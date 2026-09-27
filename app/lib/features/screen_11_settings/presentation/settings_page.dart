import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as material show Text;
import 'package:oscar_financas/shared/widgets/localized_text.dart';

import '../../../app/navigation/app_destination.dart';
import '../../../app/history_experience_copy.dart';
import '../../../app/settings/app_preferences_controller.dart';
import '../../../core/brand/product_identity.dart';
import '../../../core/localization/app_locale.dart';
import '../../../core/money/money.dart';
import '../../screen_3_investments/domain/fx_quote_set.dart';
import '../../../shared/widgets/oscar_feature_scaffold.dart';

final class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.onDestinationSelected,
    required this.preferences,
    required this.fxRepository,
    this.onResetHistory,
  });
  final ValueChanged<AppDestination> onDestinationSelected;
  final AppPreferencesController preferences;
  final FxRepository fxRepository;
  final Future<void> Function()? onResetHistory;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

final class _SettingsPageState extends State<SettingsPage> {
  late SupportedAppLocale _draftLocale = widget.preferences.locale;
  late CurrencyCode _draftCurrency = widget.preferences.currency;
  late RegionPreference _draftRegion = widget.preferences.region;
  late WeekStartPreference _draftWeekStart = widget.preferences.weekStart;
  DateTime? _nextRefreshAt;
  Timer? _countdown;
  final ValueNotifier<int> _countdownTick = ValueNotifier(0);
  bool _checkingRefresh = false;
  bool _refreshing = false;
  bool _resetting = false;

