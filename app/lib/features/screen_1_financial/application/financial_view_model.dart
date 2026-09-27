import 'package:flutter/foundation.dart';

import '../../../core/money/money.dart';
import '../../../core/time/year_month.dart';
import '../../../shared/controllers/month_controller.dart';
import '../../screen_2_extra_income/screen_2_extra_income.dart';
import '../../screen_2_extra_income/domain/extra_income_entry.dart';
import '../../screen_3_investments/domain/fx_quote_set.dart';
import '../domain/emergency_fund.dart';
import '../domain/expense_share.dart';
import '../domain/financial_repository.dart';
import '../domain/financial_score.dart';
import '../domain/financial_transaction.dart';
import '../domain/monthly_summary.dart';

enum FinancialLoadStatus { loading, ready, empty, failure, saving }

enum EmergencyContributionMode { oneTime, fixedMonthly, variable }

final class FinancialScreenState {
  const FinancialScreenState({
    required this.status,
    required this.transactions,
    required this.extraServicesMinor,
    required this.extraSalesMinor,
    required this.summary,
    required this.chartSummaries,
    required this.expenseShares,
    required this.emergencyFund,
    required this.score,
    this.errorCode,
  });

  final FinancialLoadStatus status;
  final List<FinancialTransaction> transactions;
  final int extraServicesMinor;
  final int extraSalesMinor;
  final MonthlySummary summary;
  final List<MonthlySummary> chartSummaries;
  final List<ExpenseShare> expenseShares;
  final EmergencyFundResult emergencyFund;
  final FinancialScoreResult score;
  final String? errorCode;
}

final class FinancialViewModel extends ChangeNotifier {
  FinancialViewModel({
    required this._repository,
    required this._extraIncomePort,
    required this.monthController,
    required this.currency,
    required this._fxRepository,
  }) {
    monthController.addListener(_onMonthChanged);
  }

  final FinancialRepository _repository;
  final ExtraIncomeContributionPort _extraIncomePort;
  final MonthController monthController;
  final CurrencyCode currency;
  final FxRepository _fxRepository;
  int _loadRevision = 0;
  FinancialScreenState? _state;

  FinancialScreenState? get state => _state;

