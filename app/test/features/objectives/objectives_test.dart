import 'package:flutter_test/flutter_test.dart';
import 'package:oscar_financas/core/money/money.dart';
import 'package:oscar_financas/core/time/year_month.dart';
import 'package:oscar_financas/features/screen_1_financial/domain/financial_repository.dart';
import 'package:oscar_financas/features/screen_1_financial/domain/financial_transaction.dart';
import 'package:oscar_financas/features/screen_1_financial/domain/monthly_summary.dart';
import 'package:oscar_financas/features/screen_4_objectives/application/objectives_view_model.dart';
import 'package:oscar_financas/features/screen_4_objectives/data/shared_preferences_objective_repository.dart';
import 'package:oscar_financas/features/screen_4_objectives/domain/financial_objective.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('monthly contributions and the entered annual rate compound', () {
    const objective = FinancialObjective(
      id: 'goal:reserve',
      name: 'Reserva de emergência',
      instrument: 'treasury_selic',
      targetMonths: 6,
      initialBalanceMinor: 100000,
      targetAmountMinor: 200000,
      annualRateBasisPoints: 1200,
      monthlyContributionMinor: 10000,
      frequency: ObjectiveContributionFrequency.monthly,
      startMonth: YearMonth(2026, 1),
      currency: CurrencyCode.brl,
    );

    final evolution = ObjectiveEvolution.calculate(
      objective,
      throughMonth: const YearMonth(2026, 3),
    );

    expect(evolution, hasLength(3));
    expect(evolution.map((item) => item.contributionMinor), [
      10000,
      10000,
      10000,
    ]);
    expect(evolution.every((item) => item.yieldMinor > 0), isTrue);
    expect(evolution.last.closingBalanceMinor, greaterThan(130000));
    expect(evolution.every((item) => item.yieldIsEstimate), isTrue);
  });

  test('one-time contribution does not repeat in following months', () {
    const objective = FinancialObjective(
      id: 'goal:car',
      name: 'Carro novo',
      instrument: 'other',
      targetMonths: 12,
      initialBalanceMinor: 0,
      targetAmountMinor: 100000,
      annualRateBasisPoints: 0,
      monthlyContributionMinor: 25000,
      frequency: ObjectiveContributionFrequency.once,
      startMonth: YearMonth(2026, 1),
      currency: CurrencyCode.usd,
    );

    final evolution = ObjectiveEvolution.calculate(
      objective,
      throughMonth: const YearMonth(2026, 3),
    );

    expect(evolution.map((item) => item.contributionMinor), [25000, 0, 0]);
    expect(evolution.last.closingBalanceMinor, 25000);
  });

  test('objective history survives local storage roundtrip', () async {
    const objective = FinancialObjective(
      id: 'goal:home',
      name: 'Casa própria',
      instrument: 'cdb',
      targetMonths: 12,
      initialBalanceMinor: 10000,
      targetAmountMinor: 500000,
      annualRateBasisPoints: 850,
      monthlyContributionMinor: 3000,
      frequency: ObjectiveContributionFrequency.monthly,
      startMonth: YearMonth(2026, 4),
      currency: CurrencyCode.eur,
      monthlyOverrides: {
        '2026-05': ObjectiveMonthOverride(
          contributionMinor: 3500,
          yieldMinor: 147,
        ),
      },
    );
    const repository = SharedPreferencesObjectiveRepository();

    await repository.save(objective);
    final restored = (await repository.loadAll()).single;

    expect(restored.name, objective.name);
    expect(restored.currency, CurrencyCode.eur);
    expect(restored.monthlyOverrides['2026-05']?.contributionMinor, 3500);
    expect(restored.monthlyOverrides['2026-05']?.yieldMinor, 147);
    await repository.delete(objective.id);
    expect(await repository.loadAll(), isEmpty);
  });

  test(
    'legacy emergency-fund expenses are not imported into objectives',
    () async {
      final oldExpense = FinancialTransaction(
        id: 'emergency-fund:BRL:2026-07',
        title: 'Reserva de emergência',
        kind: TransactionKind.expense,
        originalAmountMinor: 50000,
        currency: CurrencyCode.brl,
        month: YearMonth.now().addMonths(-2),
      );
      final financial = _FakeFinancialRepository(
        contributions: [oldExpense],
        settings: (balanceMinor: 0, targetMonths: 6),
        expenses: [200000],
      );
      final viewModel = ObjectivesViewModel(
        const SharedPreferencesObjectiveRepository(),
        financial,
      );
      addTearDown(viewModel.dispose);

      await viewModel.load();

      expect(viewModel.objectives, isEmpty);
    },
  );

  test('monthly objective contribution is registered as an expense', () async {
    final financial = _FakeFinancialRepository();
    final viewModel = ObjectivesViewModel(
      const SharedPreferencesObjectiveRepository(),
      financial,
    );
    addTearDown(viewModel.dispose);
    final current = YearMonth.now();
    final objective = FinancialObjective(
      id: 'goal:car-test',
      name: 'Carro novo',
      instrument: 'cdb',
      targetMonths: 12,
      initialBalanceMinor: 0,
      targetAmountMinor: 100000,
      annualRateBasisPoints: 0,
      monthlyContributionMinor: 10000,
      frequency: ObjectiveContributionFrequency.monthly,
      startMonth: current,
      currency: CurrencyCode.usd,
    );

    await viewModel.create(objective);

    expect(financial.saved, hasLength(1));
    expect(financial.saved.single.kind, TransactionKind.expense);
    expect(financial.saved.single.title, 'Contribution · Carro novo');
    expect(financial.saved.single.originalAmountMinor, 10000);
    expect(financial.saved.single.recurring, isTrue);
  });

  test(
    'manual contribution updates only this month and adds an expense',
    () async {
      final financial = _FakeFinancialRepository();
      final viewModel = ObjectivesViewModel(
        const SharedPreferencesObjectiveRepository(),
        financial,
      );
      addTearDown(viewModel.dispose);
      final current = YearMonth.now();
      final objective = FinancialObjective(
        id: 'goal:manual-contribution-test',
        name: 'Carro novo',
        instrument: 'cdb',
        targetMonths: 12,
        initialBalanceMinor: 0,
        targetAmountMinor: 100000,
        annualRateBasisPoints: 0,
        monthlyContributionMinor: 30000,
        frequency: ObjectiveContributionFrequency.monthly,
        startMonth: current.addMonths(-2),
        currency: CurrencyCode.usd,
      );

      await viewModel.create(objective);
      await viewModel.contribute(objective.id, 15000);

      final updated =
          (await const SharedPreferencesObjectiveRepository().loadAll()).single;
      final history = ObjectiveEvolution.calculate(
        updated,
        throughMonth: current,
      );
      expect(history.map((item) => item.contributionMinor), [
        30000,
        30000,
        45000,
      ]);
      expect(financial.saved.last.title, 'Contribution · Carro novo');
      expect(financial.saved.last.originalAmountMinor, 15000);
      expect(financial.saved.last.recurring, isFalse);
    },
  );
}

