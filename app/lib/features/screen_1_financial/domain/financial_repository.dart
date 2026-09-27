import '../../../core/money/money.dart';
import '../../../core/time/year_month.dart';
import 'financial_transaction.dart';
import 'monthly_summary.dart';

abstract interface class FinancialRepository {
  Future<List<FinancialTransaction>> transactionsFor(YearMonth month);
  Future<List<FinancialTransaction>> emergencyFundContributions(
    CurrencyCode currency,
  );
  Future<void> saveTransaction(FinancialTransaction transaction);
  Future<List<FinancialTransaction>> materializeRecurringTransactions(
    YearMonth month,
    CurrencyCode currency,
  );
  Future<void> softDelete(String id, DateTime deletedAt);
  Future<void> restore(String id);
  Future<List<int>> completedExpenseTotalsBefore(
    YearMonth month,
    CurrencyCode currency, {
    int limit = 3,
  });
  Future<({int balanceMinor, int targetMonths})> emergencyFund(
    CurrencyCode currency,
  );
  Future<void> saveEmergencyFund({
    required CurrencyCode currency,
    required int balanceMinor,
    required int targetMonths,
  });
  Future<void> saveSummary(MonthlySummary summary);
}
