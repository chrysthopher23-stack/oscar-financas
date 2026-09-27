import 'package:flutter_test/flutter_test.dart';
import 'package:oscar_financas/app/services/initial_demo_data.dart';
import 'package:oscar_financas/core/money/money.dart';
import 'package:oscar_financas/core/time/year_month.dart';
import 'package:oscar_financas/features/screen_1_financial/application/financial_view_model.dart';
import 'package:oscar_financas/features/screen_1_financial/domain/financial_repository.dart';
import 'package:oscar_financas/features/screen_1_financial/domain/financial_transaction.dart';
import 'package:oscar_financas/features/screen_1_financial/domain/monthly_summary.dart';
import 'package:oscar_financas/features/screen_2_extra_income/application/extra_income_contribution_port.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/fx_quote_set.dart';
import 'package:oscar_financas/features/screen_2_extra_income/domain/extra_income_entry.dart';
import 'package:oscar_financas/features/screen_2_extra_income/domain/extra_income_repository.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/investment_position.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/investment_repository.dart';
import 'package:oscar_financas/features/screen_4_objectives/data/shared_preferences_objective_repository.dart';
import 'package:oscar_financas/features/screen_4_objectives/domain/financial_objective.dart';
import 'package:oscar_financas/features/screen_0_home/application/home_objective_totals.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oscar_financas/shared/controllers/month_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const month = YearMonth(2026, 9);

  test(
    'new emergency objective starts with six fresh monthly deposits',
    () async {
      SharedPreferences.setMockInitialValues({});
      final financial = _FinancialMemory();
      final objectives = const SharedPreferencesObjectiveRepository();
      await seedEmergencyObjectiveDemo(
        objectives: objectives,
        financial: financial,
        currentMonth: month,
      );

      final goal = (await objectives.loadAll()).single;
      final history = ObjectiveEvolution.calculate(goal, throughMonth: month);
      final deposits = financial.items
          .where((item) => item.title == 'Contribution · Emergency fund')
          .toList();
      expect(history, hasLength(6));
      expect(goal.annualRateBasisPoints, 400);
      expect(
        history.map((item) => item.contributionMinor),
        everyElement(30000),
      );
      expect(history.last.yieldMinor, greaterThan(0));
      expect(deposits, hasLength(6));
      expect(
        deposits.fold<int>(0, (sum, item) => sum + item.originalAmountMinor),
        180000,
      );
      expect(
        deposits.every((item) => item.currency == CurrencyCode.usd),
        isTrue,
      );
      expect(deposits.last.recurring, isTrue);
    },
  );

  test(
    'My First 100K is seeded once with its monthly contribution history',
    () async {
      SharedPreferences.setMockInitialValues({});
      final financial = _FinancialMemory();
      const objectives = SharedPreferencesObjectiveRepository();

      await seedFirst100kObjectiveDemo(
        objectives: objectives,
        financial: financial,
        currentMonth: month,
      );
      await seedFirst100kObjectiveDemo(
        objectives: objectives,
        financial: financial,
        currentMonth: month,
      );

      final goal = (await objectives.loadAll()).single;
      final history = ObjectiveEvolution.calculate(goal, throughMonth: month);
      final deposits = financial.items
          .where((item) => item.id.contains('objective:demo-first-100k'))
          .toList();
      expect(goal.name, 'My First 100K');
      expect(goal.targetAmountMinor, 10000000);
      expect(goal.targetMonths, 180);
      expect(goal.annualRateBasisPoints, 500);
      expect(goal.monthlyContributionMinor, 50000);
      expect(goal.currency, CurrencyCode.usd);
      expect(history, hasLength(9));
      expect(history.every((item) => item.contributionMinor == 50000), isTrue);
      expect(deposits, hasLength(10));
      expect(deposits.where((item) => item.recurring), hasLength(1));
      expect(
        deposits
            .where((item) => item.month.compareTo(month) <= 0)
            .fold<int>(0, (sum, item) => sum + item.originalAmountMinor),
        450000,
      );
    },
  );

  test(
    'own-home objective seeds eight deposits and appears in home totals',
    () async {
      SharedPreferences.setMockInitialValues({});
      final financial = _FinancialMemory();
      final objectives = const SharedPreferencesObjectiveRepository();

      await seedEmergencyObjectiveDemo(
        objectives: objectives,
        financial: financial,
        currentMonth: month,
      );
      await seedOwnHomeObjectiveDemo(
        objectives: objectives,
        financial: financial,
        currentMonth: month,
      );
      // Re-running startup seeding must not duplicate either goal or deposits.
      await seedOwnHomeObjectiveDemo(
        objectives: objectives,
        financial: financial,
        currentMonth: month,
      );

      final allObjectives = await objectives.loadAll();
      final ownHome = allObjectives.singleWhere(
        (objective) => objective.name == 'Own a Home',
      );
      final history = ObjectiveEvolution.calculate(
        ownHome,
        throughMonth: month,
      );
      final deposits = financial.items
          .where(
            (item) =>
                item.title == 'Contribution · Own a Home' &&
                item.month.compareTo(month) <= 0,
          )
          .toList();
      final nextDeposit = financial.items.singleWhere(
        (item) =>
            item.title == 'Contribution · Own a Home' &&
            item.month == const YearMonth(2026, 10),
      );
      final forecast = ObjectiveEvolution.calculate(
        ownHome,
        throughMonth: const YearMonth(2036, 1),
      );
      final homeTotals = HomeObjectiveTotals.calculate(
        objectives: allObjectives,
        throughMonth: month,
        baseCurrency: CurrencyCode.usd,
        fx: null,
      );

      expect(ownHome.targetAmountMinor, 40000000);
      expect(ownHome.monthlyContributionMinor, 220000);
      expect(ownHome.targetMonths, 120);
      expect(ownHome.annualRateBasisPoints, 1000);
      expect(ownHome.instrument, isEmpty);
      expect(ownHome.currency, CurrencyCode.usd);
      expect(history, hasLength(8));
      expect(history.first.month, const YearMonth(2026, 2));
      expect(history.last.month, month);
      expect(
        history.map((item) => item.contributionMinor),
        everyElement(50000),
      );
      expect(deposits, hasLength(8));
      expect(
        deposits.fold<int>(0, (sum, item) => sum + item.originalAmountMinor),
        400000,
      );
      expect(deposits.last.recurring, isFalse);
      expect(nextDeposit.originalAmountMinor, 220000);
      expect(nextDeposit.recurring, isTrue);
      expect(forecast.last.closingBalanceMinor, greaterThan(40000000));
      expect(
        homeTotals.objectives.map((item) => item.name),
        contains('Own a Home'),
      );
      expect(homeTotals.targetMinor, 42000000);
    },
  );

  test(
    'new-car goal records monthly deposits from January 2026 through today',
    () async {
      SharedPreferences.setMockInitialValues({});
      final financial = _FinancialMemory();
      const objectives = SharedPreferencesObjectiveRepository();

      await seedNewCar2031ObjectiveDemo(
        objectives: objectives,
        financial: financial,
        currentMonth: month,
      );
      await seedNewCar2031ObjectiveDemo(
        objectives: objectives,
        financial: financial,
        currentMonth: month,
      );

      final goal = (await objectives.loadAll()).single;
      final history = ObjectiveEvolution.calculate(goal, throughMonth: month);
      final forecast = ObjectiveEvolution.calculate(
        goal,
        throughMonth: const YearMonth(2030, 12),
      );
      final deposits = financial.items
          .where(
            (item) =>
                item.title == 'Contribution · New Car 2031' &&
                item.month.compareTo(month) <= 0,
          )
          .toList();
      final nextDeposit = financial.items.singleWhere(
        (item) =>
            item.title == 'Contribution · New Car 2031' &&
            item.month == const YearMonth(2026, 10),
      );

      expect(goal.name, 'New Car 2031');
      expect(goal.annualRateBasisPoints, 450);
      expect(goal.targetAmountMinor, 6000000);
      expect(goal.monthlyContributionMinor, 95000);
      expect(goal.targetMonths, 60);
      expect(goal.currency, CurrencyCode.usd);
      expect(history, hasLength(9));
      expect(history.first.month, const YearMonth(2026, 1));
      expect(history.last.month, month);
      expect(deposits, hasLength(9));
      expect(deposits.last.recurring, isFalse);
      expect(nextDeposit.originalAmountMinor, 95000);
      expect(nextDeposit.recurring, isTrue);
      expect(
        deposits.fold<int>(0, (sum, item) => sum + item.originalAmountMinor),
        675000,
      );
      expect(forecast.last.closingBalanceMinor, greaterThan(6000000));
    },
  );

  test(
    'migrates existing home and car goals without rewriting past contributions',
    () async {
      SharedPreferences.setMockInitialValues({});
      final financial = _FinancialMemory();
      const objectives = SharedPreferencesObjectiveRepository();
      for (final sample in [
        (
          id: 'objective:demo-own-home',
          name: 'Own a Home',
          title: 'Aporte · Own a Home',
          start: const YearMonth(2026, 2),
          months: 8,
          amount: 50000,
          target: 40000000,
          rate: 1000,
        ),
        (
          id: 'objective:demo-new-car-2031',
          name: 'New Car 2031',
          title: 'Aporte · New Car 2031',
          start: const YearMonth(2026, 1),
          months: 72,
          amount: 75000,
          target: 6000000,
          rate: 450,
        ),
      ]) {
        await objectives.save(
          FinancialObjective(
            id: sample.id,
            name: sample.name,
            instrument: '',
            targetMonths: sample.months,
            initialBalanceMinor: 0,
            targetAmountMinor: sample.target,
            annualRateBasisPoints: sample.rate,
            monthlyContributionMinor: sample.amount,
            frequency: ObjectiveContributionFrequency.monthly,
            startMonth: sample.start,
            currency: CurrencyCode.usd,
          ),
        );
        await financial.saveTransaction(
          FinancialTransaction(
            id: 'objective:${sample.id}:${month.databaseKey}',
            title: sample.title,
            kind: TransactionKind.expense,
            originalAmountMinor: sample.amount,
            currency: CurrencyCode.usd,
            month: month,
            recurring: true,
          ),
        );
      }

      await migrateDemoObjectiveTimeframes(
        objectives: objectives,
        financial: financial,
        currentMonth: month,
      );
      await migrateDemoObjectiveTimeframes(
        objectives: objectives,
        financial: financial,
        currentMonth: month,
      );

      final goals = await objectives.loadAll();
      final home = goals.singleWhere((item) => item.name == 'Own a Home');
      final car = goals.singleWhere((item) => item.name == 'New Car 2031');
      expect(home.targetMonths, 120);
      expect(car.targetMonths, 60);
      expect(home.monthlyContributionMinor, 220000);
      expect(car.monthlyContributionMinor, 95000);
      expect(
        ObjectiveEvolution.calculate(
          home,
          throughMonth: month,
        ).map((item) => item.contributionMinor),
        everyElement(50000),
      );
      expect(
        ObjectiveEvolution.calculate(
          car,
          throughMonth: month,
        ).map((item) => item.contributionMinor),
        everyElement(75000),
      );
      expect(financial.items.where((item) => item.recurring), hasLength(2));
      expect(
        financial.items.where(
          (item) => item.month == const YearMonth(2026, 10),
        ),
        hasLength(2),
      );
    },
  );

  test(
    'removes investment metadata from existing goals without changing progress',
    () async {
      SharedPreferences.setMockInitialValues({});
      const objectives = SharedPreferencesObjectiveRepository();
      await objectives.save(
        FinancialObjective(
          id: 'objective:demo-own-home',
          name: 'Own a Home',
          instrument: 'Savings',
          targetMonths: 8,
          initialBalanceMinor: 0,
          targetAmountMinor: 40000000,
          annualRateBasisPoints: 0,
          monthlyContributionMinor: 50000,
          frequency: ObjectiveContributionFrequency.monthly,
          startMonth: const YearMonth(2026, 2),
          currency: CurrencyCode.usd,
        ),
      );
      await objectives.save(
        const FinancialObjective(
          id: 'goal:travel',
          name: 'Travel around the world',
          instrument: 'cdb',
          targetMonths: 60,
          initialBalanceMinor: 10000,
          targetAmountMinor: 3000000,
          annualRateBasisPoints: 500,
          monthlyContributionMinor: 20000,
          frequency: ObjectiveContributionFrequency.monthly,
          startMonth: YearMonth(2026, 4),
          currency: CurrencyCode.usd,
          monthlyOverrides: {
            '2026-05': ObjectiveMonthOverride(contributionMinor: 25000),
          },
        ),
      );

      await migrateOwnHomeObjectiveDemoRate(objectives);
      await removeObjectiveInvestmentMetadata(objectives);
      await removeObjectiveInvestmentMetadata(objectives);

      final migrated = await objectives.loadAll();
      final ownHome = migrated.singleWhere(
        (item) => item.id == 'objective:demo-own-home',
      );
      final travel = migrated.singleWhere((item) => item.id == 'goal:travel');
      expect(ownHome.annualRateBasisPoints, 1000);
      expect(ownHome.instrument, isEmpty);
      expect(travel.instrument, isEmpty);
      expect(travel.targetMonths, 60);
      expect(travel.targetAmountMinor, 3000000);
      expect(travel.monthlyOverrides['2026-05']?.contributionMinor, 25000);
    },
  );

  test(
    'legacy reserve expense history counts and recurs in the fund',
    () async {
      final financial = _FinancialMemory();
      await financial.saveTransaction(
        const FinancialTransaction(
          id: 'tx:legacy-emergency-july',
          title: 'Reserva de emergência',
          kind: TransactionKind.expense,
          originalAmountMinor: 28000,
          currency: CurrencyCode.brl,
          month: YearMonth(2026, 7),
          recurring: true,
        ),
      );
      final august = MonthController(initialMonth: const YearMonth(2026, 8));
      final viewModel = FinancialViewModel(
        repository: financial,
        extraIncomePort: const _ZeroExtraIncome(),
        monthController: august,
        currency: CurrencyCode.brl,
        fxRepository: const OfflineDemonstrationFxRepository(),
      );
      addTearDown(viewModel.dispose);
      addTearDown(august.dispose);

      await viewModel.load();
      expect(viewModel.state!.emergencyFund.balanceMinor, 56000);
      final augustContribution = financial.items.singleWhere(
        (item) => item.month == const YearMonth(2026, 8),
      );
      expect(augustContribution.isLegacyEmergencyFundContribution, isTrue);

      await viewModel.updateEmergencyFund(
        contributionMinor: 50000,
        targetMonths: 6,
        mode: EmergencyContributionMode.fixedMonthly,
      );
      expect(viewModel.state!.emergencyFund.balanceMinor, 78000);
      expect(
        financial.items
            .singleWhere((item) => item.month == const YearMonth(2026, 7))
            .originalAmountMinor,
        28000,
      );

      await viewModel.updateEmergencyFund(
        contributionMinor: 0,
        targetMonths: 3,
        mode: EmergencyContributionMode.fixedMonthly,
      );
      expect(financial.fund.balanceMinor, 0);
      expect(financial.fund.targetMonths, 3);
      expect(viewModel.state!.emergencyFund.balanceMinor, 78000);

      final september = MonthController(initialMonth: const YearMonth(2026, 9));
      final nextMonthViewModel = FinancialViewModel(
        repository: financial,
        extraIncomePort: const _ZeroExtraIncome(),
        monthController: september,
        currency: CurrencyCode.brl,
        fxRepository: const OfflineDemonstrationFxRepository(),
      );
      addTearDown(nextMonthViewModel.dispose);
      addTearDown(september.dispose);
      await nextMonthViewModel.load();
      expect(nextMonthViewModel.state!.emergencyFund.balanceMinor, 128000);
    },
  );

  test(
    'tagged simulated reserve history is recovered when setting is zero',
    () async {
      final financial = _FinancialMemory();
      for (var monthIndex = 0; monthIndex < 12; monthIndex++) {
        final historyMonth = month.addMonths(-monthIndex);
        await financial.saveTransaction(
          FinancialTransaction(
            id: 'emergency-fund:BRL:${historyMonth.databaseKey}',
            title: 'Reserva de emergência',
            kind: TransactionKind.expense,
            originalAmountMinor: 30000,
            currency: CurrencyCode.brl,
            month: historyMonth,
            recurring: true,
          ),
        );
      }
      final controller = MonthController(initialMonth: month);
      final viewModel = FinancialViewModel(
        repository: financial,
        extraIncomePort: const _ZeroExtraIncome(),
        monthController: controller,
        currency: CurrencyCode.brl,
        fxRepository: const OfflineDemonstrationFxRepository(),
      );
      addTearDown(viewModel.dispose);
      addTearDown(controller.dispose);

      await viewModel.load();
      expect(viewModel.state!.emergencyFund.balanceMinor, 360000);
      expect(financial.fund.balanceMinor, 0);
    },
  );

  test(
    'editing monthly reserve contribution preserves earlier fund history',
    () async {
      final financial = _FinancialMemory();
      await seedFinancialDemo(
        repository: financial,
        month: month,
        currency: CurrencyCode.brl,
      );
      for (final contribution in [
        (month: month.addMonths(-2), amount: 20000),
        (month: month.addMonths(-1), amount: 30000),
      ]) {
        await financial.saveTransaction(
          FinancialTransaction(
            id: 'emergency-fund:BRL:${contribution.month.databaseKey}',
            title: 'Emergency Fund Contribution',
            kind: TransactionKind.expense,
            originalAmountMinor: contribution.amount,
            currency: CurrencyCode.brl,
            month: contribution.month,
            recurring: true,
          ),
        );
      }
      await financial.saveEmergencyFund(
        currency: CurrencyCode.brl,
        balanceMinor: 80000,
        targetMonths: 6,
      );
      final monthController = MonthController(initialMonth: month);
      final viewModel = FinancialViewModel(
        repository: financial,
        extraIncomePort: const _ZeroExtraIncome(),
        monthController: monthController,
        currency: CurrencyCode.brl,
        fxRepository: const OfflineDemonstrationFxRepository(),
      );
      addTearDown(viewModel.dispose);
      addTearDown(monthController.dispose);

      await viewModel.load();
      await viewModel.updateEmergencyFund(
        contributionMinor: 0,
        targetMonths: 6,
        mode: EmergencyContributionMode.fixedMonthly,
      );
      expect(financial.fund.balanceMinor, 110000);
      expect(
        financial.items
            .singleWhere((item) => item.id == 'emergency-fund:BRL:2026-09')
            .originalAmountMinor,
        30000,
      );

      await viewModel.updateEmergencyFund(
        contributionMinor: 50000,
        targetMonths: 6,
        mode: EmergencyContributionMode.variable,
      );
      expect(financial.fund.balanceMinor, 130000);

      await viewModel.updateEmergencyFund(
        contributionMinor: 15000,
        targetMonths: 6,
        mode: EmergencyContributionMode.fixedMonthly,
      );
      expect(financial.fund.balanceMinor, 95000);
      expect(
        financial.items
            .singleWhere((item) => item.id == 'emergency-fund:BRL:2026-07')
            .originalAmountMinor,
        20000,
      );
      expect(
        financial.items
            .singleWhere((item) => item.id == 'emergency-fund:BRL:2026-08')
            .originalAmountMinor,
        30000,
      );
      final contribution = financial.items.singleWhere(
        (item) => item.id == 'emergency-fund:BRL:2026-09',
      );
      expect(contribution.originalAmountMinor, 15000);
      expect(contribution.recurring, isTrue);
      final nextMonthController = MonthController(
        initialMonth: month.addMonths(1),
      );
      final nextMonthViewModel = FinancialViewModel(
        repository: financial,
        extraIncomePort: const _ZeroExtraIncome(),
        monthController: nextMonthController,
        currency: CurrencyCode.brl,
        fxRepository: const OfflineDemonstrationFxRepository(),
      );
      addTearDown(nextMonthViewModel.dispose);
      addTearDown(nextMonthController.dispose);

      await nextMonthViewModel.load();
      final nextMonthItems = financial.items
          .where((item) => item.month == month.addMonths(1))
          .toList();
      expect(nextMonthItems, hasLength(9));
      expect(
        nextMonthItems.where((item) => item.installmentLabel != null),
        isEmpty,
      );
      expect(
        nextMonthItems
            .singleWhere((item) => item.id == 'emergency-fund:BRL:2026-10')
            .originalAmountMinor,
        15000,
      );
      expect(financial.fund.balanceMinor, 110000);

      await nextMonthViewModel.load();
      expect(financial.fund.balanceMinor, 110000);
    },
  );
  test(
    'changing display currency preserves records and converts values',
    () async {
      final financial = _FinancialMemory();
      await seedFinancialDemo(
        repository: financial,
        month: month,
        currency: CurrencyCode.brl,
      );
      final monthController = MonthController(initialMonth: month);
      final viewModel = FinancialViewModel(
        repository: financial,
        extraIncomePort: const _ZeroExtraIncome(),
        monthController: monthController,
        currency: CurrencyCode.usd,
        fxRepository: const OfflineDemonstrationFxRepository(),
      );
      addTearDown(viewModel.dispose);
      addTearDown(monthController.dispose);

      await viewModel.load();

      expect(viewModel.state!.status, FinancialLoadStatus.ready);
      expect(viewModel.state!.transactions, hasLength(9));
      final salary = viewModel.state!.transactions.singleWhere(
        (item) => item.kind == TransactionKind.income,
      );
      expect(salary.title, 'Software Engineer Salary');
      expect(salary.currency, CurrencyCode.usd);
      expect(salary.originalAmountMinor, 73077);
      expect(viewModel.state!.emergencyFund.balanceMinor, 0);
      expect(financial.items, hasLength(9));
      expect(financial.items.first.currency, CurrencyCode.brl);
    },
  );
  test('creates the complete editable starter scenario', () async {
    final financial = _FinancialMemory();
    final extra = _ExtraMemory();
    final investments = _InvestmentMemory();

    await seedFinancialDemo(
      repository: financial,
      month: month,
      currency: CurrencyCode.brl,
    );
    await seedExtraIncomeDemo(
      repository: extra,
      month: month,
      currency: CurrencyCode.brl,
    );
    await seedInvestmentDemo(repository: investments, month: month);

    expect(financial.items, hasLength(9));
    expect(
      financial.items
          .singleWhere((item) => item.kind == TransactionKind.income)
          .originalAmountMinor,
      380000,
    );
    expect(
      financial.items
          .where((item) => item.kind == TransactionKind.expense)
          .fold<int>(0, (sum, item) => sum + item.originalAmountMinor),
      344080,
    );
    expect(
      financial.items
          .where((item) => item.installmentLabel != null)
          .map((item) => item.installmentLabel),
      containsAll(['12/48', '1/48', '1/12']),
    );
    expect(financial.fund.balanceMinor, 0);
    expect(extra.items, hasLength(4));
    expect(
      extra.items.fold<int>(0, (sum, item) => sum + item.amountMinor),
      120000,
    );
    expect(investments.items, hasLength(12));
    expect(
      investments.items.where((item) => item.identity.family.name == 'crypto'),
      hasLength(6),
    );
  });
}