final class _FakeFinancialRepository implements FinancialRepository {
  _FakeFinancialRepository({
    this.contributions = const [],
    this.settings = const (balanceMinor: 0, targetMonths: 6),
    this.expenses = const [],
  });

  final List<FinancialTransaction> contributions;
  final ({int balanceMinor, int targetMonths}) settings;
  final List<int> expenses;
  final List<FinancialTransaction> saved = [];

  @override
  Future<List<FinancialTransaction>> emergencyFundContributions(
    CurrencyCode currency,
  ) async => contributions.where((item) => item.currency == currency).toList();

  @override
  Future<({int balanceMinor, int targetMonths})> emergencyFund(
    CurrencyCode currency,
  ) async => settings;

  @override
  Future<List<int>> completedExpenseTotalsBefore(
    YearMonth month,
    CurrencyCode currency, {
    int limit = 3,
  }) async => expenses.take(limit).toList();

  @override
  Future<List<FinancialTransaction>> transactionsFor(YearMonth month) async =>
      saved.where((item) => item.month == month).toList();

  @override
  Future<void> saveTransaction(FinancialTransaction transaction) async {
    saved.removeWhere((item) => item.id == transaction.id);
    saved.add(transaction);
  }

  @override
  Future<List<FinancialTransaction>> materializeRecurringTransactions(
    YearMonth month,
    CurrencyCode currency,
  ) async => const [];

  @override
  Future<void> softDelete(String id, DateTime deletedAt) async {}

  @override
  Future<void> restore(String id) async {}

  @override
  Future<void> saveEmergencyFund({
    required CurrencyCode currency,
    required int balanceMinor,
    required int targetMonths,
  }) async {}

  @override
  Future<void> saveSummary(MonthlySummary summary) async {}
}
