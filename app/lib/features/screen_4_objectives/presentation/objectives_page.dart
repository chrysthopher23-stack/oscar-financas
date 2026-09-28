import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/navigation/app_destination.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/money/money.dart';
import '../../../core/time/year_month.dart';
import '../../screen_3_investments/domain/fx_quote_set.dart';
import '../../../shared/controllers/financial_visibility_controller.dart';
import '../../../shared/formatting/currency_amount_input_formatter.dart';
import '../../../shared/formatting/money_formatter.dart';
import '../../../shared/widgets/financial_visibility_button.dart';
import '../../../shared/widgets/oscar_feature_scaffold.dart';
import '../../../shared/widgets/bounded_modal_sheet.dart';
import '../../../shared/widgets/demo_display_names.dart';
import '../application/objectives_view_model.dart';
import '../domain/financial_objective.dart';
import '../domain/objective_repository.dart';
import '../../screen_1_financial/domain/financial_repository.dart';

final class ObjectivesPage extends StatefulWidget {
  const ObjectivesPage({
    super.key,
    required this.onDestinationSelected,
    required this.repository,
    required this.financialRepository,
    required this.fxRepository,
    required this.currency,
    required this.visibilityController,
    required this.initialData,
    required this.actionsEnabled,
    required this.onBlocked,
  });

  final ValueChanged<AppDestination> onDestinationSelected;
  final ObjectiveRepository repository;
  final FinancialRepository financialRepository;
  final FxRepository fxRepository;
  final CurrencyCode currency;
  final FinancialVisibilityController visibilityController;
  final Future<void> initialData;
  final bool actionsEnabled;
  final VoidCallback onBlocked;

  @override
  State<ObjectivesPage> createState() => _ObjectivesPageState();
}

final class _ObjectivesPageState extends State<ObjectivesPage> {
  late final ObjectivesViewModel _viewModel;
  final Set<String> _expanded = {};
  FxQuoteSet? _fx;

  @override
  void initState() {
    super.initState();
    _viewModel = ObjectivesViewModel(
      widget.repository,
      widget.financialRepository,
    );
    _initialize();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    await widget.initialData;
    if (!mounted) return;
    await _viewModel.load();
    if (!mounted) return;
    try {
      final quote = await widget.fxRepository.latest(widget.currency);
      if (mounted) setState(() => _fx = quote);
    } catch (_) {
      // Foreign values remain unavailable when no quote can be obtained.
    }
  }

