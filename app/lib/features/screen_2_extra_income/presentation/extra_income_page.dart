import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as material show Text;
import 'package:oscar_financas/shared/widgets/localized_text.dart';

import '../../../app/navigation/app_destination.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/money/money.dart';
import '../../../core/time/year_month.dart';
import '../../../core/localization/app_locale.dart';
import '../../../shared/controllers/financial_visibility_controller.dart';
import '../../../shared/controllers/month_controller.dart';
import '../../../shared/formatting/currency_amount_input_formatter.dart';
import '../../../shared/formatting/money_formatter.dart';
import '../../../shared/widgets/oscar_feature_scaffold.dart';
import '../application/extra_income_view_model.dart';
import '../../screen_3_investments/domain/fx_quote_set.dart';
import '../domain/extra_income_entry.dart';
import '../domain/extra_income_repository.dart';

part 'widgets/extra_income_visuals.dart';

final class ExtraIncomePage extends StatefulWidget {
  const ExtraIncomePage({
    super.key,
    required this.onDestinationSelected,
    required this.visibilityController,
    required this.repository,
    required this.currency,
    required this.fxRepository,
    required this.actionsEnabled,
    required this.onBlocked,
    this.minimumMonth,
  });

  final ValueChanged<AppDestination> onDestinationSelected;
  final FinancialVisibilityController visibilityController;
  final ExtraIncomeRepository repository;
  final CurrencyCode currency;
  final FxRepository fxRepository;
  final bool actionsEnabled;
  final VoidCallback onBlocked;
  final YearMonth? minimumMonth;

  @override
  State<ExtraIncomePage> createState() => _ExtraIncomePageState();
}

