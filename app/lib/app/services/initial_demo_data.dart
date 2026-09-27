import '../../core/money/money.dart';
import '../../core/time/year_month.dart';
import '../../features/screen_1_financial/domain/financial_repository.dart';
import '../../features/screen_1_financial/domain/financial_transaction.dart';
import '../../features/screen_2_extra_income/domain/extra_income_entry.dart';
import '../../features/screen_2_extra_income/domain/extra_income_repository.dart';
import '../../features/screen_3_investments/domain/asset_family.dart';
import '../../features/screen_3_investments/domain/instrument_identity.dart';
import '../../features/screen_3_investments/domain/investment_position.dart';
import '../../features/screen_3_investments/domain/investment_repository.dart';
import '../../features/screen_4_objectives/domain/financial_objective.dart';
import '../../features/screen_4_objectives/domain/objective_repository.dart';

Future<void> seedFinancialDemo({
  required FinancialRepository repository,
  required YearMonth month,
  required CurrencyCode currency,
}) async {
  final items = <FinancialTransaction>[
    _transaction(
      'salary',
      'Software Engineer Salary',
      TransactionKind.income,
      380000,
      month,
      currency,
      recurring: true,
    ),
    _transaction(
      'rent',
      'Apartment Rent',
      TransactionKind.expense,
      60000,
      month,
      currency,
      recurring: true,
    ),
    _transaction(
      'electricity',
      'Electricity',
      TransactionKind.expense,
      14000,
      month,
      currency,
      recurring: true,
    ),
    _transaction(
      'water',
      'Water',
      TransactionKind.expense,
      8000,
      month,
      currency,
      recurring: true,
    ),
    _transaction(
      'internet',
      'Internet',
      TransactionKind.expense,
      7990,
      month,
      currency,
      recurring: true,
    ),
    _transaction(
      'groceries',
      'Groceries',
      TransactionKind.expense,
      80000,
      month,
      currency,
      recurring: true,
    ),
    _transaction(
      'college',
      'College Tuition',
      TransactionKind.expense,
      75000,
      month,
      currency,
      recurring: true,
      installmentLabel: '12/48',
    ),
    _transaction(
      'car',
      'Car Payment',
      TransactionKind.expense,
      80000,
      month,
      currency,
      recurring: false,
      installmentLabel: '1/48',
    ),
    _transaction(
      'tv',
      'Home Furniture',
      TransactionKind.expense,
      19090,
      month,
      currency,
      recurring: true,
      installmentLabel: '1/12',
    ),
  ];
  for (final item in items) {
    await repository.saveTransaction(item);
  }
}

Future<void> seedEmergencyObjectiveDemo({
  required ObjectiveRepository objectives,
  required FinancialRepository financial,
  required YearMonth currentMonth,
}) async {
  const objectiveId = 'objective:demo-emergency-reserve';
  final existing = (await objectives.loadAll()).toList();
  // Remove only the empty goal that was auto-imported from the retired block.
  if (existing.any(
    (item) => item.id == 'objective:emergency-reserve:imported',
  )) {
    await objectives.delete('objective:emergency-reserve:imported');
    existing.removeWhere(
      (item) => item.id == 'objective:emergency-reserve:imported',
    );
  }
  if (existing.any((item) => item.id == objectiveId)) return;
  if (existing.any((item) => item.name.toLowerCase().contains('reserva'))) {
    return;
  }
  final start = currentMonth.addMonths(-5);
  const amount = 30000;
  final goal = FinancialObjective(
    id: objectiveId,
    name: 'Emergency fund',
    instrument: '',
    targetMonths: 6,
    initialBalanceMinor: 0,
    targetAmountMinor: 2000000,
    annualRateBasisPoints: 400,
    monthlyContributionMinor: amount,
    frequency: ObjectiveContributionFrequency.monthly,
    startMonth: start,
    currency: CurrencyCode.usd,
  );
  await objectives.save(goal);
  for (var index = 0; index < 6; index++) {
    final month = start.addMonths(index);
    await financial.saveTransaction(
      FinancialTransaction(
        id: 'objective:$objectiveId:${month.databaseKey}',
        title: 'Contribution · Emergency fund',
        kind: TransactionKind.expense,
        originalAmountMinor: amount,
        currency: CurrencyCode.usd,
        month: month,
        recurring: index == 5,
      ),
    );
  }
}

