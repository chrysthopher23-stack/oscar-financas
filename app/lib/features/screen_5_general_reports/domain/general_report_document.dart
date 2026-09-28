import '../../../core/money/money.dart';
import '../../../core/time/year_month.dart';
import '../../screen_1_financial/screen_1_financial.dart';
import '../../screen_3_investments/domain/asset_family.dart';
import '../../screen_3_investments/domain/instrument_identity.dart';
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

final class ReportInvestmentItem {
  const ReportInvestmentItem({
    required this.identity,
    required this.principalMinor,
    required this.monthlyReturnMinor,
    required this.quantity,
  });

  final InstrumentIdentity identity;
  final int principalMinor;
  final int monthlyReturnMinor;
  final String? quantity;
  int get recordedValueMinor => principalMinor + monthlyReturnMinor;
  AssetFamily get family => identity.family;
  bool get isCrypto => family == AssetFamily.crypto;
}

final class ReportObjectiveItem {
  const ReportObjectiveItem({
    required this.id,
    required this.name,
    required this.currency,
    required this.balanceMinor,
    required this.targetMinor,
    required this.contributionMinor,
    required this.monthlyYieldMinor,
    required this.yieldIsEstimate,
  });

  final String id;
  final String name;
  final CurrencyCode currency;
  final int balanceMinor;
  final int targetMinor;
  final int contributionMinor;
  final int monthlyYieldMinor;
  final bool yieldIsEstimate;
  int get progressBasisPoints => targetMinor <= 0
      ? 0
      : ((balanceMinor * 10000) ~/ targetMinor).clamp(0, 10000);
  bool get isEmergencyReserve =>
      id == 'objective:demo-emergency-reserve' ||
      name.toLowerCase().contains('reserva') ||
      name.toLowerCase().contains('emergency fund') ||
      name.toLowerCase().contains('notgroschen') ||
      name.toLowerCase().contains('fonds d’urgence') ||
      name.toLowerCase().contains("fonds d'urgence") ||
      name.contains('आपातकालीन निधि');
}

enum ReportAccessTier { basic, plus, pro }

final class MonthlyReportPage {
  const MonthlyReportPage({
    required this.financial,
    required this.extraIncomeMinor,
    this.extraIncomeItems = const [],
    this.investments = const [],
    this.objectives = const [],
  });
  final MonthlyFinancialSnapshot financial;
  final int extraIncomeMinor;
  final List<ReportExtraIncomeItem> extraIncomeItems;
  final List<ReportInvestmentItem> investments;
  final List<ReportObjectiveItem> objectives;
  List<ReportInvestmentItem> get assets =>
      investments.where((item) => !item.isCrypto).toList(growable: false);
  List<ReportInvestmentItem> get cryptoassets =>
      investments.where((item) => item.isCrypto).toList(growable: false);
  ReportObjectiveItem? get emergencyReserve =>
      objectives.where((item) => item.isEmergencyReserve).firstOrNull;
  bool get hasContinuationPage =>
      assets.isNotEmpty || cryptoassets.isNotEmpty || objectives.isNotEmpty;
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
  int get pdfPageCount => pages.fold<int>(
    0,
    (total, page) => total + (page.hasContinuationPage ? 2 : 1),
  );
  int pdfPageStartForMonth(int index) =>
      1 +
      pages
          .take(index)
          .fold<int>(
            0,
            (total, page) => total + (page.hasContinuationPage ? 2 : 1),
          );
  int pdfPageCountForMonth(int index) =>
      pages[index].hasContinuationPage ? 2 : 1;
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
