import '../../../core/money/money.dart';
import '../../../core/time/year_month.dart';
import '../../screen_1_financial/screen_1_financial.dart';
import '../../screen_2_extra_income/screen_2_extra_income.dart';
import '../../screen_3_investments/domain/fx_quote_set.dart';
import '../../screen_3_investments/domain/investment_holding.dart';
import '../../screen_3_investments/domain/investment_repository.dart';
import '../../screen_4_objectives/domain/financial_objective.dart';
import '../../screen_4_objectives/domain/objective_repository.dart';
import '../domain/general_report_document.dart';
import '../domain/report_period.dart';

final class GeneralReportService {
  const GeneralReportService({
    required this.financial,
    required this.extraIncome,
    this.investments,
    this.objectives,
    this.fxRepository = const OfflineDemonstrationFxRepository(),
  });
  final MonthlyFinancialReportPort financial;
  final ExtraIncomeContributionPort extraIncome;
  final InvestmentRepository? investments;
  final ObjectiveRepository? objectives;
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
    var savedObjectives = <FinancialObjective>[];
    if (objectives != null) {
      try {
        savedObjectives = await objectives!.loadAll();
      } catch (_) {
        savedObjectives = [];
      }
    }
    for (var index = 0; index < count; index++) {
      final month = start.addMonths(index);
      final snapshot = await financial.snapshotFor(month, fx: fx);
      var extra = 0;
      var extraItems = <ReportExtraIncomeItem>[];
      var investmentItems = <ReportInvestmentItem>[];
      var objectiveItems = <ReportObjectiveItem>[];
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
      if (investments != null) {
        try {
          final positions = await investments!.listForMonth(month);
          investmentItems = [
            for (final holding in InvestmentHolding.group(
              positions.where((item) => item.active),
            ))
              ReportInvestmentItem(
                identity: holding.identity,
                principalMinor: holding.principalMinor,
                monthlyReturnMinor: holding.monthlyReturnMinor,
                quantity: holding.quantity,
              ),
          ];
        } catch (_) {
          investmentItems = [];
        }
      }
      if (objectives != null) {
        objectiveItems = [
          for (final objective in savedObjectives)
            if (objective.startMonth.compareTo(month) <= 0)
              ?_snapshotObjective(objective, month, fx, currency),
        ];
      }
      pages.add(
        MonthlyReportPage(
          financial: snapshot,
          extraIncomeMinor: extra,
          extraIncomeItems: List.unmodifiable(extraItems),
          investments: List.unmodifiable(investmentItems),
          objectives: List.unmodifiable(objectiveItems),
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

  ReportObjectiveItem? _snapshotObjective(
    FinancialObjective objective,
    YearMonth month,
    FxQuoteSet fx,
    CurrencyCode baseCurrency,
  ) {
    final history = ObjectiveEvolution.calculate(
      objective,
      throughMonth: month,
    );
    if (history.isEmpty) return null;
    final closing = history.last;
    final thisMonth = history.where((item) => item.month == month).firstOrNull;
    if (thisMonth == null) return null;
    int convert(int amount) => objective.currency == baseCurrency
        ? amount
        : fx.convertToBaseMinor(amount, objective.currency) ?? amount;
    return ReportObjectiveItem(
      id: objective.id,
      name: objective.name,
      currency: baseCurrency,
      balanceMinor: convert(closing.closingBalanceMinor),
      targetMinor: convert(objective.targetAmountMinor),
      contributionMinor: convert(thisMonth.contributionMinor),
      monthlyYieldMinor: convert(thisMonth.yieldMinor),
      yieldIsEstimate: thisMonth.yieldIsEstimate,
    );
  }
}
