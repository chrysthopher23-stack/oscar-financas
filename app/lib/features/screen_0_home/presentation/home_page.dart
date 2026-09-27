import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as material show Text;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/navigation/app_destination.dart';
import '../../../app/history_experience_copy.dart';
import '../../../app/settings/app_preferences_controller.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/money/money.dart';
import '../../../core/time/year_month.dart';
import '../../../features/screen_1_financial/domain/financial_repository.dart';
import '../../../features/screen_1_financial/domain/financial_transaction.dart';
import '../../../features/screen_2_extra_income/domain/extra_income_entry.dart';
import '../../../features/screen_2_extra_income/domain/extra_income_repository.dart';
import '../../../features/screen_3_investments/domain/asset_family.dart';
import '../../../features/screen_3_investments/domain/asset_market_series.dart';
import '../../../features/screen_3_investments/domain/fx_quote_set.dart';
import '../../../features/screen_3_investments/domain/investment_position.dart';
import '../../../features/screen_3_investments/domain/investment_repository.dart';
import '../../../features/screen_4_objectives/domain/financial_objective.dart';
import '../../../features/screen_4_objectives/domain/objective_repository.dart';
import '../application/home_investment_totals.dart';
import '../application/home_objective_totals.dart';
import '../../../shared/controllers/financial_visibility_controller.dart';
import '../../../shared/formatting/money_formatter.dart';
import '../../../shared/widgets/financial_visibility_button.dart';
import '../../../shared/widgets/demo_display_names.dart';
import '../../../shared/widgets/localized_text.dart' show uiText;
import '../../../shared/widgets/oscar_feature_scaffold.dart';
import '../../../app/theme/app_colors.dart';
import 'widgets/investment_breakdown.dart';

final class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.onDestinationSelected,
    required this.visibilityController,
    required this.preferences,
    required this.financialRepository,
    required this.extraIncomeRepository,
    required this.investmentRepository,
    required this.objectiveRepository,
    required this.assetMarketRepository,
    required this.fxRepository,
    required this.initialData,
    this.welcomeCopy,
  });

  final ValueChanged<AppDestination> onDestinationSelected;
  final FinancialVisibilityController visibilityController;
  final AppPreferencesController preferences;
  final FinancialRepository financialRepository;
  final ExtraIncomeRepository extraIncomeRepository;
  final InvestmentRepository investmentRepository;
  final ObjectiveRepository objectiveRepository;
  final AssetMarketRepository assetMarketRepository;
  final FxRepository fxRepository;
  final Future<void> initialData;
  final HistoryExperienceCopy? welcomeCopy;

  @override
  State<HomePage> createState() => _HomePageState();
}

final class _HomePageState extends State<HomePage> {
  _HomeSummary? _summary;
  Object? _error;
  int _loadRevision = 0;