  Future<void> _confirmReset() async {
    final copy = HistoryExperienceCopy(widget.preferences.locale);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: material.Text(copy.confirmTitle),
        content: material.Text(copy.confirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: material.Text(copy.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: material.Text(
              copy.reset,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || widget.onResetHistory == null) return;
    setState(() => _resetting = true);
    try {
      await widget.onResetHistory!();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: material.Text(copy.done)));
      widget.onDestinationSelected(AppDestination.home);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: material.Text(copy.failed)));
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.fxRepository is FxRefreshSchedule) {
      _checkingRefresh = true;
      _loadRefreshSchedule();
      _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_nextRefreshAt != null && mounted) _countdownTick.value++;
      });
    }
  }

  Future<void> _loadRefreshSchedule() async {
    final schedule = widget.fxRepository;
    if (schedule is! FxRefreshSchedule) return;
    final next = await (schedule as FxRefreshSchedule).nextRefreshAt();
    if (!mounted) return;
    setState(() {
      _nextRefreshAt = next;
      _checkingRefresh = false;
    });
  }

  Future<void> _updateQuotes() async {
    setState(() => _refreshing = true);
    final quote = await widget.fxRepository.latest(
      widget.preferences.currency,
      forceRefresh: true,
    );
    await _loadRefreshSchedule();
    if (!mounted) return;
    setState(() => _refreshing = false);
    final message = quote?.status == QuoteStatus.current
        ? 'Cotações atualizadas com sucesso.'
        : quote?.status == QuoteStatus.cached
        ? 'Últimas cotações salvas · atualização automática'
        : quote == null
        ? 'Não foi possível atualizar as cotações.'
        : 'Sem conexão. O último valor disponível foi mantido.';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _countdownTick.dispose();
    super.dispose();
  }

  String _remainingText(Duration remaining) {
    final seconds = remaining.inSeconds + 1;
    final hours = (seconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final rest = (seconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$rest';
  }

  @override
  Widget build(BuildContext context) {
    return OscarFeatureScaffold(
      destination: AppDestination.settings,
      onDestinationSelected: widget.onDestinationSelected,
      headerKind: FeatureHeaderKind.menuOnly,
      body: ListenableBuilder(
        listenable: widget.preferences,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 42),
          children: [
            _Section(
              title: 'Idioma, região e moeda',
              children: [
                DropdownButtonFormField<SupportedAppLocale>(
                  isExpanded: true,
                  initialValue: _draftLocale,
                  decoration: InputDecoration(label: Text('Idioma')),
                  items: [
                    for (final locale in SupportedAppLocale.values)
                      DropdownMenuItem(
                        value: locale,
                        child: Text(locale.nativeName, translate: false),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _draftLocale = value ?? _draftLocale),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<RegionPreference>(
                  isExpanded: true,
                  initialValue: _draftRegion,
                  decoration: InputDecoration(label: Text('Região')),
                  items: RegionPreference.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_regionLabel(value)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    _draftRegion = value ?? _draftRegion;
                    _draftCurrency = _currencyForRegion(
                      _draftRegion,
                      _draftLocale,
                    );
                  }),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<CurrencyCode>(
                  isExpanded: true,
                  initialValue: _draftCurrency,
                  decoration: InputDecoration(label: Text('Moeda principal')),
                  items: [
                    for (final currency in CurrencyCode.values)
                      DropdownMenuItem(
                        value: currency,
                        child: Text(
                          '${currency.isoCode} · ${currency.symbol}',
                          translate: false,
                        ),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _draftCurrency = value ?? _draftCurrency),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<WeekStartPreference>(
                  isExpanded: true,
                  initialValue: _draftWeekStart,
                  decoration: InputDecoration(
                    label: Text('Primeiro dia da semana'),
                  ),
                  items: WeekStartPreference.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_weekStartLabel(value)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(
                    () => _draftWeekStart = value ?? _draftWeekStart,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    await widget.preferences.updateRegional(
                      locale: _draftLocale,
                      region: _draftRegion,
                      currency: _draftCurrency,
                      weekStart: _draftWeekStart,
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Configurações atualizadas')),
                    );
                  },
                  child: Text('Salvar alterações'),
                ),
              ],
            ),
            _Section(
              title: 'Aparência',
              children: [
                SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('Automático'),
                    ),
                    ButtonSegment(value: ThemeMode.light, label: Text('Claro')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Escuro')),
                  ],
                  selected: {widget.preferences.themeMode},
                  onSelectionChanged: (value) =>
                      widget.preferences.updateThemeMode(value.single),
                ),
              ],
            ),
            _Section(
              title: 'Privacidade dos valores',
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Ocultar valores ao abrir'),
                  subtitle: Text('As Telas 1, 2 e 3 começam protegidas.'),
                  value: widget.preferences.hideValuesOnOpen,
                  onChanged: widget.preferences.updateHideValuesOnOpen,
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Ocultar valores ao sair'),
                  subtitle: Text(
                    'Oculta os valores quando o aplicativo vai para segundo plano.',
                  ),
                  value: widget.preferences.hideValuesOnBackground,
                  onChanged: widget.preferences.updateHideValuesOnBackground,
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Vibração e resposta tátil'),
                  value: widget.preferences.hapticsEnabled,
                  onChanged: widget.preferences.updateHaptics,
                ),
              ],
            ),
            _Section(
              title: 'Notificações',
              children: [
                _switch(
                  'Lembretes da Agenda',
                  widget.preferences.agendaRemindersEnabled,
                  widget.preferences.updateAgendaReminders,
                ),
                DropdownButtonFormField<AgendaReminderPreference>(
                  isExpanded: true,
                  initialValue: widget.preferences.agendaReminder,
                  decoration: InputDecoration(
                    label: Text('Lembrete padrão para novos eventos'),
                  ),
                  items: AgendaReminderPreference.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_reminderLabel(value)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      widget.preferences.updateAgendaReminder(value);
                    }
                  },
                ),
                _switch(
                  'Fechamento mensal',
                  widget.preferences.monthlyClosingNotifications,
                  widget.preferences.updateMonthlyClosingNotifications,
                ),
                _switch(
                  'Lançamentos recorrentes',
                  widget.preferences.recurringEntryNotifications,
                  widget.preferences.updateRecurringEntryNotifications,
                ),
                _switch(
                  'Relatório mensal disponível',
                  widget.preferences.monthlyReportNotifications,
                  widget.preferences.updateMonthlyReportNotifications,
                ),
                _switch(
                  'Plano e assinatura',
                  widget.preferences.subscriptionNotifications,
                  widget.preferences.updateSubscriptionNotifications,
                ),
              ],
            ),
            _Section(
              title: 'Dados econômicos e câmbio',
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.currency_exchange),
                          SizedBox(width: 16),
                          Expanded(child: Text('Cotações e indicadores')),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'O último snapshot válido é usado offline. Atualizações indisponíveis aparecem como desatualizadas.',
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.shield_outlined),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'O Oscar Finanças não se conecta a contas bancárias nem movimenta dinheiro. Informações, simulações e projeções têm caráter informativo e usam dados fornecidos por você e referências de mercado atualizadas. Cotações podem apresentar atrasos ou diferenças em relação ao mercado.',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: ListenableBuilder(
                          listenable: _countdownTick,
                          builder: (context, _) {
                            final remaining = _nextRefreshAt?.difference(
                              DateTime.now().toUtc(),
                            );
                            final waiting =
                                remaining != null && remaining > Duration.zero;
                            return FilledButton(
                              onPressed:
                                  _checkingRefresh || _refreshing || waiting
                                  ? null
                                  : _updateQuotes,
                              child: Text(
                                waiting
                                    ? 'Disponível em ${_remainingText(remaining)}'
                                    : 'Atualizar agora',
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            _Section(
              title: 'Transparência e metodologia',
              children: [
                for (final document in _documents)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(document.title),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openDocument(document),
                  ),
              ],
            ),
            _Section(
              title: 'Sobre o aplicativo',
              titleAlign: TextAlign.center,
              children: [
                Center(
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/images/oscar_star.webp',
                        width: 76,
                        height: 76,
                        fit: BoxFit.contain,
                        semanticLabel: ProductIdentity.appName,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ProductIdentity.appName,
                        translate: false,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ProductIdentity.tagline,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Organiza receitas, despesas, ganhos extras, saúde financeira, relatórios, agenda e investimentos sem movimentar seu dinheiro nem oferecer recomendação individual.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Versão 0.1.0 · compilação 1',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                material.Text(
                  HistoryExperienceCopy(widget.preferences.locale).warning,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _resetting || widget.onResetHistory == null
                      ? null
                      : _confirmReset,
                  icon: const Icon(Icons.delete_outline),
                  label: material.Text(
                    HistoryExperienceCopy(widget.preferences.locale).reset,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _switch(String label, bool value, ValueChanged<bool> update) =>
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: value,
        onChanged: update,
      );

  Future<void> _openDocument(_LegalDocument document) => Navigator.of(context)
      .push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: Text(document.title),
              leading: IconButton(
                tooltip: uiText(context, 'Fechar'),
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: ListView(
              padding: const EdgeInsets.all(22),
              children: [
                Text(
                  document.body,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (document.body == 'legal.privacy.body') ...[
                  const SizedBox(height: 18),
                  const Text('legal.account.profile.body'),
                ],
              ],
            ),
          ),
        ),
      );
}

final class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
    this.titleAlign,
  });
  final String title;
  final List<Widget> children;
  final TextAlign? titleAlign;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          textAlign: titleAlign,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  );
}

String _regionLabel(RegionPreference value) => switch (value) {
  RegionPreference.automatic => 'Automático',
  RegionPreference.brazil => 'Brasil',
  RegionPreference.unitedStates => 'Estados Unidos',
  RegionPreference.germany => 'Alemanha',
  RegionPreference.france => 'França',
  RegionPreference.india => 'Índia',
};

CurrencyCode _currencyForRegion(
  RegionPreference region,
  SupportedAppLocale locale,
) => switch (region) {
  RegionPreference.brazil => CurrencyCode.brl,
  RegionPreference.unitedStates => CurrencyCode.usd,
  RegionPreference.germany || RegionPreference.france => CurrencyCode.eur,
  RegionPreference.india => CurrencyCode.inr,
  RegionPreference.automatic => switch (locale) {
    SupportedAppLocale.enUs => CurrencyCode.usd,
    SupportedAppLocale.deDe || SupportedAppLocale.frFr => CurrencyCode.eur,
    SupportedAppLocale.hiIn => CurrencyCode.inr,
    SupportedAppLocale.ptBr => CurrencyCode.brl,
  },
};
String _weekStartLabel(WeekStartPreference value) => switch (value) {
  WeekStartPreference.automatic => 'Automático',
  WeekStartPreference.sunday => 'Domingo',
  WeekStartPreference.monday => 'Segunda-feira',
};
String _reminderLabel(AgendaReminderPreference value) => switch (value) {
  AgendaReminderPreference.atTime => 'No horário',
  AgendaReminderPreference.oneDayAndAtTime => '1 dia antes e no horário',
  AgendaReminderPreference.threeDaysOneDayAndAtTime =>
    '3 dias antes, 1 dia antes e no horário',
};

final class _LegalDocument {
  const _LegalDocument(this.title, this.body);
  final String title;
  final String body;
}

const _documents = [
  _LegalDocument('Permissões e notificações', 'legal.permissions.body'),
  _LegalDocument('Termos de Uso', 'legal.terms.body'),
  _LegalDocument('Política de Privacidade', 'legal.privacy.body'),
  _LegalDocument(
    'Consentimento e tratamento de dados financeiros',
    'O aplicativo aplica minimização, finalidade e controle do usuário. LGPD, GDPR e normas regionais serão observadas de acordo com o país de disponibilização.',
  ),
  _LegalDocument('Política de Anúncios', 'legal.ads.body'),
  _LegalDocument(
    'Política de Parcerias e Benefícios',
    'O Oscar Finanças poderá receber comissão por links identificados. A transparência aparece antes da saída; critérios comerciais não alteram Oscar Score, relatórios ou cálculos.',
  ),
  _LegalDocument(
    'Privacidade Internacional',
    'Idioma, região e moeda são independentes. Transferências internacionais, quando existirem, deverão informar destino, proteção e direitos aplicáveis.',
  ),
  _LegalDocument('Exclusão de dados', 'legal.privacy.body'),
  _LegalDocument(
    'Aviso educacional financeiro',
    'O aplicativo não executa investimentos, não oferece custódia e não recomenda compra ou venda. Câmbio, inflação e rentabilidade podem variar; desempenho passado não garante resultado futuro.',
  ),
  _LegalDocument(
    'Como funciona o Oscar Score',
    'O Oscar Score resume a sobra mensal em relação à renda bruta. Ele considera entradas confirmadas, despesas e déficit. Não é score de crédito e não determina acesso a produtos.',
  ),
  _LegalDocument('Crescimento acima da inflação', 'legal.terms.body'),
  _LegalDocument(
    'Licenças e bibliotecas',
    'Construído com Flutter e bibliotecas revisadas para gráficos, banco local, PDF, impressão e notificações. A relação final de licenças será gerada para a versão publicada.',
  ),
];