  Future<void> load() async {
    final revision = ++_loadRevision;
    final month = monthController.focusedMonth;
    try {
      final fx =
          await _fxRepository.latest(currency) ??
          (await const OfflineDemonstrationFxRepository().latest(currency));
      final months = [month.addMonths(-2), month.addMonths(-1), month];
      final summaries = <MonthlySummary>[];
      List<FinancialTransaction> focusedTransactions = const [];
      var focusedExtraServices = 0;
      var focusedExtraSales = 0;
      for (final candidate in months) {
        for (final sourceCurrency in CurrencyCode.values) {
          final materialized = await _repository
              .materializeRecurringTransactions(candidate, sourceCurrency);
          final reserveContributions = materialized.where(
            (item) => item.id.startsWith('emergency-fund:'),
          );
          if (reserveContributions.isNotEmpty) {
            final reserve = await _repository.emergencyFund(sourceCurrency);
            await _repository.saveEmergencyFund(
              currency: sourceCurrency,
              balanceMinor:
                  reserve.balanceMinor +
                  reserveContributions.fold<int>(
                    0,
                    (sum, item) => sum + item.originalAmountMinor,
                  ),
              targetMonths: reserve.targetMonths,
            );
          }
        }
        final rawTransactions = await _repository.transactionsFor(candidate);
        final transactions = rawTransactions
            .map((item) => _convertedTransaction(item, currency, fx))
            .toList(growable: false);
        final extraEntries = await _extraIncomePort.includedEntriesFor(
          candidate,
        );
        var services = 0;
        var sales = 0;
        for (final item in extraEntries) {
          final amount = fx.convertToBaseMinor(item.amountMinor, item.currency);
          if (amount == null) continue;
          if (item.kind == ExtraIncomeKind.service) {
            services += amount;
          } else {
            sales += amount;
          }
        }
        final extra = services + sales;
        final summary = MonthlySummaryCalculator.calculate(
          month: candidate,
          currency: currency,
          transactions: transactions,
          extraIncomeMinor: extra,
          sourceRevision: DateTime.now().microsecondsSinceEpoch,
        );
        await _repository.saveSummary(summary);
        summaries.add(summary);
        if (candidate == month) {
          focusedTransactions = transactions;
          focusedExtraServices = services;
          focusedExtraSales = sales;
        }
      }
      final reserveFunds = await Future.wait(
        CurrencyCode.values.map(_repository.emergencyFund),
      );
      final legacyReserveContributions = await Future.wait(
        CurrencyCode.values.map(_repository.emergencyFundContributions),
      );
      final reserveBalance = CurrencyCode.values.indexed.fold<int>(0, (
        sum,
        entry,
      ) {
        final legacyBalance = legacyReserveContributions[entry.$1].fold<int>(
          0,
          (subtotal, item) => subtotal + item.netAmountMinor,
        );
        // Older app versions stored contribution ledger rows without also
        // updating the cumulative fund setting. Use whichever source is
        // higher so migrated histories appear without double counting.
        final balance = reserveFunds[entry.$1].balanceMinor > legacyBalance
            ? reserveFunds[entry.$1].balanceMinor
            : legacyBalance;
        return sum + (fx.convertToBaseMinor(balance, entry.$2) ?? 0);
      });
      final reserveTargetMonths =
          CurrencyCode.values.indexed
              .where((entry) {
                final legacyBalance = legacyReserveContributions[entry.$1]
                    .fold<int>(0, (sum, item) => sum + item.netAmountMinor);
                return (reserveFunds[entry.$1].balanceMinor > legacyBalance
                        ? reserveFunds[entry.$1].balanceMinor
                        : legacyBalance) >
                    0;
              })
              .map((entry) => reserveFunds[entry.$1].targetMonths)
              .firstOrNull ??
          6;
      final expenses = await _repository.completedExpenseTotalsBefore(
        month,
        currency,
      );
      final focused = summaries.last;
      final currentReserveContribution = focusedTransactions
          .where(
            (item) =>
                item.active &&
                item.kind == TransactionKind.expense &&
                item.isEmergencyFundContribution,
          )
          .fold<int>(0, (sum, item) => sum + item.netAmountMinor);
      final coverageExpenses = expenses.isNotEmpty
          ? expenses
          : [
              (focused.expenseMinor - currentReserveContribution).clamp(
                0,
                focused.expenseMinor,
              ),
            ].where((value) => value > 0).toList();
      if (revision != _loadRevision) return;
      _state = FinancialScreenState(
        status: focusedTransactions.where((item) => item.active).isEmpty
            ? FinancialLoadStatus.empty
            : FinancialLoadStatus.ready,
        transactions: List.unmodifiable(
          focusedTransactions.where((item) => item.active),
        ),
        extraServicesMinor: focusedExtraServices,
        extraSalesMinor: focusedExtraSales,
        summary: focused,
        chartSummaries: List.unmodifiable(summaries),
        expenseShares: List.unmodifiable(
          ExpenseShareCalculator.calculate(
            expenses: focusedTransactions,
            grossIncomeMinor: focused.grossIncomeMinor,
          ),
        ),
        emergencyFund: EmergencyFundCalculator.calculate(
          balanceMinor: reserveBalance,
          targetMonths: reserveTargetMonths,
          completedMonthlyExpensesMinor: coverageExpenses,
        ),
        score: FinancialScoreCalculator.calculate(focused),
      );
    } catch (_) {
      if (revision != _loadRevision) return;
      _state = _fallbackState(month, errorCode: 'financial.loadFailed');
    }
    notifyListeners();
  }

  Future<void> addTransaction({
    required String title,
    required int amountMinor,
    required TransactionKind kind,
    DiscountType discountType = DiscountType.none,
    int discountValue = 0,
    bool recurring = false,
    String? installmentLabel,
  }) async {
    if (title.trim().isEmpty || amountMinor <= 0) return;
    await _repository.saveTransaction(
      FinancialTransaction(
        id: 'tx:${DateTime.now().microsecondsSinceEpoch}',
        title: title.trim(),
        kind: kind,
        originalAmountMinor: amountMinor,
        currency: currency,
        month: monthController.focusedMonth,
        discountType: discountType,
        discountValue: discountValue,
        recurring: recurring,
        installmentLabel: installmentLabel,
      ),
    );
    await load();
  }

  Future<void> updateTransaction({
    required FinancialTransaction existing,
    required String title,
    required int amountMinor,
    required DiscountType discountType,
    required int discountValue,
    required bool recurring,
    String? installmentLabel,
  }) async {
    if (title.trim().isEmpty || amountMinor <= 0) return;
    await _repository.saveTransaction(
      FinancialTransaction(
        id: existing.id,
        title: title.trim(),
        kind: existing.kind,
        originalAmountMinor: amountMinor,
        currency: existing.currency,
        month: existing.month,
        discountType: discountType,
        discountValue: discountValue,
        recurring: recurring,
        installmentLabel: installmentLabel ?? existing.installmentLabel,
        deletedAt: existing.deletedAt,
      ),
    );
    await load();
  }