  @override
  Widget build(BuildContext context) {
    return OscarFeatureScaffold(
      destination: AppDestination.objectives,
      onDestinationSelected: widget.onDestinationSelected,
      headerKind: FeatureHeaderKind.menuOnly,
      actions: [
        FinancialVisibilityButton(controller: widget.visibilityController),
        const SizedBox(width: 4),
      ],
      body: ListenableBuilder(
        listenable: Listenable.merge([_viewModel, widget.visibilityController]),
        builder: (context, _) {
          final strings = AppStrings.of(context);
          if (_viewModel.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_viewModel.error != null) {
            return _loadError(context, strings);
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
            children: [
              FilledButton.icon(
                onPressed: widget.actionsEnabled
                    ? _showCreateForm
                    : widget.onBlocked,
                icon: const Icon(Icons.add),
                label: Text(strings.text('objectives.new')),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
              const SizedBox(height: 16),
              if (_viewModel.objectives.isEmpty)
                _emptyState(context, strings)
              else
                for (final objective in _viewModel.objectives)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _objectiveCard(
                      context,
                      objective,
                      strings,
                      widget.visibilityController.valuesHidden,
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }

  Widget _loadError(BuildContext context, AppStrings strings) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(strings.text('objectives.loadFailed')),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _viewModel.load,
            icon: const Icon(Icons.refresh),
            label: Text(strings.text('objectives.retry')),
          ),
        ],
      ),
    ),
  );

  Widget _emptyState(BuildContext context, AppStrings strings) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          const Icon(Icons.flag_outlined, color: AppColors.gold, size: 28),
          const SizedBox(height: 10),
          Text(
            strings.text('objectives.emptyTitle'),
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            strings.text('objectives.emptyBody'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );

  Widget _objectiveCard(
    BuildContext context,
    FinancialObjective objective,
    AppStrings strings,
    bool valuesHidden,
  ) {
    final snapshots = _viewModel.evolution(objective);
    final currentBalance = snapshots.isEmpty
        ? objective.initialBalanceMinor
        : snapshots.last.closingBalanceMinor;
    final accumulatedContributions =
        objective.initialBalanceMinor +
        snapshots.fold<int>(0, (sum, item) => sum + item.contributionMinor);
    final accumulatedYield = snapshots.fold<int>(
      0,
      (sum, item) => sum + item.yieldMinor,
    );
    final progress = objective.targetAmountMinor <= 0
        ? 0.0
        : (currentBalance / objective.targetAmountMinor).clamp(0.0, 1.0);
    final percent = (progress * 100).round();
    final formatter = MoneyFormatter(
      locale: Localizations.localeOf(context).toLanguageTag(),
      currency: widget.currency,
    );
    int? displayAmount(int amount) => objective.currency == widget.currency
        ? amount
        : _fx?.convertToBaseMinor(amount, objective.currency);
    final isExpanded = _expanded.contains(objective.id);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  _isEmergencyReserve(objective)
                      ? Icons.account_balance_outlined
                      : Icons.flag_outlined,
                  color: AppColors.gold,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    demoGoalName(
                      context,
                      _objectiveDisplayName(objective, strings),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: strings.text('objectives.goalActions'),
                  onSelected: (action) {
                    if (action != 'delete') return;
                    if (!widget.actionsEnabled) {
                      widget.onBlocked();
                      return;
                    }
                    _confirmDelete(objective, strings);
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(strings.text('objectives.delete')),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      strings.text('objectives.annualRateShort'),
                      maxLines: 1,
                      softWrap: false,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: strings.text('objectives.lowerRate'),
                      onPressed: objective.annualRateBasisPoints <= 0
                          ? null
                          : () => _changeAnnualRate(objective, -10),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text(
                      '${(NumberFormat.decimalPattern(Localizations.localeOf(context).toLanguageTag())..maximumFractionDigits = 2).format(objective.annualRateBasisPoints / 100)}%',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    IconButton(
                      tooltip: strings.text('objectives.raiseRate'),
                      onPressed: objective.annualRateBasisPoints >= 10000
                          ? null
                          : () => _changeAnnualRate(objective, 10),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 2),
            OutlinedButton.icon(
              onPressed: widget.actionsEnabled
                  ? () => _showContributionForm(objective)
                  : widget.onBlocked,
              icon: const Icon(Icons.add),
              label: Text(strings.text('objectives.addContribution')),
            ),
            const SizedBox(height: 6),
            Text(
              strings.text('objectives.currentBalance'),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _money(
                formatter,
                displayAmount(currentBalance),
                valuesHidden,
                unavailableLabel: strings.text('Indisponível'),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ObjectiveMetric(
                    label: strings.text('objectives.contributions'),
                    value: _money(
                      formatter,
                      displayAmount(accumulatedContributions),
                      valuesHidden,
                      unavailableLabel: strings.text('Indisponível'),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 34,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                Expanded(
                  child: _ObjectiveMetric(
                    label: strings.text('objectives.returnLabel'),
                    value: _money(
                      formatter,
                      displayAmount(accumulatedYield),
                      valuesHidden,
                      positive: true,
                      unavailableLabel: strings.text('Indisponível'),
                    ),
                    color: AppColors.emerald,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Semantics(
              label: strings.text('objectives.progressSemantics', {
                'percent': percent.toString(),
              }),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  color: AppColors.gold,
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    strings.text('objectives.target', {
                      'months': _periodLabel(objective.targetMonths, strings),
                      'amount':
                          displayAmount(objective.targetAmountMinor) == null
                          ? strings.text('Indisponível')
                          : formatter.formatMinor(
                              displayAmount(objective.targetAmountMinor)!,
                            ),
                    }),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  strings.text('objectives.percentComplete', {
                    'percent': percent.toString(),
                  }),
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            if (objective.importedFromExpenseHistory)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  strings.text('objectives.importedHistory'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            const Divider(height: 12),
            InkWell(
              onTap: () => setState(() {
                if (isExpanded) {
                  _expanded.remove(objective.id);
                } else {
                  _expanded.add(objective.id);
                }
              }),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.visibility_outlined, size: 19),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        strings.text('objectives.viewEvolution'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                    ),
                  ],
                ),
              ),
            ),
            if (isExpanded)
              _EvolutionDetails(
                snapshots: snapshots,
                formatter: formatter,
                convertAmount: displayAmount,
                valuesHidden: valuesHidden,
                strings: strings,
                annualRateBasisPoints: objective.annualRateBasisPoints,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateForm() async {
    if (!widget.actionsEnabled) {
      widget.onBlocked();
      return;
    }
    final strings = AppStrings.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final name = TextEditingController();
    final initial = TextEditingController(text: '0');
    final target = TextEditingController();
    final contribution = TextEditingController(text: '0');
    var rateBasisPoints = 400;
    var targetMonths = 6;
    var frequency = ObjectiveContributionFrequency.monthly;
    var saving = false;
    final formKey = GlobalKey<FormState>();
    TransitionRoute<dynamic>? sheetRoute;
    final saved = await showOscarBoundedModalSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        sheetRoute = ModalRoute.of(sheetContext);
        return StatefulBuilder(
          builder: (context, setSheetState) => Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              18 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      strings.text('objectives.new'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: name,
                      maxLength: 60,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: strings.text('objectives.name'),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? strings.text('objectives.nameRequired')
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Text(strings.text('objectives.targetPeriod')),
                    const SizedBox(height: 8),
                    SegmentedButton<int>(
                      showSelectedIcon: false,
                      emptySelectionAllowed: true,
                      segments: [
                        ButtonSegment(
                          value: 3,
                          label: Text(strings.text('objectives.threeMonths')),
                        ),
                        ButtonSegment(
                          value: 6,
                          label: Text(strings.text('objectives.sixMonths')),
                        ),
                        ButtonSegment(
                          value: 12,
                          label: Text(strings.text('objectives.oneYear')),
                        ),
                      ],
                      selected: targetMonths <= 12 ? {targetMonths} : {},
                      onSelectionChanged: (value) {
                        if (value.isNotEmpty) {
                          setSheetState(() => targetMonths = value.single);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.center,
                      child: FractionallySizedBox(
                        widthFactor: 2 / 3,
                        child: SegmentedButton<int>(
                          showSelectedIcon: false,
                          emptySelectionAllowed: true,
                          segments: [
                            ButtonSegment(
                              value: 60,
                              label: Text(strings.text('objectives.fiveYears')),
                            ),
                            ButtonSegment(
                              value: 120,
                              label: Text(strings.text('objectives.tenYears')),
                            ),
                          ],
                          selected: targetMonths > 12 ? {targetMonths} : {},
                          onSelectionChanged: (value) {
                            if (value.isNotEmpty) {
                              setSheetState(() => targetMonths = value.single);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    _moneyField(
                      controller: target,
                      label: strings.text('objectives.targetAmount'),
                      locale: locale,
                      validator: (value) =>
                          parseCurrencyMinor(value ?? '', locale) <= 0
                          ? strings.text('objectives.targetRequired')
                          : null,
                    ),
                    const SizedBox(height: 12),
                    _moneyField(
                      controller: initial,
                      label: strings.text('objectives.initialBalance'),
                      locale: locale,
                      helper: strings.text('objectives.initialBalanceHelp'),
                    ),
                    const SizedBox(height: 12),
                    _moneyField(
                      controller: contribution,
                      label: strings.text('objectives.contribution'),
                      locale: locale,
                    ),
                    const SizedBox(height: 12),
                    Text(strings.text('objectives.annualRate')),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: rateBasisPoints <= 0
                              ? null
                              : () => setSheetState(
                                  () => rateBasisPoints = (rateBasisPoints - 10)
                                      .clamp(0, 10000),
                                ),
                          child: const Text(
                            '−',
                            style: TextStyle(fontSize: 22),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${(NumberFormat.decimalPattern(locale)..maximumFractionDigits = 2).format(rateBasisPoints / 100)}%',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        OutlinedButton(
                          onPressed: rateBasisPoints >= 10000
                              ? null
                              : () => setSheetState(
                                  () => rateBasisPoints = (rateBasisPoints + 10)
                                      .clamp(0, 10000),
                                ),
                          child: const Text(
                            '+',
                            style: TextStyle(fontSize: 22),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        strings.text('objectives.compoundInterest'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(strings.text('objectives.frequency')),
                    const SizedBox(height: 7),
                    SegmentedButton<ObjectiveContributionFrequency>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                          value: ObjectiveContributionFrequency.once,
                          label: Text(strings.text('objectives.oneTime')),
                        ),
                        ButtonSegment(
                          value: ObjectiveContributionFrequency.monthly,
                          label: Text(strings.text('objectives.monthly')),
                        ),
                      ],
                      selected: {frequency},
                      onSelectionChanged: (value) =>
                          setSheetState(() => frequency = value.single),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      strings.text('objectives.projectionDisclosure'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: saving
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setSheetState(() => saving = true);
                              final objective = FinancialObjective(
                                id: 'objective:${DateTime.now().microsecondsSinceEpoch}',
                                name: name.text.trim(),
                                instrument: '',
                                targetMonths: targetMonths,
                                initialBalanceMinor: parseCurrencyMinor(
                                  initial.text,
                                  locale,
                                ),
                                targetAmountMinor: parseCurrencyMinor(
                                  target.text,
                                  locale,
                                ),
                                annualRateBasisPoints: rateBasisPoints,
                                monthlyContributionMinor: parseCurrencyMinor(
                                  contribution.text,
                                  locale,
                                ),
                                frequency: frequency,
                                startMonth: YearMonth.now(),
                                currency: widget.currency,
                              );
                              await _viewModel.create(objective);
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext, true);
                              }
                            },
                      child: Text(strings.text('objectives.create')),
                    ),
                    TextButton(
                      onPressed: saving
                          ? null
                          : () => Navigator.pop(sheetContext, false),
                      child: Text(strings.text('objectives.cancel')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    await sheetRoute?.completed;
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.text('objectives.created'))),
      );
    }
    name.dispose();
    initial.dispose();
    target.dispose();
    contribution.dispose();
  }

  Future<void> _changeAnnualRate(
    FinancialObjective objective,
    int difference,
  ) async {
    if (!widget.actionsEnabled) {
      widget.onBlocked();
      return;
    }
    await _viewModel.updateAnnualRate(
      objective.id,
      objective.annualRateBasisPoints + difference,
    );
  }

  Widget _moneyField({
    required TextEditingController controller,
    required String label,
    required String locale,
    String? helper,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [CurrencyAmountInputFormatter(locale)],
    validator: validator,
    decoration: InputDecoration(
      labelText: label,
      prefixText: '${widget.currency.symbol} ',
      helperText: helper,
    ),
  );

  Future<void> _showContributionForm(FinancialObjective objective) async {
    if (!widget.actionsEnabled) {
      widget.onBlocked();
      return;
    }
    final strings = AppStrings.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final amount = TextEditingController();
    final formKey = GlobalKey<FormState>();
    TransitionRoute<dynamic>? sheetRoute;
    final saved = await showOscarBoundedModalSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        sheetRoute = ModalRoute.of(sheetContext);
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            18 + MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  demoGoalName(
                    context,
                    _objectiveDisplayName(objective, strings),
                  ),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 14),
                _moneyField(
                  controller: amount,
                  label: strings.text('objectives.contributionAmount'),
                  locale: locale,
                  validator: (value) =>
                      parseCurrencyMinor(value ?? '', locale) <= 0
                      ? strings.text('objectives.targetRequired')
                      : null,
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final enteredAmount = parseCurrencyMinor(
                      amount.text,
                      locale,
                    );
                    final storedAmount = objective.currency == widget.currency
                        ? enteredAmount
                        : _fx?.convertMinor(enteredAmount, objective.currency);
                    if (storedAmount == null || storedAmount <= 0) {
                      if (sheetContext.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              strings.text('objectives.exchangeUnavailable'),
                            ),
                          ),
                        );
                      }
                      return;
                    }
                    await _viewModel.contribute(objective.id, storedAmount);
                    if (sheetContext.mounted) Navigator.pop(sheetContext, true);
                  },
                  child: Text(strings.text('objectives.saveContribution')),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(sheetContext, false),
                  child: Text(strings.text('objectives.cancel')),
                ),
              ],
            ),
          ),
        );
      },
    );
    await sheetRoute?.completed;
    amount.dispose();
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.text('objectives.contributionSaved'))),
      );
    }
  }

  Future<void> _confirmDelete(
    FinancialObjective objective,
    AppStrings strings,
  ) async {
    if (!widget.actionsEnabled) {
      widget.onBlocked();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.text('objectives.deleteTitle')),
        content: Text(strings.text('objectives.deleteBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.text('objectives.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.text('objectives.delete')),
          ),
        ],
      ),
    );
    if (confirmed == true) await _viewModel.delete(objective.id);
  }
}

