import '../../../core/time/year_month.dart';
import '../domain/extra_income_entry.dart';

abstract interface class ExtraIncomeContributionPort {
  Future<int> includedMinorUnitsFor(YearMonth month);
  Future<List<ExtraIncomeEntry>> includedEntriesFor(YearMonth month);
}
