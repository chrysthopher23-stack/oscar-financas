import 'package:flutter_test/flutter_test.dart';
import 'package:oscar_financas/core/money/money.dart';
import 'package:oscar_financas/core/time/year_month.dart';
import 'package:oscar_financas/features/screen_1_financial/domain/emergency_fund.dart';
import 'package:oscar_financas/features/screen_1_financial/domain/expense_share.dart';
import 'package:oscar_financas/features/screen_1_financial/domain/financial_score.dart';
import 'package:oscar_financas/features/screen_1_financial/domain/financial_transaction.dart';
import 'package:oscar_financas/features/screen_1_financial/domain/installment_plan.dart';
import 'package:oscar_financas/features/screen_1_financial/domain/monthly_summary.dart';

void main() {
  const month = YearMonth(2027, 3);

  FinancialTransaction transaction(
    String id,
    TransactionKind kind,
    int value, {
    DiscountType discountType = DiscountType.none,
    int discountValue = 0,
  }) => FinancialTransaction(
    id: id,
    title: id,
    kind: kind,
    originalAmountMinor: value,
    currency: CurrencyCode.brl,
    month: month,
    discountType: discountType,
    discountValue: discountValue,
  );

  test('calculates the canonical 5000 / 3580 / 1420 scenario', () {
    final summary = MonthlySummaryCalculator.calculate(
      month: month,
      currency: CurrencyCode.brl,
      transactions: [
        transaction('income', TransactionKind.income, 500000),
        transaction('expense', TransactionKind.expense, 358000),
      ],
      extraIncomeMinor: 0,
      sourceRevision: 1,
    );

    expect(summary.grossIncomeMinor, 500000);
    expect(summary.expenseMinor, 358000);
    expect(summary.netMinor, 142000);
    expect(summary.deficitMinor, 0);
  });

  test('fixed and percentage discounts can produce the same result', () {
    final fixed = transaction(
      'fixed',
      TransactionKind.expense,
      50000,
      discountType: DiscountType.fixed,
      discountValue: 5000,
    );
    final percentage = transaction(
      'percentage',
      TransactionKind.expense,
      50000,
      discountType: DiscountType.percentage,
      discountValue: 1000,
    );

    expect(fixed.netAmountMinor, 45000);
    expect(percentage.netAmountMinor, 45000);
  });

  test('emergency fund covers 2.4 months and reaches 80 percent', () {
    final result = EmergencyFundCalculator.calculate(
      balanceMinor: 720000,
      targetMonths: 3,
      completedMonthlyExpensesMinor: const [300000, 300000, 300000],
    );

    expect(result.coverageMilliMonths, 2400);
    expect(result.progressBasisPoints, 8000);
  });

  test('Oscar Score boundaries have no overlap', () {
    FinancialScoreLevel levelAt(int netMinor) {
      final summary = MonthlySummary(
        month: month,
        currency: CurrencyCode.brl,
        incomeMinor: 1000000,
        expenseMinor: 1000000 - netMinor,
        extraIncomeMinor: 0,
        sourceRevision: 1,
      );
      return FinancialScoreCalculator.calculate(summary).level!;
    }

    expect(levelAt(99900), FinancialScoreLevel.critical);
    expect(levelAt(100000), FinancialScoreLevel.tight);
    expect(levelAt(300000), FinancialScoreLevel.balanced);
    expect(levelAt(500000), FinancialScoreLevel.healthy);
    expect(levelAt(700000), FinancialScoreLevel.healthy);
    expect(levelAt(701000), FinancialScoreLevel.prosperous);
  });

  test('expense shares preserve 130 percent commitment', () {
    final shares = ExpenseShareCalculator.calculate(
      expenses: [
        transaction('a', TransactionKind.expense, 80000),
        transaction('b', TransactionKind.expense, 50000),
      ],
      grossIncomeMinor: 100000,
    );
    expect(
      shares.fold<int>(0, (total, share) => total + share.basisPoints),
      13000,
    );
  });

  test('installment remainder is deterministic in the last occurrence', () {
    final occurrences = InstallmentCalculator.distribute(
      totalMinor: 100,
      count: 3,
      firstMonth: const YearMonth(2026, 12),
    );
    expect(occurrences.map((item) => item.amountMinor), [33, 33, 34]);
    expect(occurrences.last.month, const YearMonth(2027, 2));
  });
}
