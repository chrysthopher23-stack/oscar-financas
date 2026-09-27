import '../../../core/money/money.dart';
import '../../../core/time/year_month.dart';
import '../../screen_1_financial/screen_1_financial.dart';
import '../../screen_2_extra_income/screen_2_extra_income.dart';
import '../../screen_3_investments/domain/fx_quote_set.dart';
import '../domain/general_report_document.dart';
import '../domain/report_period.dart';

final class GeneralReportService {
  const GeneralReportService({
    required this.financial,
    required this.extraIncome,
    this.fxRepository = const OfflineDemonstrationFxRepository(),
  });
  final MonthlyFinancialReportPort financial;
  final ExtraIncomeContributionPort extraIncome;
  final FxRepository fxRepository;

  Future<GeneralReportDocument> generate({
    required ReportPeriod period,
    required YearMonth currentMonth,
    required String localeTag,
    required CurrencyCode currency,
  }) async {
    final count = monthsForPeriod(period);
    final start = currentMonth.addMonths(-(count - 1));
    final pages = <MonthlyReportPage>[];
    final fx =
        await fxRepository.latest(currency) ??
        (await const OfflineDemonstrationFxRepository().latest(currency));
    for (var index = 0; index < count; index++) {
      final month = start.addMonths(index);
      final snapshot = await financial.snapshotFor(month, fx: fx);
      var extra = 0;
      var extraItems = <ReportExtraIncomeItem>[];
      try {
        final entries = await extraIncome.includedEntriesFor(month);
        extraItems = [
          for (final entry in entries.where((item) => item.active))
            if (fx.convertToBaseMinor(entry.amountMinor, entry.currency)
                case final amount?)
              ReportExtraIncomeItem(
                title: entry.name,
                description: entry.description,
                amountMinor: amount,
              ),
        ];
        extra = extraItems.fold<int>(
          0,
          (sum, entry) => sum + entry.amountMinor,
        );
      } catch (_) {
        extra = 0;
        extraItems = [];
      }
      pages.add(
        MonthlyReportPage(
          financial: snapshot,
          extraIncomeMinor: extra,
          extraIncomeItems: List.unmodifiable(extraItems),
        ),
      );
    }
    return GeneralReportDocument(
      period: period,
      pages: List.unmodifiable(pages),
      localeTag: localeTag,
      currency: currency,
      generatedAt: DateTime.now(),
    );
  }
}
