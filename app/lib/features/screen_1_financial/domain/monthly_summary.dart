import '../../../core/money/money.dart';
import '../../../core/time/year_month.dart';
import 'financial_transaction.dart';

final class MonthlySummary {
  const MonthlySummary({
    required this.month,
    required this.currency,
    required this.incomeMinor,
    required this.expenseMinor,
    required this.extraIncomeMinor,
    required this.sourceRevision,
  });

  final YearMonth month;
  final CurrencyCode currency;
  final int incomeMinor;
  final int expenseMinor;
  final int extraIncomeMinor;
  final int sourceRevision;

  int get grossIncomeMinor => incomeMinor + extraIncomeMinor;
  int get netMinor =>
      (grossIncomeMinor - expenseMinor).clamp(0, grossIncomeMinor);
  int get deficitMinor =>
      (expenseMinor - grossIncomeMinor).clamp(0, expenseMinor);
  int get savingsRateBasisPoints =>
      grossIncomeMinor == 0 ? 0 : (netMinor * 10000) ~/ grossIncomeMinor;
}

abstract final class MonthlySummaryCalculator {
  static MonthlySummary calculate({
    required YearMonth month,
    required CurrencyCode currency,
    required Iterable<FinancialTransaction> transactions,
    required int extraIncomeMinor,
    required int sourceRevision,
  }) {
    var income = 0;
    var expenses = 0;
    for (final transaction in transactions) {
      if (!transaction.active || transaction.month != month) continue;
      if (transaction.currency != currency) {
        throw ArgumentError('Currencies cannot be mixed in a monthly summary.');
      }
      if (transaction.kind == TransactionKind.income) {
        income += transaction.netAmountMinor;
      } else {
        expenses += transaction.netAmountMinor;
      }
    }
    return MonthlySummary(
      month: month,
      currency: currency,
      incomeMinor: income,
      expenseMinor: expenses,
      extraIncomeMinor: extraIncomeMinor,
      sourceRevision: sourceRevision,
    );
  }
}
