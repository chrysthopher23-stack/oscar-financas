import '../../../core/time/year_month.dart';
import 'extra_income_entry.dart';

abstract interface class ExtraIncomeRepository {
  Future<List<ExtraIncomeEntry>> entriesFor(YearMonth month);
  Future<void> saveEntry(ExtraIncomeEntry entry);
  Future<void> softDelete(String id, DateTime deletedAt);
  Future<void> restore(String id);
  Future<void> materializeRecurringEntries(YearMonth month);
}