final class _FinancialMemory implements FinancialRepository {
  final items = <FinancialTransaction>[];
  final _funds = <CurrencyCode, ({int balanceMinor, int targetMonths})>{};
  ({int balanceMinor, int targetMonths}) get fund =>
      _funds[CurrencyCode.brl] ?? (balanceMinor: 0, targetMonths: 6);

  @override
  Future<List<FinancialTransaction>> transactionsFor(YearMonth month) async =>
      items.where((item) => item.month == month).toList();
  @override
  Future<List<FinancialTransaction>> emergencyFundContributions(
    CurrencyCode currency,
  ) async => items
      .where(
        (item) =>
            item.active &&
            item.currency == currency &&
            item.isEmergencyFundContribution,
      )
      .toList(growable: false);
  @override
  Future<void> saveTransaction(FinancialTransaction transaction) async {
    items.removeWhere((item) => item.id == transaction.id);
    items.add(transaction);
  }

  @override
  Future<List<FinancialTransaction>> materializeRecurringTransactions(
    YearMonth month,
    CurrencyCode currency,
  ) async {
    final currentKeys = items
        .where((item) => item.month == month && item.currency == currency)
        .map((item) => '${item.kind.name}|${item.title}')
        .toSet();
    final prior =
        items
            .where(
              (item) =>
                  item.currency == currency && item.month.compareTo(month) < 0,
            )
            .toList()
          ..sort((a, b) {
            final monthOrder = b.month.compareTo(a.month);
            return monthOrder != 0 ? monthOrder : b.id.compareTo(a.id);
          });
    final latest = <String, FinancialTransaction>{};
    for (final item in prior) {
      latest.putIfAbsent('${item.kind.name}|${item.title}', () => item);
    }
    final created = <FinancialTransaction>[];
    for (final entry in latest.entries) {
      final source = entry.value;
      if (currentKeys.contains(entry.key) ||
          !source.active ||
          !source.recurring) {
        continue;
      }
      final occurrence = FinancialTransaction(
        id: source.id.contains('emergency-fund:')
            ? 'emergency-fund:${currency.isoCode}:${month.databaseKey}'
            : 'recurring:${source.id}:${month.databaseKey}',
        title: source.title,
        kind: source.kind,
        originalAmountMinor: source.originalAmountMinor,
        currency: source.currency,
        month: month,
        discountType: source.discountType,
        discountValue: source.discountValue,
        recurring: true,
      );
      await saveTransaction(occurrence);
      created.add(occurrence);
    }
    return created;
  }