final class _ObjectiveMetric extends StatelessWidget {
  const _ObjectiveMetric({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    ],
  );
}

final class _EvolutionDetails extends StatelessWidget {
  const _EvolutionDetails({
    required this.snapshots,
    required this.formatter,
    required this.convertAmount,
    required this.valuesHidden,
    required this.strings,
    required this.annualRateBasisPoints,
  });

  final List<ObjectiveMonthSnapshot> snapshots;
  final MoneyFormatter formatter;
  final int? Function(int) convertAmount;
  final bool valuesHidden;
  final AppStrings strings;
  final int annualRateBasisPoints;

  @override
  Widget build(BuildContext context) {
    final visible = snapshots.length <= 12
        ? snapshots
        : snapshots.sublist(snapshots.length - 12);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 126,
            child: CustomPaint(
              painter: _ObjectiveEvolutionPainter(
                values: visible
                    .map((item) => item.closingBalanceMinor)
                    .toList(),
                line: AppColors.gold,
                grid: Theme.of(context).colorScheme.outlineVariant,
              ),
              child: Semantics(
                label: strings.text('objectives.chartDescription'),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            strings.text('objectives.monthlyEvolution'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 5),
          for (final snapshot in visible.reversed)
            _EvolutionRow(
              snapshot: snapshot,
              formatter: formatter,
              convertAmount: convertAmount,
              valuesHidden: valuesHidden,
              locale: locale,
              strings: strings,
            ),
          const SizedBox(height: 9),
          Text(
            strings.text('objectives.projectionFootnote', {
              'rate':
                  (NumberFormat.decimalPattern(locale)
                        ..minimumFractionDigits = 2
                        ..maximumFractionDigits = 2)
                      .format(annualRateBasisPoints / 100),
            }),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

final class _EvolutionRow extends StatelessWidget {
  const _EvolutionRow({
    required this.snapshot,
    required this.formatter,
    required this.convertAmount,
    required this.valuesHidden,
    required this.locale,
    required this.strings,
  });

  final ObjectiveMonthSnapshot snapshot;
  final MoneyFormatter formatter;
  final int? Function(int) convertAmount;
  final bool valuesHidden;
  final String locale;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          DateFormat.yMMM(locale)
              .format(DateTime(snapshot.month.year, snapshot.month.month)),
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            _historyValue(
              context,
              strings.text('objectives.contribution'),
              convertAmount(snapshot.contributionMinor),
              unavailableLabel: strings.text('Indisponível'),
            ),
            _historyValue(
              context,
              snapshot.yieldIsEstimate
                  ? strings.text('objectives.estimatedYieldShort')
                  : strings.text('objectives.actualYieldShort'),
              convertAmount(snapshot.yieldMinor),
              accent: AppColors.emerald,
              unavailableLabel: strings.text('Indisponível'),
            ),
            _historyValue(
              context,
              strings.text('objectives.closingBalance'),
              convertAmount(snapshot.closingBalanceMinor),
              bold: true,
              unavailableLabel: strings.text('Indisponível'),
            ),
          ],
        ),
        const Divider(height: 12),
      ],
    ),
  );

