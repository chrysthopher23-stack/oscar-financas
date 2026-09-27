import '../../../core/money/money.dart';
import '../../../core/time/year_month.dart';
import '../domain/emergency_fund.dart';
import '../domain/financial_repository.dart';
import '../domain/financial_score.dart';
import '../domain/financial_transaction.dart';
import '../../screen_3_investments/domain/fx_quote_set.dart';
import '../domain/monthly_summary.dart';
import 'financial_snapshot_port.dart';

final class MonthlyFinancialReportAdapter
    implements MonthlyFinancialReportPort {
  const MonthlyFinancialReportAdapter(
    this._repository,
    this._currency, {
    this.fxRepository = const OfflineDemonstrationFxRepository(),
  });
  final FinancialRepository _repository;
  final CurrencyCode _currency;
  final FxRepository fxRepository;

  @override
  Future<MonthlyFinancialSnapshot> snapshotFor(
    YearMonth month, {
    FxQuoteSet? fx,
  }) async {
    final effectiveFx =
        fx ??
        await fxRepository.latest(_currency) ??
        (await const OfflineDemonstrationFxRepository().latest(_currency));
    final transactions = (await _repository.transactionsFor(month))
        .map((item) => _convertReportTransaction(item, _currency, effectiveFx))
        .where((item) => item.active)
        .toList();
    final incomes = transactions
        .where((item) => item.kind == TransactionKind.income)
        .toList();
    final expenses = transactions
        .where((item) => item.kind == TransactionKind.expense)
        .toList();
    final incomeMinor = incomes.fold<int>(
      0,
      (sum, item) => sum + item.netAmountMinor,
    );
    final expenseMinor = expenses.fold<int>(
      0,
      (sum, item) => sum + item.netAmountMinor,
    );
    final installments = expenses
        .where((item) => item.installmentLabel != null)
        .fold<int>(0, (sum, item) => sum + item.netAmountMinor);
    final summary = MonthlySummary(
      month: month,
      currency: _currency,
      incomeMinor: incomeMinor,
      expenseMinor: expenseMinor,
      extraIncomeMinor: 0,
      sourceRevision: 0,
    );
    final score = FinancialScoreCalculator.calculate(summary);
    final funds = await Future.wait(
      CurrencyCode.values.map(_repository.emergencyFund),
    );
    final fundBalance = CurrencyCode.values.indexed.fold<int>(
      0,
      (sum, entry) =>
          sum +
          (effectiveFx.convertToBaseMinor(
                funds[entry.$1].balanceMinor,
                entry.$2,
              ) ??
              0),
    );
    final fundTarget =
        funds
            .where((item) => item.balanceMinor > 0)
            .map((item) => item.targetMonths)
            .firstOrNull ??
        6;
    final history = await _repository.completedExpenseTotalsBefore(
      month,
      _currency,
      limit: 3,
    );
    final reserve = EmergencyFundCalculator.calculate(
      balanceMinor: fundBalance,
      targetMonths: fundTarget,
      completedMonthlyExpensesMinor: history.isEmpty ? [expenseMinor] : history,
    );
    expenses.sort((a, b) => b.netAmountMinor.compareTo(a.netAmountMinor));
    return MonthlyFinancialSnapshot(
      month: month,
      currency: _currency,
      mainIncomeMinor: incomeMinor,
      expenseMinor: expenseMinor,
      installmentMinor: installments,
      netMinor: incomeMinor - expenseMinor,
      score: score.calculated ? score.roundedScore : null,
      scoreLabel: _scoreLabel(score.level),
      reserveBalanceMinor: fundBalance,
      reserveCoverageMilliMonths: reserve.coverageMilliMonths,
      expenses: expenses
          .map(
            (item) => ReportExpenseItem(
              title: item.title,
              amountMinor: item.netAmountMinor,
            ),
          )
          .toList(growable: false),
    );
  }

  static String _scoreLabel(FinancialScoreLevel? level) => switch (level) {
    FinancialScoreLevel.critical => 'Alerta Crítico',
    FinancialScoreLevel.tight => 'Atenção / Apertado',
    FinancialScoreLevel.balanced => 'Equilibrado',
    FinancialScoreLevel.healthy => 'Saudável',
    FinancialScoreLevel.prosperous => 'Próspero',
    null => 'Não calculado',
  };
}

FinancialTransaction _convertReportTransaction(
  FinancialTransaction item,
  CurrencyCode target,
  FxQuoteSet fx,
) {
  if (item.currency == target) return item;
  return FinancialTransaction(
    id: item.id,
    title: item.title,
    kind: item.kind,
    originalAmountMinor:
        fx.convertToBaseMinor(item.originalAmountMinor, item.currency) ??
        item.originalAmountMinor,
    currency: target,
    month: item.month,
    discountType: item.discountType,
    discountValue: item.discountType == DiscountType.fixed
        ? fx.convertToBaseMinor(item.discountValue, item.currency) ??
              item.discountValue
        : item.discountValue,
    recurring: item.recurring,
    installmentLabel: item.installmentLabel,
    deletedAt: item.deletedAt,
  );
}