final class _ExtraIncomePageState extends State<ExtraIncomePage>
    with SingleTickerProviderStateMixin {
  late final MonthController _monthController;
  late final ExtraIncomeViewModel _viewModel;
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _monthController = MonthController(
      minimumMonth: widget.minimumMonth,
      currentMonthFloor: true,
    );
    _viewModel = ExtraIncomeViewModel(
      repository: widget.repository,
      monthController: _monthController,
      currency: widget.currency,
      fxRepository: widget.fxRepository,
    )..load();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    _viewModel.dispose();
    _monthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formatter = MoneyFormatter(
      locale: Localizations.localeOf(context).toLanguageTag(),
      currency: widget.currency,
    );
    return OscarFeatureScaffold(
      destination: AppDestination.extraIncome,
      onDestinationSelected: widget.onDestinationSelected,
      headerKind: FeatureHeaderKind.financialMonth,
      monthController: _monthController,
      visibilityController: widget.visibilityController,
      bottomNavigationBar: ListenableBuilder(
        listenable: Listenable.merge([_viewModel, widget.visibilityController]),
        builder: (context, _) {
          final total = _viewModel.state?.summary.totalMinor ?? 0;
          return SafeArea(
            top: false,
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainer,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    const Expanded(child: Text('Total realizado no mês')),
                    Text(
                      widget.visibilityController.valuesHidden
                          ? '••••'
                          : formatter.formatMinor(total),
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(color: AppColors.emerald),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([_viewModel, widget.visibilityController]),
        builder: (context, _) {
          final state = _viewModel.state;
          if (state == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == ExtraIncomeLoadStatus.failure) {
            return Center(
              child: FilledButton(
                onPressed: _viewModel.load,
                child: const Text('Tentar novamente'),
              ),
            );
          }
          final kind = _tabs.index == 0
              ? ExtraIncomeKind.service
              : ExtraIncomeKind.sale;
          final filtered = state.entries
              .where((entry) => entry.kind == kind)
              .toList();
          final hidden = widget.visibilityController.valuesHidden;
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
            children: [
              _ExtraIncomeChart(
                summary: state.summary,
                formatter: formatter,
                hidden: hidden,
              ),
              const SizedBox(height: 16),
              TabBar(
                controller: _tabs,
                indicatorColor: AppColors.gold,
                tabs: [
                  Tab(text: uiText(context, 'Serviços')),
                  Tab(text: uiText(context, 'Vendas')),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      kind == ExtraIncomeKind.service
                          ? uiText(context, 'Serviços do mês')
                          : uiText(context, 'Vendas do mês'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _showAddForm(kind),
                    icon: const Icon(Icons.add),
                    label: Text(
                      kind == ExtraIncomeKind.service
                          ? uiText(context, 'Adicionar serviço')
                          : uiText(context, 'Adicionar venda'),
                    ),
                  ),
                ],
              ),
              Card(
                child: filtered.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(22),
                        child: Text('Nenhum lançamento nesta categoria.'),
                      )
                    : Column(
                        children: [
                          for (final entry in filtered)
                            ListTile(
                              onTap: () => _showDetails(entry, formatter),
                              title: material.Text(
                                _displayEntryText(context, entry, entry.name),
                              ),
                              subtitle: material.Text(
                                [
                                  _displayEntryText(
                                    context,
                                    entry,
                                    entry.description,
                                  ),
                                  if (entry.recurring)
                                    uiText(context, 'Recorrente'),
                                  if (entry.includeInFinancialIncome)
                                    uiText(context, 'Somado à Tela 1'),
                                ].where((item) => item.isNotEmpty).join(' · '),
                              ),
                              trailing: Text(
                                hidden
                                    ? '••••'
                                    : formatter.formatMinor(entry.amountMinor),
                              ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 22),
              Text(
                'Origem dos ganhos',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              _IncomeOriginDonut(
                summary: state.summary,
                formatter: formatter,
                hidden: hidden,
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showAddForm(
    ExtraIncomeKind kind, {
    ExtraIncomeEntry? existing,
  }) async {
    if (!widget.actionsEnabled) {
      widget.onBlocked();
      return;
    }
    final locale = Localizations.localeOf(context).toLanguageTag();
    final name = TextEditingController(text: existing?.name ?? '');
    final description = TextEditingController(
      text: existing?.description ?? '',
    );
    final amount = TextEditingController(
      text: existing == null
          ? ''
          : formatCurrencyInputMinor(existing.amountMinor, locale),
    );
    var recurring = existing?.recurring ?? false;
    var include = existing?.includeInFinancialIncome ?? true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  existing != null
                      ? kind == ExtraIncomeKind.service
                            ? 'Editar serviço'
                            : 'Editar venda'
                      : kind == ExtraIncomeKind.service
                      ? 'Novo serviço'
                      : 'Nova venda',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: name,
                  decoration: InputDecoration(
                    labelText: uiText(context, 'Nome'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: description,
                  decoration: InputDecoration(
                    labelText: uiText(context, 'Descrição'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [CurrencyAmountInputFormatter(locale)],
                  decoration: InputDecoration(
                    labelText: uiText(context, 'Valor'),
                    prefixText: '${widget.currency.symbol} ',
                  ),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ganho recorrente'),
                  value: recurring,
                  onChanged: (value) => setSheetState(() => recurring = value),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Somar à renda extra da Tela 1'),
                  value: include,
                  onChanged: (value) =>
                      setSheetState(() => include = value ?? false),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          final amountMinor = parseCurrencyMinor(
                            amount.text,
                            locale,
                          );
                          if (existing == null) {
                            await _viewModel.add(
                              kind: kind,
                              name: name.text,
                              description: description.text,
                              amountMinor: amountMinor,
                              recurring: recurring,
                              includeInFinancialIncome: include,
                            );
                          } else {
                            await _viewModel.update(
                              existing: existing,
                              name: name.text,
                              description: description.text,
                              amountMinor: amountMinor,
                              recurring: recurring,
                              includeInFinancialIncome: include,
                            );
                          }
                          if (sheetContext.mounted) Navigator.pop(sheetContext);
                        },
                        child: const Text('Salvar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    name.dispose();
    description.dispose();
    amount.dispose();
  }

  Future<void> _showDetails(
    ExtraIncomeEntry entry,
    MoneyFormatter formatter,
  ) async {
    if (!widget.actionsEnabled) {
      widget.onBlocked();
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: material.Text(
                      _displayEntryText(context, entry, entry.name),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: uiText(context, 'Editar'),
                    onPressed: () async {
                      Navigator.pop(sheetContext);
                      await Future<void>.delayed(
                        const Duration(milliseconds: 200),
                      );
                      if (!mounted) return;
                      await _showAddForm(entry.kind, existing: entry);
                    },
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: AppColors.gold,
                    ),
                  ),
                ],
              ),
              Text(formatter.formatMinor(entry.amountMinor)),
              if (entry.description.isNotEmpty)
                material.Text(
                  _displayEntryText(context, entry, entry.description),
                ),
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: () async {
                  final confirmed =
                      await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Confirmar exclusão'),
                          content: Text(
                            '${entry.name} será removido de ${entry.month.databaseKey}.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancelar'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Excluir'),
                            ),
                          ],
                        ),
                      ) ??
                      false;
                  if (!confirmed) return;
                  await _viewModel.remove(entry.id);
                  if (!sheetContext.mounted) return;
                  Navigator.pop(sheetContext);
                  if (!mounted) return;
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      duration: const Duration(seconds: 5),
                      content: const Text('Ganho removido.'),
                      action: SnackBarAction(
                        label: uiText(context, 'Desfazer'),
                        onPressed: () => _viewModel.undoRemove(entry.id),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Excluir'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _displayEntryText(
  BuildContext context,
  ExtraIncomeEntry entry,
  String value,
) {
  if (!entry.id.startsWith('demo:extra:')) return value;
  if (value == 'Pool cleaning' || value == 'Monthly pool maintenance') {
    final locale = SupportedAppLocale.resolve(Localizations.localeOf(context));
    return switch ((locale, value)) {
      (SupportedAppLocale.ptBr, 'Pool cleaning') => 'Limpeza de piscina',
      (SupportedAppLocale.ptBr, _) => 'Manutenção mensal de piscina',
      (SupportedAppLocale.deDe, 'Pool cleaning') => 'Poolreinigung',
      (SupportedAppLocale.deDe, _) => 'Monatliche Poolpflege',
      (SupportedAppLocale.frFr, 'Pool cleaning') => 'Nettoyage de piscine',
      (SupportedAppLocale.frFr, _) => 'Entretien mensuel de piscine',
      (SupportedAppLocale.hiIn, 'Pool cleaning') => 'पूल की सफाई',
      (SupportedAppLocale.hiIn, _) => 'मासिक पूल रखरखाव',
      _ => value,
    };
  }
  final source = switch (value) {
    'Freelance service' => 'Serviço freelance',
    'Project or client work this month' => 'Projeto ou atendimento do mês',
    'Occasional sale' => 'Venda ocasional',
    'Sale of an item or product' => 'Venda de item ou produto',
    _ => value,
  };
  if (source == value &&
      !const {
        'Serviço freelance',
        'Projeto ou atendimento do mês',
        'Venda ocasional',
        'Venda de item ou produto',
      }.contains(value)) {
    return value;
  }
  return uiText(context, source);
}