Future<void> seedFirst100kObjectiveDemo({
  required ObjectiveRepository objectives,
  required FinancialRepository financial,
  required YearMonth currentMonth,
}) async {
  const objectiveId = 'objective:demo-first-100k';
  const start = YearMonth(2026, 1);
  const title = 'Contribution · My First 100K';
  const monthlyAmountMinor = 50000;
  final existing = await objectives.loadAll();
  if (existing.any(
    (item) =>
        item.id == objectiveId ||
        item.name.trim().toLowerCase() == 'my first 100k' ||
        item.name.trim().toLowerCase() == 'meus primeiros 100k',
  )) {
    return;
  }

  await objectives.save(
    FinancialObjective(
      id: objectiveId,
      name: 'My First 100K',
      instrument: '',
      targetMonths: 180,
      initialBalanceMinor: 0,
      targetAmountMinor: 10000000,
      annualRateBasisPoints: 500,
      monthlyContributionMinor: monthlyAmountMinor,
      frequency: ObjectiveContributionFrequency.monthly,
      startMonth: start,
      currency: CurrencyCode.usd,
    ),
  );

  var month = start;
  while (month.compareTo(currentMonth) <= 0) {
    await financial.saveTransaction(
      FinancialTransaction(
        id: 'objective:$objectiveId:${month.databaseKey}',
        title: title,
        kind: TransactionKind.expense,
        originalAmountMinor: monthlyAmountMinor,
        currency: CurrencyCode.usd,
        month: month,
      ),
    );
    month = month.addMonths(1);
  }
  await _scheduleNextDemoContribution(
    financial: financial,
    objectiveId: objectiveId,
    title: title,
    currentMonth: currentMonth,
    amountMinor: monthlyAmountMinor,
  );
}

Future<void> seedOwnHomeObjectiveDemo({
  required ObjectiveRepository objectives,
  required FinancialRepository financial,
  required YearMonth currentMonth,
}) async {
  const objectiveId = 'objective:demo-own-home';
  final existing = await objectives.loadAll();
  if (existing.any(
    (item) =>
        item.id == objectiveId ||
        item.name.trim().toLowerCase() == 'own a home',
  )) {
    return;
  }

  const start = YearMonth(2026, 2);
  const previousMonthlyAmountMinor = 50000;
  const monthlyAmountMinor = 220000;
  await objectives.save(
    FinancialObjective(
      id: objectiveId,
      name: 'Own a Home',
      instrument: '',
      targetMonths: 120,
      initialBalanceMinor: 0,
      targetAmountMinor: 40000000,
      annualRateBasisPoints: 1000,
      monthlyContributionMinor: monthlyAmountMinor,
      frequency: ObjectiveContributionFrequency.monthly,
      startMonth: start,
      currency: CurrencyCode.usd,
      monthlyOverrides: {
        for (var index = 0; index < 8; index++)
          start.addMonths(index).databaseKey: ObjectiveMonthOverride(
            contributionMinor: previousMonthlyAmountMinor,
          ),
      },
    ),
  );

  var month = start;
  while (month.compareTo(currentMonth) <= 0) {
    await financial.saveTransaction(
      FinancialTransaction(
        id: 'objective:$objectiveId:${month.databaseKey}',
        title: 'Contribution · Own a Home',
        kind: TransactionKind.expense,
        originalAmountMinor: month.compareTo(const YearMonth(2026, 10)) < 0
            ? previousMonthlyAmountMinor
            : monthlyAmountMinor,
        currency: CurrencyCode.usd,
        month: month,
      ),
    );
    month = month.addMonths(1);
  }
  await _scheduleNextDemoContribution(
    financial: financial,
    objectiveId: objectiveId,
    title: 'Contribution · Own a Home',
    currentMonth: currentMonth,
    amountMinor: monthlyAmountMinor,
  );
}

