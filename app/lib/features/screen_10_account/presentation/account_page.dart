import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as material show Text;
import 'package:intl/intl.dart';
import 'package:oscar_financas/shared/widgets/localized_text.dart';

import '../../../app/navigation/app_destination.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/localization/app_strings.dart';
import '../../../features/screen_8_plans/domain/access_policy.dart';
import '../../../shared/widgets/oscar_feature_scaffold.dart';
import '../domain/account_profile.dart';

final class AccountPage extends StatefulWidget {
  const AccountPage({
    super.key,
    required this.onDestinationSelected,
    required this.repository,
    required this.currentPlan,
  });

  final ValueChanged<AppDestination> onDestinationSelected;
  final AccountProfileRepository repository;
  final PlanTier currentPlan;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

final class _AccountPageState extends State<AccountPage> {
  final _nameController = TextEditingController();
  final _birthDateController = TextEditingController();
  DateTime? _birthDate;
  bool _receiveCommunications = false;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await widget.repository.load();
      if (!mounted) return;
      _nameController.text = profile.name;
      _birthDate = profile.birthDate;
      _receiveCommunications = profile.receiveCommunications;
      _formatBirthDate();
      setState(() => _loading = false);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _formatBirthDate() {
    final date = _birthDate;
    _birthDateController.text = date == null
        ? ''
        : DateFormat.yMd(Localizations.localeOf(context).toLanguageTag())
              .format(date);
  }

  Future<void> _chooseBirthDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (selected == null || !mounted) return;
    setState(() {
      _birthDate = DateTime(selected.year, selected.month, selected.day);
      _formatBirthDate();
    });
  }

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    try {
      await widget.repository.save(
        AccountProfile(
          name: _nameController.text.trim(),
          birthDate: _birthDate,
          receiveCommunications: _receiveCommunications,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(uiText(context, 'Perfil salvo neste dispositivo.')),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(uiText(context, 'Não foi possível salvar o perfil.')),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showLegalDocument(String titleKey, String bodyKey) async {
    final strings = AppStrings.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .82,
        maxChildSize: .95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            material.Text(
              strings.text(titleKey),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            material.Text(
              strings.text(bodyKey),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (bodyKey == 'legal.privacy.body') ...[
              const SizedBox(height: 18),
              material.Text(
                strings.text('legal.account.profile.body'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    final planName = switch (widget.currentPlan) {
      PlanTier.basic => 'Plano Básico',
      PlanTier.plus => 'Plano Plus',
      PlanTier.pro => 'Plano Pro',
    };

    return OscarFeatureScaffold(
      destination: AppDestination.account,
      onDestinationSelected: widget.onDestinationSelected,
      headerKind: FeatureHeaderKind.menuOnly,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Column(
                  children: [
                    CircleAvatar(
                      radius: 42,
                      backgroundColor: AppColors.gold,
                      child: Icon(
                        Icons.person_outline_rounded,
                        size: 48,
                        color: AppColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      uiText(context, planName),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          uiText(context, 'Dados do perfil'),
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          maxLength: 80,
                          decoration: InputDecoration(
                            labelText: uiText(context, 'Nome'),
                            border: const OutlineInputBorder(),
                            counterText: '',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _birthDateController,
                          readOnly: true,
                          onTap: _chooseBirthDate,
                          decoration: InputDecoration(
                            labelText: uiText(context, 'Data de nascimento'),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              tooltip: uiText(context, 'Data de nascimento'),
                              onPressed: _chooseBirthDate,
                              icon: const Icon(Icons.calendar_month_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            uiText(
                              context,
                              'Receber comunicações do Oscar Hive',
                            ),
                          ),
                          subtitle: material.Text(
                            '${strings.text('Opcional e independente da publicidade.')}\n${strings.text('Essa preferência fica salva neste aparelho.')}',
                          ),
                          value: _receiveCommunications,
                          activeTrackColor: AppColors.gold,
                          onChanged: (value) =>
                              setState(() => _receiveCommunications = value),
                        ),
                        const SizedBox(height: 6),
                        FilledButton(
                          onPressed: _saving ? null : _saveProfile,
                          child: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(uiText(context, 'Salvar alterações')),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        FilledButton.icon(
                          onPressed: null,
                          icon: const Icon(Icons.g_mobiledata_rounded),
                          label: Text(strings.text('entry.google')),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          uiText(
                            context,
                            'O acesso com Google ainda não está disponível nesta versão.',
                          ),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: null,
                          icon: const Icon(Icons.apple),
                          label: Text(strings.text('entry.apple')),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          uiText(
                            context,
                            'Apple estará disponível em uma versão futura.',
                          ),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: Text(uiText(context, 'Termos de Uso')),
                        trailing: const Icon(Icons.open_in_new_rounded),
                        onTap: () => _showLegalDocument(
                          'Termos de Uso',
                          'legal.terms.body',
                        ),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        leading: const Icon(Icons.shield_outlined),
                        title: Text(uiText(context, 'Política de Privacidade')),
                        trailing: const Icon(Icons.open_in_new_rounded),
                        onTap: () => _showLegalDocument(
                          'Política de Privacidade',
                          'legal.privacy.body',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(Icons.cloud_outlined),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                uiText(
                                  context,
                                  'Cópia de segurança e recuperação',
                                ),
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                uiText(
                                  context,
                                  'Seus dados ficam neste aparelho. A sincronização e a recuperação na nuvem ainda não estão disponíveis.',
                                ),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
