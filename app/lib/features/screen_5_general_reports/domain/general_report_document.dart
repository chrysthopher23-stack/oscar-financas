import '../../../core/money/money.dart';
import '../../../core/time/year_month.dart';
import '../../screen_1_financial/screen_1_financial.dart';
import 'report_period.dart';

final class ReportExtraIncomeItem {
  const ReportExtraIncomeItem({
    required this.title,
    required this.description,
    required this.amountMinor,
  });

  final String title;
  final String description;
  final int amountMinor;
}

enum ReportAccessTier { basic, plus, pro }

final class MonthlyReportPage {
  const MonthlyReportPage({
    required this.financial,
    required this.extraIncomeMinor,
    this.extraIncomeItems = const [],
  });
  final MonthlyFinancialSnapshot financial;
  final int extraIncomeMinor;
  final List<ReportExtraIncomeItem> extraIncomeItems;
  YearMonth get month => financial.month;
  int get totalIncomeMinor => financial.mainIncomeMinor + extraIncomeMinor;
  int get netMinor => totalIncomeMinor - financial.expenseMinor;
}

final class GeneralReportDocument {
  const GeneralReportDocument({
    required this.period,
    required this.pages,
    required this.localeTag,
    required this.currency,
    required this.generatedAt,
  });
  final ReportPeriod period;
  final List<MonthlyReportPage> pages;
  final String localeTag;
  final CurrencyCode currency;
  final DateTime generatedAt;
  int get pageCount => pages.length;
  bool get usesLetterPaper => localeTag == 'en-US';
}

int monthsForPeriod(ReportPeriod period) => switch (period) {
  ReportPeriod.currentMonth => 1,
  ReportPeriod.last3Months => 3,
  ReportPeriod.last6Months => 6,
  ReportPeriod.annual => 12,
};

bool canGenerateReport(ReportAccessTier tier, ReportPeriod period) =>
    switch (period) {
      ReportPeriod.currentMonth => true,
      ReportPeriod.last3Months => tier.index >= ReportAccessTier.plus.index,
      ReportPeriod.last6Months ||
      ReportPeriod.annual => tier == ReportAccessTier.pro,
    };