Future<void> seedNewCar2031ObjectiveDemo({
  required ObjectiveRepository objectives,
  required FinancialRepository financial,
  required YearMonth currentMonth,
}) async {
  const objectiveId = 'objective:demo-new-car-2031';
  const start = YearMonth(2026, 1);
  final existing = await objectives.loadAll();
  if (existing.any(
    (item) =>
        item.id == objectiveId ||
        item.name.trim().toLowerCase() == 'new car 2031',
  )) {
    return;
  }

  const previousMonthlyAmountMinor = 75000;
  const monthlyAmountMinor = 95000;
  await objectives.save(
    FinancialObjective(
      id: objectiveId,
      name: 'New Car 2031',
      instrument: '',
      targetMonths: 60,
      initialBalanceMinor: 0,
      targetAmountMinor: 6000000,
      annualRateBasisPoints: 450,
      monthlyContributionMinor: monthlyAmountMinor,
      frequency: ObjectiveContributionFrequency.monthly,
      startMonth: start,
      currency: CurrencyCode.usd,
      monthlyOverrides: {
        for (var index = 0; index < 9; index++)
          start.addMonths(index).databaseKey: ObjectiveMonthOverride(
            contributionMinor: previousMonthlyAmountMinor,
          ),
      },
    ),
  );

  var month = start;
  while (month.compareTo(currentMonth) <= 0) {
    await financial.saveTransaction(
      FinancialTransaction(
        id: 'objective:$objectiveId:${month.databaseKey}',
        title: 'Contribution · New Car 2031',
        kind: TransactionKind.expense,
        originalAmountMinor: month.compareTo(const YearMonth(2026, 10)) < 0
            ? previousMonthlyAmountMinor
            : monthlyAmountMinor,
        currency: CurrencyCode.usd,
        month: month,
      ),
    );
    month = month.addMonths(1);
  }
  await _scheduleNextDemoContribution(
    financial: financial,
    objectiveId: objectiveId,
    title: 'Contribution · New Car 2031',
    currentMonth: currentMonth,
    amountMinor: monthlyAmountMinor,
  );
}

Future<void> _scheduleNextDemoContribution({
  required FinancialRepository financial,
  required String objectiveId,
  required String title,
  required YearMonth currentMonth,
  required int amountMinor,
}) async {
  final nextMonth = currentMonth.addMonths(1);
  await financial.saveTransaction(
    FinancialTransaction(
      id: 'objective:$objectiveId:${nextMonth.databaseKey}',
      title: title,
      kind: TransactionKind.expense,
      originalAmountMinor: amountMinor,
      currency: CurrencyCode.usd,
      month: nextMonth,
      recurring: true,
    ),
  );
}

Future<void> migrateDemoObjectiveTimeframes({
  required ObjectiveRepository objectives,
  required FinancialRepository financial,
  required YearMonth currentMonth,
}) async {
  for (final plan in [
    (
      id: 'objective:demo-own-home',
      title: 'Contribution · Own a Home',
      oldMonths: 8,
      oldContributionMinor: 50000,
      newMonths: 120,
      newContributionMinor: 220000,
    ),
    (
      id: 'objective:demo-new-car-2031',
      title: 'Contribution · New Car 2031',
      oldMonths: 72,
      oldContributionMinor: 75000,
      newMonths: 60,
      newContributionMinor: 95000,
    ),
  ]) {
    final objective = (await objectives.loadAll())
        .where((item) => item.id == plan.id)
        .firstOrNull;
    if (objective == null ||
        objective.targetMonths != plan.oldMonths ||
        objective.monthlyContributionMinor != plan.oldContributionMinor) {
      continue;
    }

    final overrides = Map<String, ObjectiveMonthOverride>.of(
      objective.monthlyOverrides,
    );
    for (final snapshot in ObjectiveEvolution.calculate(
      objective,
      throughMonth: currentMonth,
    )) {
      overrides.putIfAbsent(
        snapshot.month.databaseKey,
        () => ObjectiveMonthOverride(
          contributionMinor: snapshot.contributionMinor,
          yieldMinor: snapshot.yieldIsEstimate ? null : snapshot.yieldMinor,
        ),
      );
    }
    await objectives.save(
      objective.copyWith(
        targetMonths: plan.newMonths,
        monthlyContributionMinor: plan.newContributionMinor,
        monthlyOverrides: Map.unmodifiable(overrides),
      ),
    );

    for (final transaction in await financial.transactionsFor(currentMonth)) {
      if (transaction.active &&
          transaction.recurring &&
          transaction.id.contains(plan.id) &&
          (transaction.title == plan.title ||
              transaction.title ==
                  plan.title.replaceFirst('Contribution', 'Aporte'))) {
        await financial.saveTransaction(transaction.copyWith(recurring: false));
      }
    }
    await _scheduleNextDemoContribution(
      financial: financial,
      objectiveId: plan.id,
      title: plan.title,
      currentMonth: currentMonth,
      amountMinor: plan.newContributionMinor,
    );
  }
}