  @override
  void initState() {
    super.initState();
    widget.preferences.addListener(_load);
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showWelcomeOnce());
  }

  Future<void> _showWelcomeOnce() async {
    await widget.initialData;
    final preferences = await SharedPreferences.getInstance();
    const key = 'welcome.examples.seen.v1';
    if (!mounted ||
        preferences.getBool(key) == true ||
        preferences.getBool('history.personal-start.v1') == true) {
      return;
    }
    // Mark before showing so quick navigation cannot open a second dialog.
    await preferences.setBool(key, true);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: material.Text(
          (widget.welcomeCopy ??
                  HistoryExperienceCopy(widget.preferences.locale))
              .welcomeTitle,
        ),
        content: material.Text(
          (widget.welcomeCopy ??
                  HistoryExperienceCopy(widget.preferences.locale))
              .welcomeBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: material.Text(
              (widget.welcomeCopy ??
                      HistoryExperienceCopy(widget.preferences.locale))
                  .explore,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preferences != widget.preferences) {
      oldWidget.preferences.removeListener(_load);
      widget.preferences.addListener(_load);
    }
  }

  Future<void> _load() async {
    final revision = ++_loadRevision;
    setState(() => _error = null);
    try {
      await widget.initialData;
      final month = YearMonth.now();
      await Future.wait(
        CurrencyCode.values.map(
          (currency) => widget.financialRepository
              .materializeRecurringTransactions(month, currency),
        ),
      );
      final results = await Future.wait<Object>([
        widget.financialRepository.transactionsFor(month),
        widget.extraIncomeRepository.entriesFor(month),
        widget.investmentRepository.listForMonth(month),
        widget.objectiveRepository.loadAll(),
      ]);
      final transactions = (results[0] as List<FinancialTransaction>)
          .where((item) => item.active)
          .toList();
      final extraEntries = (results[1] as List<ExtraIncomeEntry>)
          .where((item) => item.active)
          .toList();
      final positions = (results[2] as List<InvestmentPosition>)
          .where((item) => item.active)
          .toList();
      final objectives = results[3] as List<FinancialObjective>;
      final base = widget.preferences.currency;
      final hasForeignCurrency = [
        ...transactions.map((item) => item.currency),
        ...extraEntries.map((item) => item.currency),
        ...positions.map((item) => item.currency),
        ...objectives.map((item) => item.currency),
      ].any((currency) => currency != base);
      final fx = hasForeignCurrency
          ? await widget.fxRepository.latest(base)
          : null;
      int convert(int value, CurrencyCode currency) => currency == base
          ? value
          : fx?.convertToBaseMinor(value, currency) ?? 0;
      var income = 0;
      var expenses = 0;
      for (final item in transactions) {
        if (item.kind == TransactionKind.income) {
          income += convert(item.netAmountMinor, item.currency);
        } else {
          expenses += convert(item.netAmountMinor, item.currency);
        }
      }
      var services = 0;
      var sales = 0;
      var includedExtra = 0;
      for (final item in extraEntries) {
        final amount = convert(item.amountMinor, item.currency);
        if (item.kind == ExtraIncomeKind.service) {
          services += amount;
        } else {
          sales += amount;
        }
        if (item.includeInFinancialIncome) includedExtra += amount;
      }
      final investmentTotals = HomeInvestmentTotals.fromPositions(
        positions,
        baseCurrency: base,
        fx: fx,
      );
      final objectiveTotals = HomeObjectiveTotals.calculate(
        objectives: objectives,
        throughMonth: month,
        baseCurrency: base,
        fx: fx,
      );
      if (!mounted || revision != _loadRevision) return;
      setState(() {
        _summary = _HomeSummary(
          income: income,
          expenses: expenses,
          includedExtra: includedExtra,
          services: services,
          sales: sales,
          investments: investmentTotals,
          objectiveTotals: objectiveTotals,
        );
      });
      if (investmentTotals.cryptoCount > 0) {
        unawaited(
          _refreshCryptoVariation(revision: revision, positions: positions),
        );
      }
    } catch (error) {
      if (mounted && revision == _loadRevision) setState(() => _error = error);
    }
  }

  Future<void> _refreshCryptoVariation({
    required int revision,
    required List<InvestmentPosition> positions,
  }) async {
    final crypto = positions
        .where((position) => position.identity.family == AssetFamily.crypto)
        .toList(growable: false);
    if (crypto.isEmpty) return;
    try {
      final series = await widget.assetMarketRepository.latestFor(
        crypto.map((position) => position.identity).toList(growable: false),
        includeHistory: false,
      );
      if (!mounted || revision != _loadRevision) return;
      final current = _summary;
      if (current == null) return;
      setState(() {
        _summary = current.copyWith(
          investments: current.investments.withCryptoMarketData(series),
        );
      });
    } catch (_) {
      // Market data is optional; keep the locally available portfolio totals.
    }
  }

  @override
  void dispose() {
    widget.preferences.removeListener(_load);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final formatter = MoneyFormatter(
      locale: locale,
      currency: widget.preferences.currency,
    );
    final month = YearMonth.now();
    final rawMonthName = DateFormat.MMMM(
      Localizations.localeOf(context).toString(),
    ).format(DateTime(month.year, month.month));
    final monthName = rawMonthName.isEmpty
        ? rawMonthName
        : '${rawMonthName.substring(0, 1).toUpperCase()}${rawMonthName.substring(1)}';
    return OscarFeatureScaffold(
      destination: AppDestination.home,
      onDestinationSelected: widget.onDestinationSelected,
      headerKind: FeatureHeaderKind.menuOnly,
      actions: [
        FinancialVisibilityButton(controller: widget.visibilityController),
        const SizedBox(width: 4),
      ],
      body: ListenableBuilder(
        listenable: widget.visibilityController,
        builder: (context, _) {
          final hidden = widget.visibilityController.valuesHidden;
          final summary = _summary;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            children: [
              Text(
                uiText(context, 'Resumo de $monthName'),
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              _SummaryCard(
                icon: Icons.bar_chart_rounded,
                title: strings.text('home.block.financial'),
                subtitle: strings.text('Sua vida financeira em um só lugar'),
                valueLabel: strings.text('Saldo do mês'),
                value: summary == null
                    ? null
                    : summary.income + summary.includedExtra - summary.expenses,
                detailLeftLabel: strings.text('Entradas'),
                detailLeftValue: summary == null
                    ? null
                    : summary.income + summary.includedExtra,
                detailRightLabel: strings.text('Gastos'),
                detailRightValue: summary?.expenses,
                detailRightColor: AppColors.ruby,
                formatter: formatter,
                hidden: hidden,
                loading: summary == null && _error == null,
                error: _error != null,
                onTap: () =>
                    widget.onDestinationSelected(AppDestination.financial),
              ),
              const SizedBox(height: 3),
              _SummaryCard(
                icon: Icons.account_balance_wallet_outlined,
                title: strings.text('home.block.extraIncome'),
                subtitle: strings.text('Renda além do seu salário'),
                valueLabel: strings.text('Total no mês'),
                value: summary == null
                    ? null
                    : summary.services + summary.sales,
                detailLeftLabel: strings.text('Serviços'),
                detailLeftValue: summary?.services,
                detailRightLabel: strings.text('Vendas'),
                detailRightValue: summary?.sales,
                formatter: formatter,
                hidden: hidden,
                loading: summary == null && _error == null,
                error: _error != null,
                onTap: () =>
                    widget.onDestinationSelected(AppDestination.extraIncome),
              ),
              const SizedBox(height: 3),
              _SummaryCard(
                icon: Icons.trending_up_rounded,
                title: strings.text('home.block.investments'),
                subtitle: strings.text('Seu patrimônio trabalhando por você'),
                valueLabel: strings.text('Total investido'),
                value: summary?.investments.totalValueMinor,
                footer: summary == null
                    ? null
                    : InvestmentBreakdown(
                        totals: summary.investments,
                        formatter: formatter,
                        locale: locale,
                        valuesHidden: hidden,
                      ),
                formatter: formatter,
                hidden: hidden,
                loading: summary == null && _error == null,
                error: _error != null,
                onTap: () =>
                    widget.onDestinationSelected(AppDestination.investments),
              ),
              const SizedBox(height: 3),
              _SummaryCard(
                icon: Icons.account_balance_outlined,
                title: strings.text('home.block.objectives'),
                subtitle: strings.text('Acompanhe o progresso das suas metas'),
                valueLabel: strings.text('Saldo dos objetivos'),
                value: summary?.objectiveTotals.balanceMinor,
                detailLeftLabel: strings.text('Total acumulado'),
                detailLeftValue: summary?.objectiveTotals.contributionsMinor,
                detailRightLabel: strings.text('Meta total'),
                detailRightValue: summary?.objectiveTotals.targetMinor,
                footer: summary == null
                    ? null
                    : _ObjectiveSummaries(
                        objectives: summary.objectiveTotals.objectives,
                        formatter: formatter,
                        hidden: hidden,
                        error: _error != null,
                      ),
                formatter: formatter,
                hidden: hidden,
                loading: summary == null && _error == null,
                error: _error != null,
                onTap: () =>
                    widget.onDestinationSelected(AppDestination.objectives),
              ),
            ],
          );
        },
      ),
    );
  }
}