  @override
  Future<void> saveEmergencyFund({
    required CurrencyCode currency,
    required int balanceMinor,
    required int targetMonths,
  }) async => _funds[currency] = (
    balanceMinor: balanceMinor,
    targetMonths: targetMonths,
  );
  @override
  Future<({int balanceMinor, int targetMonths})> emergencyFund(
    CurrencyCode currency,
  ) async => _funds[currency] ?? (balanceMinor: 0, targetMonths: 6);
  @override
  Future<void> softDelete(String id, DateTime deletedAt) async {
    final index = items.indexWhere((item) => item.id == id);
    if (index >= 0) items[index] = items[index].copyWith(deletedAt: deletedAt);
  }

  @override
  Future<void> restore(String id) async {}
  @override
  Future<List<int>> completedExpenseTotalsBefore(
    YearMonth month,
    CurrencyCode currency, {
    int limit = 3,
  }) async => [];
  @override
  Future<void> saveSummary(MonthlySummary summary) async {}
}

final class _ExtraMemory implements ExtraIncomeRepository {
  final items = <ExtraIncomeEntry>[];
  @override
  Future<void> saveEntry(ExtraIncomeEntry entry) async {
    items.removeWhere((item) => item.id == entry.id);
    items.add(entry);
  }

  @override
  Future<List<ExtraIncomeEntry>> entriesFor(YearMonth month) async =>
      items.where((item) => item.month == month).toList();
  @override
  Future<void> materializeRecurringEntries(YearMonth month) async {}
  @override
  Future<void> softDelete(String id, DateTime deletedAt) async {
    final index = items.indexWhere((item) => item.id == id);
    if (index >= 0) items[index] = items[index].copyWith(deletedAt: deletedAt);
  }

  @override
  Future<void> restore(String id) async {}
}

final class _InvestmentMemory implements InvestmentRepository {
  final items = <InvestmentPosition>[];
  @override
  Future<void> save(InvestmentPosition position) async {
    items.removeWhere((item) => item.id == position.id);
    items.add(position);
  }

  @override
  Future<List<InvestmentPosition>> listForMonth(YearMonth month) async =>
      items.where((item) => item.month == month).toList();
  @override
  Future<void> softDelete(String id, DateTime deletedAt) async {}
  @override
  Future<void> restore(String id) async {}
}

final class _ZeroExtraIncome implements ExtraIncomeContributionPort {
  const _ZeroExtraIncome();
  @override
  Future<List<ExtraIncomeEntry>> includedEntriesFor(YearMonth month) async =>
      const [];
  @override
  Future<int> includedMinorUnitsFor(YearMonth month) async => 0;
}