Future<void> migrateEmergencyObjectiveDemoRate(
  ObjectiveRepository objectives,
) async {
  final sample = (await objectives.loadAll())
      .where((item) => item.id == 'objective:demo-emergency-reserve')
      .firstOrNull;
  if (sample != null && sample.annualRateBasisPoints == 0) {
    await objectives.save(sample.copyWith(annualRateBasisPoints: 400));
  }
}

Future<void> migrateOwnHomeObjectiveDemoRate(
  ObjectiveRepository objectives,
) async {
  final sample = (await objectives.loadAll())
      .where((item) => item.id == 'objective:demo-own-home')
      .firstOrNull;
  if (sample != null && sample.annualRateBasisPoints != 1000) {
    await objectives.save(sample.copyWith(annualRateBasisPoints: 1000));
  }
}

Future<void> removeObjectiveInvestmentMetadata(
  ObjectiveRepository objectives,
) async {
  for (final objective in await objectives.loadAll()) {
    if (objective.instrument.isNotEmpty) {
      await objectives.save(objective.copyWith(instrument: ''));
    }
  }
}

Future<void> seedExtraIncomeDemo({
  required ExtraIncomeRepository repository,
  required YearMonth month,
  required CurrencyCode currency,
}) async {
  final items = <ExtraIncomeEntry>[
    _extra(
      'design',
      ExtraIncomeKind.service,
      'Freelance Web Design',
      'One-off client project',
      45000,
      month,
      currency,
      recurring: false,
    ),
    _extra(
      'maintenance',
      ExtraIncomeKind.service,
      'Computer Setup',
      'Technical service',
      18000,
      month,
      currency,
      recurring: true,
    ),
    _extra(
      'bike',
      ExtraIncomeKind.sale,
      'Used Bicycle Sale',
      'Occasional sale',
      35000,
      month,
      currency,
      recurring: false,
    ),
    _extra(
      'sweets',
      ExtraIncomeKind.sale,
      'Online Marketplace Sale',
      'Side income',
      22000,
      month,
      currency,
      recurring: true,
    ),
  ];
  for (final item in items) {
    await repository.saveEntry(item);
  }
}

