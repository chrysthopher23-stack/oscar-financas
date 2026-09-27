import 'package:flutter_test/flutter_test.dart';
import 'package:oscar_financas/core/money/money.dart';
import 'package:oscar_financas/core/time/year_month.dart';
import 'package:oscar_financas/features/screen_0_home/application/home_objective_totals.dart';
import 'package:oscar_financas/features/screen_4_objectives/domain/financial_objective.dart';

void main() {
  test('summarizes every objective through the selected current month', () {
    final objectives = [
      FinancialObjective(
        id: 'reserve',
        name: 'Reserva de emergência',
        instrument: 'Treasury',
        targetMonths: 6,
        initialBalanceMinor: 0,
        targetAmountMinor: 2000000,
        annualRateBasisPoints: 400,
        monthlyContributionMinor: 30000,
        frequency: ObjectiveContributionFrequency.monthly,
        startMonth: const YearMonth(2026, 4),
        currency: CurrencyCode.usd,
      ),
      FinancialObjective(
        id: 'trip',
        name: 'Viagem',
        instrument: 'Savings',
        targetMonths: 4,
        initialBalanceMinor: 10000,
        targetAmountMinor: 50000,
        annualRateBasisPoints: 0,
        monthlyContributionMinor: 5000,
        frequency: ObjectiveContributionFrequency.monthly,
        startMonth: const YearMonth(2026, 8),
        currency: CurrencyCode.usd,
      ),
    ];

    final totals = HomeObjectiveTotals.calculate(
      objectives: objectives,
      throughMonth: const YearMonth(2026, 9),
      baseCurrency: CurrencyCode.usd,
      fx: null,
    );

    expect(totals.balanceMinor, greaterThan(200000));
    expect(totals.contributionsMinor, 200000);
    expect(totals.targetMinor, 2050000);
    expect(totals.objectives.map((objective) => objective.name), [
      'Reserva de emergência',
      'Viagem',
    ]);
    expect(totals.objectives.first.contributionsMinor, 180000);
    expect(totals.objectives.last.targetMinor, 50000);
  });
}