  Widget _historyValue(
    BuildContext context,
    String label,
    int? value, {
    Color? accent,
    bool bold = false,
    required String unavailableLabel,
  }) => Expanded(
    child: Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _money(
              formatter,
              value,
              valuesHidden,
              unavailableLabel: unavailableLabel,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: accent,
              fontWeight: bold ? FontWeight.w600 : null,
            ),
          ),
        ],
      ),
    ),
  );
}

final class _ObjectiveEvolutionPainter extends CustomPainter {
  const _ObjectiveEvolutionPainter({
    required this.values,
    required this.line,
    required this.grid,
  });

  final List<int> values;
  final Color line;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var row = 1; row <= 2; row++) {
      final y = size.height * row / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    if (values.isEmpty) return;
    final minValue = values.reduce(math.min).toDouble();
    final maxValue = values.reduce(math.max).toDouble();
    final rawRange = maxValue - minValue;
    final range = math.max(1, rawRange);
    final chartTop = 10.0;
    final chartBottom = size.height - 12;
    final chartHeight = chartBottom - chartTop;
    final points = <Offset>[];
    for (var index = 0; index < values.length; index++) {
      final x = values.length == 1
          ? size.width - 7
          : 7 + (size.width - 14) * index / (values.length - 1);
      final normalized = rawRange == 0
          ? 0.5
          : (values[index] - minValue) / range;
      final y = chartBottom - normalized * chartHeight;
      points.add(Offset(x, y));
    }
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 1; index < points.length; index++) {
      final previous = points[index - 1];
      final current = points[index];
      final middleX = (previous.dx + current.dx) / 2;
      linePath.cubicTo(
        middleX,
        previous.dy,
        middleX,
        current.dy,
        current.dx,
        current.dy,
      );
    }
    if (points.length > 1) {
      final areaPath = Path.from(linePath)
        ..lineTo(points.last.dx, chartBottom)
        ..lineTo(points.first.dx, chartBottom)
        ..close();
      canvas.drawPath(
        areaPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              line.withValues(alpha: 0.28),
              line.withValues(alpha: 0.015),
            ],
          ).createShader(Offset.zero & size),
      );
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = line
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      canvas.drawCircle(
        point,
        index == points.length - 1 ? 5 : 2.5,
        Paint()
          ..color = index == points.length - 1
              ? line
              : line.withValues(alpha: 0.7),
      );
      if (index == points.length - 1) {
        canvas.drawCircle(
          point,
          8,
          Paint()
            ..color = line.withValues(alpha: 0.15)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ObjectiveEvolutionPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.line != line ||
      oldDelegate.grid != grid;
}

bool _isEmergencyReserve(FinancialObjective objective) {
  final name = objective.name.toLowerCase();
  return name.contains('reserva') ||
      name.contains('emergency fund') ||
      name.contains('notfallreserve') ||
      name.contains('fonds d’urgence') ||
      name.contains("fonds d'urgence");
}

String _objectiveDisplayName(
  FinancialObjective objective,
  AppStrings strings,
) => objective.id == 'objective:demo-emergency-reserve'
    ? strings.text('Reserva de emergência')
    : objective.name;

String _periodLabel(int months, AppStrings strings) => switch (months) {
  3 => strings.text('objectives.threeMonths'),
  6 => strings.text('objectives.sixMonths'),
  12 => strings.text('objectives.oneYear'),
  60 => strings.text('objectives.fiveYears'),
  120 => strings.text('objectives.tenYears'),
  _ => strings.text('objectives.monthCount', {'count': '$months'}),
};

String _money(
  MoneyFormatter formatter,
  int? amount,
  bool hidden, {
  bool positive = false,
  String unavailableLabel = 'Unavailable',
}) => hidden
    ? '••••'
    : amount == null
    ? unavailableLabel
    : '${positive && amount > 0 ? '+' : ''}${formatter.formatMinor(amount)}';