final class _ObjectiveSummaries extends StatelessWidget {
  const _ObjectiveSummaries({
    required this.objectives,
    required this.formatter,
    required this.hidden,
    required this.error,
  });

  final List<HomeObjectiveSummary> objectives;
  final MoneyFormatter formatter;
  final bool hidden;
  final bool error;

  @override
  Widget build(BuildContext context) {
    if (objectives.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < objectives.length; index++) ...[
          if (index > 0) const Divider(height: 12),
          _ObjectiveSummaryRow(
            objective: objectives[index],
            formatter: formatter,
            hidden: hidden,
            error: error,
            balanceLabel: strings.text('objectives.currentBalance'),
            contributionLabel: strings.text('Aportes acumulados'),
            targetLabel: strings.text('Meta'),
            theme: theme,
          ),
        ],
      ],
    );
  }
}

final class _ObjectiveSummaryRow extends StatelessWidget {
  const _ObjectiveSummaryRow({
    required this.objective,
    required this.formatter,
    required this.hidden,
    required this.error,
    required this.balanceLabel,
    required this.contributionLabel,
    required this.targetLabel,
    required this.theme,
  });

  final HomeObjectiveSummary objective;
  final MoneyFormatter formatter;
  final bool hidden;
  final bool error;
  final String balanceLabel;
  final String contributionLabel;
  final String targetLabel;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    String amount(int? value) => value == null
        ? '—'
        : hidden
        ? '••••'
        : formatter.formatMinor(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        material.Text(
          demoGoalName(context, objective.name),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(
              child: Text(
                balanceLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              amount(objective.balanceMinor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: error
                    ? theme.colorScheme.onSurfaceVariant
                    : AppColors.emerald,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _Detail(
                label: contributionLabel,
                value: objective.contributionsMinor,
                formatter: formatter,
                hidden: hidden,
                error: error,
              ),
            ),
            Container(
              width: 1,
              height: 24,
              color: theme.colorScheme.outlineVariant,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: _Detail(
                  label: targetLabel,
                  value: objective.targetMinor,
                  formatter: formatter,
                  hidden: hidden,
                  error: error,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

final class _HomeSummary {
  const _HomeSummary({
    required this.income,
    required this.expenses,
    required this.includedExtra,
    required this.services,
    required this.sales,
    required this.investments,
    required this.objectiveTotals,
  });

  final int income;
  final int expenses;
  final int includedExtra;
  final int services;
  final int sales;
  final HomeInvestmentTotals investments;
  final HomeObjectiveTotals objectiveTotals;

  _HomeSummary copyWith({HomeInvestmentTotals? investments}) => _HomeSummary(
    income: income,
    expenses: expenses,
    includedExtra: includedExtra,
    services: services,
    sales: sales,
    investments: investments ?? this.investments,
    objectiveTotals: objectiveTotals,
  );
}

final class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.valueLabel,
    required this.value,
    required this.formatter,
    required this.hidden,
    required this.loading,
    required this.error,
    required this.onTap,
    this.detailLeftLabel,
    this.detailLeftValue,
    this.detailRightLabel,
    this.detailRightValue,
    this.footer,
    this.detailRightColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String valueLabel;
  final int? value;
  final MoneyFormatter formatter;
  final bool hidden;
  final bool loading;
  final bool error;
  final VoidCallback onTap;
  final String? detailLeftLabel;
  final int? detailLeftValue;
  final String? detailRightLabel;
  final int? detailRightValue;
  final Widget? footer;
  final Color? detailRightColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = AppStrings.of(context);
    final mainValue = loading
        ? text.text('Carregando resumo…')
        : error || value == null
        ? text.text('Resumo indisponível')
        : hidden
        ? '••••'
        : formatter.formatMinor(value!);
    final hasDetails = detailLeftLabel != null && detailRightLabel != null;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 10, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 24, color: AppColors.gold),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: AppColors.gold, size: 24),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Text(
                      mainValue,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: error
                            ? theme.colorScheme.onSurfaceVariant
                            : (value ?? 0) < 0
                            ? AppColors.ruby
                            : AppColors.emerald,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      valueLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              if (hasDetails) ...[
                const SizedBox(height: 3),
                Row(
                  children: [
                    Expanded(
                      child: _Detail(
                        label: detailLeftLabel!,
                        value: detailLeftValue,
                        formatter: formatter,
                        hidden: hidden,
                        error: error,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 24,
                      color: theme.colorScheme.outlineVariant,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: _Detail(
                          label: detailRightLabel!,
                          value: detailRightValue,
                          formatter: formatter,
                          hidden: hidden,
                          error: error,
                          valueColor: detailRightColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (footer != null) ...[const SizedBox(height: 3), footer!],
            ],
          ),
        ),
      ),
    );
  }
}

final class _Detail extends StatelessWidget {
  const _Detail({
    required this.label,
    required this.value,
    required this.formatter,
    required this.hidden,
    required this.error,
    this.valueColor,
  });
  final String label;
  final int? value;
  final MoneyFormatter formatter;
  final bool hidden;
  final bool error;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: 10.5,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      Text(
        value == null
            ? '—'
            : hidden
            ? '••••'
            : formatter.formatMinor(value!),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: 11,
          color: error
              ? Theme.of(context).colorScheme.onSurfaceVariant
              : valueColor ?? AppColors.emerald,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}