Future<void> seedInvestmentDemo({
  required InvestmentRepository repository,
  required YearMonth month,
}) async {
  final now = DateTime.now().toUtc();
  final items = <InvestmentPosition>[
    _position(
      'petrobras',
      const InstrumentIdentity(
        providerAssetId: 'br-petr4',
        family: AssetFamily.equity,
        symbol: 'PETR4',
        officialName: 'Petróleo Brasileiro S.A. — Petrobras',
        exchangeMic: 'BVMF',
        countryCode: 'BR',
        currency: CurrencyCode.brl,
      ),
      150000,
      6500,
      month,
      now,
    ),
    _position(
      'bnd',
      const InstrumentIdentity(
        providerAssetId: 'us-bnd',
        family: AssetFamily.governmentBond,
        symbol: 'BND',
        officialName: 'Vanguard Total Bond Market ETF',
        exchangeMic: 'ARCX',
        countryCode: 'US',
        currency: CurrencyCode.usd,
      ),
      35000,
      420,
      month,
      now,
    ),
    _position(
      'bhia3',
      const InstrumentIdentity(
        providerAssetId: 'br-bhia3',
        family: AssetFamily.equity,
        symbol: 'BHIA3',
        officialName: 'Via S.A.',
        exchangeMic: 'BVMF',
        countryCode: 'BR',
        currency: CurrencyCode.brl,
      ),
      28000,
      -310,
      month,
      now,
    ),
    _position(
      'reliance',
      const InstrumentIdentity(
        providerAssetId: 'in-reliance',
        family: AssetFamily.equity,
        symbol: 'RELIANCE',
        officialName: 'Reliance Industries Limited',
        exchangeMic: 'XBOM',
        countryCode: 'IN',
        currency: CurrencyCode.inr,
      ),
      250000,
      2100,
      month,
      now,
    ),
    _position(
      'apple',
      const InstrumentIdentity(
        providerAssetId: 'us-aapl',
        family: AssetFamily.equity,
        symbol: 'AAPL',
        officialName: 'Apple Inc.',
        exchangeMic: 'XNAS',
        countryCode: 'US',
        currency: CurrencyCode.usd,
      ),
      180000,
      3400,
      month,
      now,
    ),
    _position(
      'infosys',
      const InstrumentIdentity(
        providerAssetId: 'in-infy',
        family: AssetFamily.equity,
        symbol: 'INFY',
        officialName: 'Infosys Limited',
        exchangeMic: 'XNSE',
        countryCode: 'IN',
        currency: CurrencyCode.inr,
      ),
      185000,
      2800,
      month,
      now,
    ),
    _position(
      'bitcoin',
      const InstrumentIdentity(
        providerAssetId: 'cmc-1',
        family: AssetFamily.crypto,
        symbol: 'BTC',
        officialName: 'Bitcoin',
        exchangeMic: 'CMC',
        countryCode: 'GLOBAL',
        currency: CurrencyCode.usd,
      ),
      120000,
      0,
      month,
      now,
      quantity: '0.018',
    ),
    _position(
      'ethereum',
      const InstrumentIdentity(
        providerAssetId: 'cmc-1027',
        family: AssetFamily.crypto,
        symbol: 'ETH',
        officialName: 'Ethereum',
        exchangeMic: 'CMC',
        countryCode: 'GLOBAL',
        currency: CurrencyCode.usd,
      ),
      90000,
      0,
      month,
      now,
      quantity: '0.42',
    ),
    _position(
      'solana',
      const InstrumentIdentity(
        providerAssetId: 'cmc-5426',
        family: AssetFamily.crypto,
        symbol: 'SOL',
        officialName: 'Solana',
        exchangeMic: 'CMC',
        countryCode: 'GLOBAL',
        currency: CurrencyCode.usd,
      ),
      55000,
      0,
      month,
      now,
      quantity: '2.4',
    ),
    _position(
      'xrp',
      const InstrumentIdentity(
        providerAssetId: 'cmc-52',
        family: AssetFamily.crypto,
        symbol: 'XRP',
        officialName: 'XRP',
        exchangeMic: 'CMC',
        countryCode: 'GLOBAL',
        currency: CurrencyCode.usd,
      ),
      30000,
      0,
      month,
      now,
      quantity: '75',
    ),
    _position(
      'usdt',
      const InstrumentIdentity(
        providerAssetId: 'cmc-825',
        family: AssetFamily.crypto,
        symbol: 'USDT',
        officialName: 'Tether USDt',
        exchangeMic: 'CMC',
        countryCode: 'GLOBAL',
        currency: CurrencyCode.usd,
      ),
      25000,
      0,
      month,
      now,
      quantity: '120',
    ),
    _position(
      'usdc',
      const InstrumentIdentity(
        providerAssetId: 'cmc-3408',
        family: AssetFamily.crypto,
        symbol: 'USDC',
        officialName: 'USDC',
        exchangeMic: 'CMC',
        countryCode: 'GLOBAL',
        currency: CurrencyCode.usd,
      ),
      22000,
      0,
      month,
      now,
      quantity: '100',
    ),
  ];
  for (final item in items) {
    await repository.save(item);
  }
}

