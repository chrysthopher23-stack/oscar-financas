import '../../../core/money/money.dart';
import '../../../core/time/year_month.dart';
import '../../screen_3_investments/domain/fx_quote_set.dart';

final class ReportExpenseItem {
  const ReportExpenseItem({required this.title, required this.amountMinor});
  final String title;
  final int amountMinor;
}

final class MonthlyFinancialSnapshot {
  const MonthlyFinancialSnapshot({
    required this.month,
    required this.currency,
    required this.mainIncomeMinor,
    required this.expenseMinor,
    required this.installmentMinor,
    required this.netMinor,
    required this.score,
    required this.scoreLabel,
    required this.reserveBalanceMinor,
    required this.reserveCoverageMilliMonths,
    required this.expenses,
  });
  final YearMonth month;
  final CurrencyCode currency;
  final int mainIncomeMinor;
  final int expenseMinor;
  final int installmentMinor;
  final int netMinor;
  final int? score;
  final String scoreLabel;
  final int reserveBalanceMinor;
  final int reserveCoverageMilliMonths;
  final List<ReportExpenseItem> expenses;
  bool get hasMovement => mainIncomeMinor != 0 || expenseMinor != 0;
}

abstract interface class MonthlyFinancialReportPort {
  Future<MonthlyFinancialSnapshot> snapshotFor(
    YearMonth month, {
    FxQuoteSet? fx,
  });
}
