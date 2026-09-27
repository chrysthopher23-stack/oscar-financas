import '../../../core/money/money.dart';
import '../../../core/time/year_month.dart';
import '../../screen_3_investments/domain/fx_quote_set.dart';
import '../../screen_4_objectives/domain/financial_objective.dart';

final class HomeObjectiveTotals {
  const HomeObjectiveTotals({
    required this.balanceMinor,
    required this.contributionsMinor,
    required this.targetMinor,
    required this.objectives,
  });

  final int? balanceMinor;
  final int? contributionsMinor;
  final int? targetMinor;
  final List<HomeObjectiveSummary> objectives;

  factory HomeObjectiveTotals.calculate({
    required Iterable<FinancialObjective> objectives,
    required YearMonth throughMonth,
    required CurrencyCode baseCurrency,
    required FxQuoteSet? fx,
  }) {
    var balance = 0;
    var contributions = 0;
    var target = 0;
    var canConvertAll = true;
    final summaries = <HomeObjectiveSummary>[];

    for (final objective in objectives) {
      final history = ObjectiveEvolution.calculate(
        objective,
        throughMonth: throughMonth,
      );
      final balanceInGoalCurrency = history.isEmpty
          ? objective.initialBalanceMinor
          : history.last.closingBalanceMinor;
      final contributionsInGoalCurrency =
          objective.initialBalanceMinor +
          history.fold<int>(0, (sum, item) => sum + item.contributionMinor);
      final convertedBalance = _convert(
        balanceInGoalCurrency,
        objective.currency,
        baseCurrency,
        fx,
      );
      final convertedContributions = _convert(
        contributionsInGoalCurrency,
        objective.currency,
        baseCurrency,
        fx,
      );
      final convertedTarget = _convert(
        objective.targetAmountMinor,
        objective.currency,
        baseCurrency,
        fx,
      );
      summaries.add(
        HomeObjectiveSummary(
          name: objective.name,
          balanceMinor: convertedBalance,
          contributionsMinor: convertedContributions,
          targetMinor: convertedTarget,
        ),
      );
      if (convertedBalance == null ||
          convertedContributions == null ||
          convertedTarget == null) {
        canConvertAll = false;
        continue;
      }
      balance += convertedBalance;
      contributions += convertedContributions;
      target += convertedTarget;
    }

    return HomeObjectiveTotals(
      balanceMinor: canConvertAll ? balance : null,
      contributionsMinor: canConvertAll ? contributions : null,
      targetMinor: canConvertAll ? target : null,
      objectives: List.unmodifiable(summaries),
    );
  }

  static int? _convert(
    int amountMinor,
    CurrencyCode source,
    CurrencyCode target,
    FxQuoteSet? fx,
  ) => source == target
      ? amountMinor
      : fx?.convertToBaseMinor(amountMinor, source);
}

final class HomeObjectiveSummary {
  const HomeObjectiveSummary({
    required this.name,
    required this.balanceMinor,
    required this.contributionsMinor,
    required this.targetMinor,
  });

  final String name;
  final int? balanceMinor;
  final int? contributionsMinor;
  final int? targetMinor;
}