/// Seeds a varied, editable twelve-month history for the browser preview.
/// Every row uses a stable demo ID so it is stored like a normal user record,
/// survives reloads, and remains subject to the app's ordinary delete/undo UI.
Future<void> seedRecurringPoolCleaningDemo({
  required ExtraIncomeRepository repository,
  required YearMonth currentMonth,
}) async {
  const start = YearMonth(2026, 1);
  const id = 'demo:extra:pool-cleaning:2026-01';
  final january = await repository.entriesFor(start);
  if (!january.any((entry) => entry.id == id)) {
    await repository.saveEntry(
      const ExtraIncomeEntry(
        id: id,
        kind: ExtraIncomeKind.service,
        name: 'Pool cleaning',
        description: 'Monthly pool maintenance',
        amountMinor: 30000,
        currency: CurrencyCode.usd,
        month: start,
        recurring: true,
        includeInFinancialIncome: true,
      ),
    );
  }
  for (
    var month = start.addMonths(1);
    month.compareTo(currentMonth) <= 0;
    month = month.addMonths(1)
  ) {
    await repository.materializeRecurringEntries(month);
  }
}

Future<void> seedAnnualBrowserDemo({
  required FinancialRepository financialRepository,
  required ExtraIncomeRepository extraIncomeRepository,
  required InvestmentRepository investmentRepository,
  required YearMonth currentMonth,
  required CurrencyCode currency,
}) async {
  const months = <_DemoMonthAmounts>[
    _DemoMonthAmounts(
      380000,
      128000,
      28000,
      56000,
      19000,
      12000,
      24000,
      21000,
      15000,
      48000,
      32000,
      26000,
      18000,
    ),
    _DemoMonthAmounts(
      385000,
      128000,
      31000,
      59000,
      21000,
      18000,
      26000,
      25000,
      16000,
      29000,
      51000,
      34000,
      22000,
    ),
    _DemoMonthAmounts(
      385000,
      128000,
      27000,
      61000,
      22000,
      16000,
      22000,
      31000,
      18000,
      54000,
      28000,
      19000,
      39000,
    ),
    _DemoMonthAmounts(
      390000,
      132000,
      32000,
      64000,
      20000,
      15000,
      24000,
      28000,
      18000,
      35000,
      41000,
      47000,
      21000,
    ),
    _DemoMonthAmounts(
      395000,
      132000,
      30000,
      68000,
      23000,
      21000,
      29000,
      35000,
      20000,
      61000,
      23000,
      29000,
      44000,
    ),
    _DemoMonthAmounts(
      395000,
      132000,
      35000,
      63000,
      24000,
      17000,
      25000,
      26000,
      22000,
      42000,
      57000,
      24000,
      31000,
    ),
    _DemoMonthAmounts(
      405000,
      136000,
      34000,
      72000,
      26000,
      24000,
      27000,
      38000,
      22000,
      67000,
      39000,
      52000,
      24000,
    ),
    _DemoMonthAmounts(
      405000,
      136000,
      33000,
      67000,
      25000,
      20000,
      28000,
      30000,
      24000,
      31000,
      69000,
      33000,
      56000,
    ),
    _DemoMonthAmounts(
      415000,
      140000,
      36000,
      71000,
      27000,
      19000,
      30000,
      42000,
      25000,
      73000,
      36000,
      21000,
      62000,
    ),
    _DemoMonthAmounts(
      415000,
      140000,
      39000,
      76000,
      28000,
      26000,
      32000,
      34000,
      26000,
      39000,
      72000,
      58000,
      27000,
    ),
    _DemoMonthAmounts(
      425000,
      144000,
      38000,
      74000,
      30000,
      22000,
      34000,
      46000,
      28000,
      79000,
      45000,
      37000,
      64000,
    ),
    _DemoMonthAmounts(
      435000,
      144000,
      42000,
      80000,
      31000,
      28000,
      36000,
      39000,
      30000,
      45000,
      82000,
      71000,
      33000,
    ),
  ];

  final now = DateTime.now().toUtc();
  for (var index = 0; index < months.length; index++) {
    final month = currentMonth.addMonths(index - months.length + 1);
    final amounts = months[index];
    final financialItems = <FinancialTransaction>[
      _transaction(
        'salary',
        'Salary',
        TransactionKind.income,
        amounts.salary,
        month,
        currency,
        recurring: true,
      ),
      _transaction(
        'rent',
        'Rent',
        TransactionKind.expense,
        amounts.rent,
        month,
        currency,
        recurring: true,
      ),
      _transaction(
        'utilities',
        'Household bills',
        TransactionKind.expense,
        amounts.utilities,
        month,
        currency,
        recurring: true,
      ),
      _transaction(
        'groceries',
        'Groceries',
        TransactionKind.expense,
        amounts.groceries,
        month,
        currency,
      ),
      _transaction(
        'transport',
        'Transportation',
        TransactionKind.expense,
        amounts.transport,
        month,
        currency,
      ),
      _transaction(
        'health',
        'Healthcare',
        TransactionKind.expense,
        amounts.health,
        month,
        currency,
      ),
      _transaction(
        'leisure',
        'Leisure and dining',
        TransactionKind.expense,
        amounts.leisure,
        month,
        currency,
      ),
      _transaction(
        'installment',
        'Appliances',
        TransactionKind.expense,
        amounts.installment,
        month,
        currency,
        installmentLabel: '${index + 1}/12',
      ),
    ];
    for (final item in financialItems) {
      await financialRepository.saveTransaction(item);
    }

    final entries = <ExtraIncomeEntry>[
      _extra(
        'service',
        ExtraIncomeKind.service,
        'Freelance service',
        'Project or client work this month',
        amounts.service,
        month,
        currency,
      ),
      _extra(
        'sale',
        ExtraIncomeKind.sale,
        'Occasional sale',
        'Sale of an item or product',
        amounts.sale,
        month,
        currency,
      ),
    ];
    for (final entry in entries) {
      await extraIncomeRepository.saveEntry(entry);
    }

    if (index < months.length - 1) {
      await _seedMonthlyInvestment(
        repository: investmentRepository,
        month: month,
        createdAt: now,
        index: index,
        commonAmountMinor: amounts.commonInvestment,
        cryptoAmountMinor: amounts.cryptoInvestment,
      );
    } else {
      await seedInvestmentDemo(repository: investmentRepository, month: month);
    }
  }
}