  Future<void> remove(String id) async {
    await _repository.softDelete(id, DateTime.now());
    await load();
  }

  Future<void> undoRemove(String id) async {
    await _repository.restore(id);
    await load();
  }

  Future<void> updateEmergencyFund({
    required int contributionMinor,
    required int targetMonths,
    required EmergencyContributionMode mode,
  }) async {
    final month = monthController.focusedMonth;
    final transactions = await _repository.transactionsFor(month);
    final existing = transactions
        .where((item) => item.id.startsWith('emergency-fund:') && item.active)
        .toList();
    final legacyExisting = transactions
        .where((item) => item.isLegacyEmergencyFundContribution && item.active)
        .toList();
    final sourceCurrency = existing.isNotEmpty
        ? existing.first.currency
        : legacyExisting.isNotEmpty
        ? legacyExisting.first.currency
        : currency;
    final fx =
        await _fxRepository.latest(currency) ??
        (await const OfflineDemonstrationFxRepository().latest(currency));
    final current = await _repository.emergencyFund(sourceCurrency);
    if (contributionMinor <= 0) {
      await _repository.saveEmergencyFund(
        currency: sourceCurrency,
        balanceMinor: current.balanceMinor,
        targetMonths: targetMonths.clamp(1, 120),
      );
      await load();
      return;
    }
    final storedContribution = sourceCurrency == currency
        ? contributionMinor
        : fx.convertMinor(contributionMinor, sourceCurrency) ??
              contributionMinor;
    final existingLegacy = legacyExisting.firstOrNull;
    final existingTagged = existing.firstOrNull;
    final nextBalance = existingLegacy != null && existingTagged == null
        ? current.balanceMinor
        : (current.balanceMinor -
                  (existingTagged?.originalAmountMinor ?? 0) +
                  storedContribution)
              .clamp(0, 1 << 62);

    await _repository.saveEmergencyFund(
      currency: sourceCurrency,
      balanceMinor: nextBalance,
      targetMonths: targetMonths.clamp(1, 120),
    );
    await _repository.saveTransaction(
      existingLegacy != null && existingTagged == null
          ? existingLegacy.copyWith(
              originalAmountMinor: storedContribution,
              recurring: mode == EmergencyContributionMode.fixedMonthly,
            )
          : FinancialTransaction(
              id:
                  existingTagged?.id ??
                  'emergency-fund:${sourceCurrency.isoCode}:${month.databaseKey}',
              title:
                  existingTagged?.title ??
                  existingLegacy?.title ??
                  'Reserva de emergência',
              kind: TransactionKind.expense,
              originalAmountMinor: storedContribution,
              currency: sourceCurrency,
              month: month,
              recurring: mode == EmergencyContributionMode.fixedMonthly,
            ),
    );
    await load();
  }

  void _onMonthChanged() => load();

  FinancialScreenState _fallbackState(YearMonth month, {String? errorCode}) {
    final summary = MonthlySummary(
      month: month,
      currency: currency,
      incomeMinor: 0,
      expenseMinor: 0,
      extraIncomeMinor: 0,
      sourceRevision: 0,
    );
    return FinancialScreenState(
      status: errorCode == null
          ? FinancialLoadStatus.loading
          : FinancialLoadStatus.failure,
      transactions: const [],
      extraServicesMinor: 0,
      extraSalesMinor: 0,
      summary: summary,
      chartSummaries: [summary],
      expenseShares: const [],
      emergencyFund: EmergencyFundCalculator.calculate(
        balanceMinor: 0,
        targetMonths: 3,
        completedMonthlyExpensesMinor: const [],
      ),
      score: FinancialScoreCalculator.calculate(summary),
      errorCode: errorCode,
    );
  }

  @override
  void dispose() {
    monthController.removeListener(_onMonthChanged);
    super.dispose();
  }
}

FinancialTransaction _convertedTransaction(
  FinancialTransaction item,
  CurrencyCode target,
  FxQuoteSet fx,
) {
  if (item.currency == target) return item;
  final amount = fx.convertToBaseMinor(item.originalAmountMinor, item.currency);
  if (amount == null) return item;
  final fixedDiscount = item.discountType == DiscountType.fixed
      ? fx.convertToBaseMinor(item.discountValue, item.currency) ?? 0
      : item.discountValue;
  return FinancialTransaction(
    id: item.id,
    title: item.title,
    kind: item.kind,
    originalAmountMinor: amount,
    currency: target,
    month: item.month,
    discountType: item.discountType,
    discountValue: fixedDiscount,
    recurring: item.recurring,
    installmentLabel: item.installmentLabel,
    deletedAt: item.deletedAt,
  );
}