Future<void> _seedMonthlyInvestment({
  required InvestmentRepository repository,
  required YearMonth month,
  required DateTime createdAt,
  required int index,
  required int commonAmountMinor,
  required int cryptoAmountMinor,
}) async {
  const commonIdentities = <InstrumentIdentity>[
    InstrumentIdentity(
      providerAssetId: 'us-aapl',
      family: AssetFamily.equity,
      symbol: 'AAPL',
      officialName: 'Apple Inc.',
      exchangeMic: 'XNAS',
      countryCode: 'US',
      currency: CurrencyCode.usd,
    ),
    InstrumentIdentity(
      providerAssetId: 'us-bnd',
      family: AssetFamily.governmentBond,
      symbol: 'BND',
      officialName: 'Vanguard Total Bond Market ETF',
      exchangeMic: 'ARCX',
      countryCode: 'US',
      currency: CurrencyCode.usd,
    ),
    InstrumentIdentity(
      providerAssetId: 'us-aapl',
      family: AssetFamily.equity,
      symbol: 'AAPL',
      officialName: 'Apple Inc.',
      exchangeMic: 'XNAS',
      countryCode: 'US',
      currency: CurrencyCode.usd,
    ),
  ];
  const cryptoIdentities =
      <({InstrumentIdentity identity, int unitPriceMinor})>[
        (
          identity: InstrumentIdentity(
            providerAssetId: 'cmc-1',
            family: AssetFamily.crypto,
            symbol: 'BTC',
            officialName: 'Bitcoin',
            exchangeMic: 'CMC',
            countryCode: 'GLOBAL',
            currency: CurrencyCode.usd,
          ),
          unitPriceMinor: 6000000,
        ),
        (
          identity: InstrumentIdentity(
            providerAssetId: 'cmc-1027',
            family: AssetFamily.crypto,
            symbol: 'ETH',
            officialName: 'Ethereum',
            exchangeMic: 'CMC',
            countryCode: 'GLOBAL',
            currency: CurrencyCode.usd,
          ),
          unitPriceMinor: 300000,
        ),
        (
          identity: InstrumentIdentity(
            providerAssetId: 'cmc-5426',
            family: AssetFamily.crypto,
            symbol: 'SOL',
            officialName: 'Solana',
            exchangeMic: 'CMC',
            countryCode: 'GLOBAL',
            currency: CurrencyCode.usd,
          ),
          unitPriceMinor: 14000,
        ),
      ];
  final common = commonIdentities[index % commonIdentities.length];
  final crypto = cryptoIdentities[index % cryptoIdentities.length];
  final cryptoQuantity = (cryptoAmountMinor / crypto.unitPriceMinor)
      .toStringAsFixed(8);
  for (final position in <InvestmentPosition>[
    _position(
      'annual-common-$index',
      common,
      commonAmountMinor,
      commonAmountMinor ~/ 100,
      month,
      createdAt,
    ),
    _position(
      'annual-crypto-$index',
      crypto.identity,
      cryptoAmountMinor,
      cryptoAmountMinor ~/ 80,
      month,
      createdAt,
      quantity: cryptoQuantity,
    ),
  ]) {
    await repository.save(position);
  }
}

final class _DemoMonthAmounts {
  const _DemoMonthAmounts(
    this.salary,
    this.rent,
    this.utilities,
    this.groceries,
    this.transport,
    this.health,
    this.leisure,
    this.installment,
    this.reserve,
    this.service,
    this.sale,
    this.commonInvestment,
    this.cryptoInvestment,
  );

  final int salary;
  final int rent;
  final int utilities;
  final int groceries;
  final int transport;
  final int health;
  final int leisure;
  final int installment;
  final int reserve;
  final int service;
  final int sale;
  final int commonInvestment;
  final int cryptoInvestment;
}

FinancialTransaction _transaction(
  String key,
  String title,
  TransactionKind kind,
  int amountMinor,
  YearMonth month,
  CurrencyCode currency, {
  bool recurring = false,
  String? installmentLabel,
}) => FinancialTransaction(
  id: 'demo:financial:$key:${month.databaseKey}',
  title: title,
  kind: kind,
  originalAmountMinor: amountMinor,
  currency: currency,
  month: month,
  recurring: recurring,
  installmentLabel: installmentLabel,
);

ExtraIncomeEntry _extra(
  String key,
  ExtraIncomeKind kind,
  String name,
  String description,
  int amountMinor,
  YearMonth month,
  CurrencyCode currency, {
  bool recurring = false,
}) => ExtraIncomeEntry(
  id: 'demo:extra:$key:${month.databaseKey}',
  kind: kind,
  name: name,
  description: description,
  amountMinor: amountMinor,
  currency: currency,
  month: month,
  includeInFinancialIncome: true,
  recurring: recurring,
);

InvestmentPosition _position(
  String key,
  InstrumentIdentity identity,
  int principalMinor,
  int returnMinor,
  YearMonth month,
  DateTime now, {
  String? quantity,
}) => InvestmentPosition(
  id: 'demo:investment:$key:${month.databaseKey}',
  identity: identity,
  principalMinor: principalMinor,
  monthlyReturnMinor: returnMinor,
  month: month,
  createdAt: now,
  updatedAt: now,
  source: 'demo',
  quantity: quantity,
);
