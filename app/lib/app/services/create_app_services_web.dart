import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/money/money.dart';
import '../../core/time/year_month.dart';
import '../../shared/formatting/installment_formatter.dart';
import '../../features/screen_1_financial/domain/financial_repository.dart';
import '../../features/screen_1_financial/domain/financial_transaction.dart';
import '../../features/screen_1_financial/domain/monthly_summary.dart';
import '../../features/screen_2_extra_income/application/extra_income_contribution_port.dart';
import '../../features/screen_2_extra_income/domain/extra_income_entry.dart';
import '../../features/screen_2_extra_income/domain/extra_income_repository.dart';
import '../../features/screen_3_investments/domain/investment_position.dart';
import '../../features/screen_3_investments/domain/investment_repository.dart';
import '../../features/screen_3_investments/domain/asset_family.dart';
import '../../features/screen_3_investments/domain/instrument_identity.dart';
import '../../features/screen_6_agenda/application/notification_contracts.dart';
import '../../features/screen_6_agenda/domain/agenda_event.dart';
import '../../features/screen_6_agenda/domain/agenda_repository.dart';
import '../../features/screen_4_objectives/data/shared_preferences_objective_repository.dart';
import '../../features/screen_4_objectives/domain/objective_repository.dart';
import 'app_services.dart';
import 'initial_demo_data.dart';

AppServices createAppServices() => _WebAppServices();

final class _WebAppServices implements AppServices {
  _WebAppServices() {
    final extra = _MemoryExtraIncomeRepository();
    financialRepository = _MemoryFinancialRepository();
    extraIncomeRepository = extra;
    extraIncomeContributionPort = extra;
    investmentRepository = _MemoryInvestmentRepository();
    objectiveRepository = const SharedPreferencesObjectiveRepository();
    agendaRepository = _MemoryAgendaRepository();
  }
  bool _initialDemoChecked = false;

  @override
  Future<void> ensureInitialDemoData({
    required YearMonth month,
    required CurrencyCode currency,
  }) async {
    if (_initialDemoChecked) return;
    _initialDemoChecked = true;
    final preferences = await SharedPreferences.getInstance();
    final financial = financialRepository as _MemoryFinancialRepository;
    final extra = extraIncomeRepository as _MemoryExtraIncomeRepository;
    final investments = investmentRepository as _MemoryInvestmentRepository;
    await financial.loadFromStorage(preferences);
    await extra.loadFromStorage(preferences);
    await investments.loadFromStorage(preferences);
    if (preferences.getBool('history.personal-start.v1') == true) return;
    const legacyCleanupMarker = 'migration.remove-legacy-emergency-fund.v1';
    if (preferences.getBool(legacyCleanupMarker) != true) {
      financial._items.removeWhere(
        (item) =>
            item.id.startsWith('emergency-fund:') ||
            FinancialTransaction.legacyEmergencyFundTitles.contains(
              item.title.trim().toLowerCase(),
            ),
      );
      financial._funds.clear();
      await financial._persist();
      await preferences.remove(_fundsStorageKey);
      await preferences.setBool(legacyCleanupMarker, true);
    }
    const demoMarker = 'demo.seed.annual-browser.v1';
    if (preferences.getBool(demoMarker) != true &&
        financial._items.isEmpty &&
        extra._items.isEmpty &&
        investments._items.isEmpty) {
      await seedAnnualBrowserDemo(
        financialRepository: financial,
        extraIncomeRepository: extra,
        investmentRepository: investments,
        currentMonth: month,
        currency: CurrencyCode.usd,
      );
      await preferences.setBool(demoMarker, true);
    }
    const objectiveDemoMarker = 'demo.seed.objectives.emergency-six-month.v1';
    if (preferences.getBool(objectiveDemoMarker) != true) {
      await seedEmergencyObjectiveDemo(
        objectives: objectiveRepository,
        financial: financialRepository,
        currentMonth: month,
      );
      await preferences.setBool(objectiveDemoMarker, true);
    }
    const first100kDemoMarker = 'demo.seed.objectives.first-100k.v1';
    if (preferences.getBool(first100kDemoMarker) != true) {
      await seedFirst100kObjectiveDemo(
        objectives: objectiveRepository,
        financial: financialRepository,
        currentMonth: month,
      );
      await preferences.setBool(first100kDemoMarker, true);
    }
    const ownHomeDemoMarker = 'demo.seed.objectives.own-home-eight-month.v1';
    if (preferences.getBool(ownHomeDemoMarker) != true) {
      await seedOwnHomeObjectiveDemo(
        objectives: objectiveRepository,
        financial: financialRepository,
        currentMonth: month,
      );
      await preferences.setBool(ownHomeDemoMarker, true);
    }
    const newCarDemoMarker = 'demo.seed.objectives.new-car-2031.v1';
    if (preferences.getBool(newCarDemoMarker) != true) {
      await seedNewCar2031ObjectiveDemo(
        objectives: objectiveRepository,
        financial: financialRepository,
        currentMonth: month,
      );
      await preferences.setBool(newCarDemoMarker, true);
    }
    const timeframeMarker = 'migration.demo-objective-timeframes.v1';
    if (preferences.getBool(timeframeMarker) != true) {
      await migrateDemoObjectiveTimeframes(
        objectives: objectiveRepository,
        financial: financialRepository,
        currentMonth: month,
      );
      await preferences.setBool(timeframeMarker, true);
    }
    const objectiveRateMarker = 'migration.emergency-objective-rate-4.v1';
    if (preferences.getBool(objectiveRateMarker) != true) {
      await migrateEmergencyObjectiveDemoRate(objectiveRepository);
      await preferences.setBool(objectiveRateMarker, true);
    }
    const ownHomeRateMarker = 'migration.own-home-objective-rate-10.v1';
    if (preferences.getBool(ownHomeRateMarker) != true) {
      await migrateOwnHomeObjectiveDemoRate(objectiveRepository);
      await preferences.setBool(ownHomeRateMarker, true);
    }
    const objectiveMetadataMarker = 'migration.objectives.remove-investment.v1';
    if (preferences.getBool(objectiveMetadataMarker) != true) {
      await removeObjectiveInvestmentMetadata(objectiveRepository);
      await preferences.setBool(objectiveMetadataMarker, true);
    }
    const englishExamplesMarker = 'migration.english-example-records.v1';
    if (preferences.getBool(englishExamplesMarker) != true) {
      const financialNames = <String, String>{
        'salary': 'Salary',
        'rent': 'Rent',
        'utilities': 'Household bills',
        'groceries': 'Groceries',
        'transport': 'Transportation',
        'health': 'Healthcare',
        'leisure': 'Leisure and dining',
        'installment': 'Appliances',
      };
      for (final item in financial._items.toList()) {
        final key = item.id.startsWith('demo:financial:')
            ? item.id.split(':').elementAtOrNull(2)
            : null;
        final translated = financialNames[key];
        final title =
            translated ??
            switch (item.title) {
              'Aporte · Reserva de emergência' =>
                'Contribution · Emergency fund',
              'Aporte · Meus primeiros 100K' => 'Contribution · My First 100K',
              'Aporte · Own a Home' => 'Contribution · Own a Home',
              'Aporte · New Car 2031' => 'Contribution · New Car 2031',
              _ => item.title,
            };
        if (title != item.title) {
          await financial.saveTransaction(item.copyWith(title: title));
        }
      }
      for (final entry in extra._items.toList()) {
        if (!entry.id.startsWith('demo:extra:')) continue;
        final name = switch (entry.name) {
          'Serviço freelance' => 'Freelance service',
          'Venda ocasional' => 'Occasional sale',
          _ => entry.name,
        };
        final description = switch (entry.description) {
          'Projeto ou atendimento do mês' =>
            'Project or client work this month',
          'Venda de item ou produto' => 'Sale of an item or product',
          _ => entry.description,
        };
        if (name != entry.name || description != entry.description) {
          await extra.saveEntry(
            ExtraIncomeEntry(
              id: entry.id,
              kind: entry.kind,
              name: name,
              description: description,
              amountMinor: entry.amountMinor,
              currency: entry.currency,
              month: entry.month,
              recurring: entry.recurring,
              includeInFinancialIncome: entry.includeInFinancialIncome,
              recurrenceTemplateId: entry.recurrenceTemplateId,
              deletedAt: entry.deletedAt,
            ),
          );
        }
      }
      for (final goal in await objectiveRepository.loadAll()) {
        final name = switch (goal.name) {
          'Reserva de emergência'
              when goal.id == 'objective:demo-emergency-reserve' =>
            'Emergency fund',
          'Meus primeiros 100K' => 'My First 100K',
          _ => goal.name,
        };
        if (name != goal.name) {
          await objectiveRepository.save(goal.copyWith(name: name));
        }
      }
      await preferences.setBool(englishExamplesMarker, true);
    }
    const poolCleaningMarker = 'demo.seed.pool-cleaning-recurring.v1';
    if (preferences.getBool(poolCleaningMarker) != true) {
      await seedRecurringPoolCleaningDemo(
        repository: extraIncomeRepository,
        currentMonth: month,
      );
      await preferences.setBool(poolCleaningMarker, true);
    }
  }

  @override
  Future<void> resetPersonalHistory() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('history.personal-start.v1', true);
    final financial = financialRepository as _MemoryFinancialRepository;
    final extra = extraIncomeRepository as _MemoryExtraIncomeRepository;
    final investments = investmentRepository as _MemoryInvestmentRepository;
    financial._items.clear();
    financial._funds.clear();
    extra._items.clear();
    extra._templates.clear();
    investments._items.clear();
    (agendaRepository as _MemoryAgendaRepository)._items.clear();
    await Future.wait([
      financial._persist(),
      extra._persist(),
      investments._persist(),
      preferences.remove(_fundsStorageKey),
      (objectiveRepository as SharedPreferencesObjectiveRepository).clearAll(),
    ]);
  }

  @override
  Future<YearMonth?> earliestRecordedMonth() async {
    YearMonth? earliest;
    void include(YearMonth month) {
      if (earliest == null || month.compareTo(earliest!) < 0) earliest = month;
    }

    for (final item
        in (financialRepository as _MemoryFinancialRepository)._items) {
      if (item.active) include(item.month);
    }
    final extra = extraIncomeRepository as _MemoryExtraIncomeRepository;
    for (final item in extra._items) {
      if (item.active) include(item.month);
    }
    for (final item in extra._templates.values) {
      if (item.active) include(item.startMonth);
    }
    for (final item
        in (investmentRepository as _MemoryInvestmentRepository)._items) {
      if (item.active) include(item.month);
    }
    for (final item in (agendaRepository as _MemoryAgendaRepository)._items) {
      if (item.deletedAt == null) {
        include(YearMonth(item.start.year, item.start.month));
      }
    }
    for (final item in await objectiveRepository.loadAll()) {
      include(item.startMonth);
    }
    return earliest;
  }

  @override
  late final FinancialRepository financialRepository;
  @override
  late final ExtraIncomeRepository extraIncomeRepository;
  @override
  late final ExtraIncomeContributionPort extraIncomeContributionPort;
  @override
  late final InvestmentRepository investmentRepository;
  @override
  late final ObjectiveRepository objectiveRepository;
  @override
  late final AgendaRepository agendaRepository;
  @override
  LocalNotificationScheduler get notificationScheduler =>
      const DisabledNotificationScheduler();
}

final class _MemoryFinancialRepository implements FinancialRepository {
  final _items = <FinancialTransaction>[];
  final _funds = <CurrencyCode, ({int balanceMinor, int targetMonths})>{};
  SharedPreferences? _preferences;

  Future<void> loadFromStorage(SharedPreferences preferences) async {
    _preferences = preferences;
    final encoded = preferences.getString(_transactionsStorageKey);
    if (encoded == null) return;
    _items
      ..clear()
      ..addAll(
        (jsonDecode(encoded) as List<dynamic>).map(
          (item) => _transactionFromJson(item as Map<String, dynamic>),
        ),
      );
  }

  Future<void> _persist() async => _preferences?.setString(
    _transactionsStorageKey,
    jsonEncode(_items.map(_transactionToJson).toList()),
  );

  Future<void> _persistFunds() async {
    final value = <String, Object>{
      for (final entry in _funds.entries)
        entry.key.isoCode: {
          'balanceMinor': entry.value.balanceMinor,
          'targetMonths': entry.value.targetMonths,
        },
    };
    await _preferences?.setString(_fundsStorageKey, jsonEncode(value));
  }

  @override
  Future<List<FinancialTransaction>> transactionsFor(YearMonth month) async =>
      _items.where((e) => e.month == month).toList();

  @override
  Future<List<FinancialTransaction>> emergencyFundContributions(
    CurrencyCode currency,
  ) async => _items
      .where(
        (item) =>
            item.active &&
            item.currency == currency &&
            item.isEmergencyFundContribution,
      )
      .toList(growable: false);
  @override
  Future<void> saveTransaction(FinancialTransaction value) async {
    _items.removeWhere((e) => e.id == value.id);
    _items.add(value);
    await _persist();
  }

  @override
  Future<List<FinancialTransaction>> materializeRecurringTransactions(
    YearMonth month,
    CurrencyCode currency,
  ) async {
    final currentKeys = _items
        .where((item) => item.month == month && item.currency == currency)
        .map((item) => '${item.kind.name}|${item.title}')
        .toSet();
    final prior =
        _items
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
      final progress = parseInstallmentProgress(source.installmentLabel);
      final nextProgress = progress == null
          ? null
          : advanceInstallmentProgress(
              source.installmentLabel,
              elapsedMonths: monthsBetween(
                fromYear: source.month.year,
                fromMonth: source.month.month,
                toYear: month.year,
                toMonth: month.month,
              ),
            );
      final pendingInstallment = nextProgress != null;
      if (currentKeys.contains(entry.key) ||
          !source.active ||
          (!source.recurring && !pendingInstallment)) {
        continue;
      }
      final occurrence = FinancialTransaction(
        id: pendingInstallment
            ? 'installment:${source.id}:${month.databaseKey}'
            : 'recurring:${source.id}:${month.databaseKey}',
        title: source.title,
        kind: source.kind,
        originalAmountMinor: source.originalAmountMinor,
        currency: source.currency,
        month: month,
        discountType: source.discountType,
        discountValue: source.discountValue,
        recurring: !pendingInstallment,
        installmentLabel: pendingInstallment
            ? encodeInstallmentProgress(
                nextProgress.current,
                nextProgress.total,
              )
            : null,
      );
      await saveTransaction(occurrence);
      created.add(occurrence);
    }
    return created;
  }

  @override
  Future<void> softDelete(String id, DateTime at) async {
    final i = _items.indexWhere((e) => e.id == id);
    if (i >= 0) _items[i] = _items[i].copyWith(deletedAt: at);
    await _persist();
  }

  @override
  Future<void> restore(String id) async {
    final i = _items.indexWhere((e) => e.id == id);
    if (i >= 0) _items[i] = _items[i].copyWith(restore: true);
    await _persist();
  }

  @override
  Future<List<int>> completedExpenseTotalsBefore(
    YearMonth month,
    CurrencyCode currency, {
    int limit = 3,
  }) async {
    final totals = <YearMonth, int>{};
    for (final item in _items.where(
      (item) =>
          item.active &&
          item.kind == TransactionKind.expense &&
          item.currency == currency &&
          item.month.compareTo(month) < 0 &&
          !item.isEmergencyFundContribution,
    )) {
      totals.update(
        item.month,
        (value) => value + item.netAmountMinor,
        ifAbsent: () => item.netAmountMinor,
      );
    }
    final months = totals.keys.toList()..sort((a, b) => b.compareTo(a));
    return months.take(limit).map((item) => totals[item]!).toList();
  }

  @override
  Future<({int balanceMinor, int targetMonths})> emergencyFund(
    CurrencyCode currency,
  ) async => _funds[currency] ?? (balanceMinor: 0, targetMonths: 6);
  @override
  Future<void> saveEmergencyFund({
    required CurrencyCode currency,
    required int balanceMinor,
    required int targetMonths,
  }) async {
    _funds[currency] = (balanceMinor: balanceMinor, targetMonths: targetMonths);
    await _persistFunds();
  }

  @override
  Future<void> saveSummary(MonthlySummary summary) async {}
}

final class _MemoryExtraIncomeRepository
    implements ExtraIncomeRepository, ExtraIncomeContributionPort {
  final _items = <ExtraIncomeEntry>[];
  final _templates = <String, ExtraIncomeRecurrenceTemplate>{};
  SharedPreferences? _preferences;

  Future<void> loadFromStorage(SharedPreferences preferences) async {
    _preferences = preferences;
    final encoded = preferences.getString(_extraIncomeStorageKey);
    if (encoded == null) return;
    _items
      ..clear()
      ..addAll(
        (jsonDecode(encoded) as List<dynamic>).map(
          (item) => _extraFromJson(item as Map<String, dynamic>),
        ),
      );
    _templates.clear();
    final savedTemplates = preferences.getString(
      _extraIncomeTemplatesStorageKey,
    );
    if (savedTemplates != null) {
      for (final item in jsonDecode(savedTemplates) as List<dynamic>) {
        final template = _extraTemplateFromJson(item as Map<String, dynamic>);
        _templates[template.id] = template;
      }
    } else {
      // Recover recurring entries created before browser recurrence existed.
      for (final entry in _items.where((item) => item.recurring)) {
        final id = entry.recurrenceTemplateId ?? 'template:${entry.id}';
        _templates.putIfAbsent(id, () => _templateFromEntry(entry, id));
      }
    }
  }

  Future<void> _persist() async {
    final preferences = _preferences;
    if (preferences == null) return;
    await preferences.setString(
      _extraIncomeStorageKey,
      jsonEncode(_items.map(_extraToJson).toList()),
    );
    await preferences.setString(
      _extraIncomeTemplatesStorageKey,
      jsonEncode(_templates.values.map(_extraTemplateToJson).toList()),
    );
  }

  @override
  Future<List<ExtraIncomeEntry>> entriesFor(YearMonth month) async {
    await materializeRecurringEntries(month);
    return _items.where((e) => e.month == month).toList();
  }

  @override
  Future<void> saveEntry(ExtraIncomeEntry value) async {
    final existing = _items.where((item) => item.id == value.id).firstOrNull;
    final templateId =
        value.recurrenceTemplateId ??
        existing?.recurrenceTemplateId ??
        (value.recurring ? 'template:${value.id}' : null);
    if (templateId != null) {
      final previous = _templates[templateId];
      _templates[templateId] = ExtraIncomeRecurrenceTemplate(
        id: templateId,
        kind: value.kind,
        name: value.name,
        description: value.description,
        amountMinor: value.amountMinor,
        currency: value.currency,
        startMonth: previous?.startMonth ?? value.month,
        includeInFinancialIncome: value.includeInFinancialIncome,
        active: value.recurring,
      );
    }
    final stored = ExtraIncomeEntry(
      id: value.id,
      kind: value.kind,
      name: value.name,
      description: value.description,
      amountMinor: value.amountMinor,
      currency: value.currency,
      month: value.month,
      recurring: value.recurring,
      includeInFinancialIncome: value.includeInFinancialIncome,
      recurrenceTemplateId: templateId,
      deletedAt: value.deletedAt,
    );
    _items.removeWhere((e) => e.id == value.id);
    _items.add(stored);
    await _persist();
  }

  @override
  Future<void> softDelete(String id, DateTime at) async {
    final i = _items.indexWhere((e) => e.id == id);
    if (i >= 0) _items[i] = _items[i].copyWith(deletedAt: at);
    await _persist();
  }

  @override
  Future<void> restore(String id) async {
    final i = _items.indexWhere((e) => e.id == id);
    if (i >= 0) _items[i] = _items[i].copyWith(restore: true);
    await _persist();
  }

  @override
  Future<void> materializeRecurringEntries(YearMonth month) async {
    var changed = false;
    for (final template in _templates.values) {
      if (!template.active || month.compareTo(template.startMonth) <= 0) {
        continue;
      }
      if (_items.any(
        (item) =>
            item.recurrenceTemplateId == template.id && item.month == month,
      )) {
        continue;
      }
      _items.add(template.occurrenceFor(month));
      changed = true;
    }
    if (changed) await _persist();
  }

  @override
  Future<List<ExtraIncomeEntry>> includedEntriesFor(YearMonth month) async =>
      (await entriesFor(month))
          .where((entry) => entry.active && entry.includeInFinancialIncome)
          .toList(growable: false);

  @override
  Future<int> includedMinorUnitsFor(YearMonth month) async =>
      (await entriesFor(month))
          .where((e) => e.active && e.includeInFinancialIncome)
          .fold<int>(0, (sum, e) => sum + e.amountMinor);
}

final class _MemoryInvestmentRepository implements InvestmentRepository {
  final _items = <InvestmentPosition>[];
  SharedPreferences? _preferences;

  Future<void> loadFromStorage(SharedPreferences preferences) async {
    _preferences = preferences;
    final encoded = preferences.getString(_investmentsStorageKey);
    if (encoded == null) return;
    _items
      ..clear()
      ..addAll(
        (jsonDecode(encoded) as List<dynamic>).map(
          (item) => _positionFromJson(item as Map<String, dynamic>),
        ),
      );
  }

  Future<void> _persist() async => _preferences?.setString(
    _investmentsStorageKey,
    jsonEncode(_items.map(_positionToJson).toList()),
  );

  @override
  Future<List<InvestmentPosition>> listForMonth(YearMonth month) async => _items
      .where((item) => item.active && item.month.compareTo(month) <= 0)
      .toList(growable: false);
  @override
  Future<void> save(InvestmentPosition value) async {
    _items.removeWhere((e) => e.id == value.id);
    _items.add(value);
    await _persist();
  }

  @override
  Future<void> softDelete(String id, DateTime at) async => _replace(id, at);
  @override
  Future<void> restore(String id) async => _replace(id, null);
  Future<void> _replace(String id, DateTime? at) async {
    final i = _items.indexWhere((e) => e.id == id);
    if (i < 0) return;
    final e = _items[i];
    _items[i] = InvestmentPosition(
      id: e.id,
      identity: e.identity,
      principalMinor: e.principalMinor,
      quantity: e.quantity,
      monthlyReturnMinor: e.monthlyReturnMinor,
      month: e.month,
      createdAt: e.createdAt,
      updatedAt: e.updatedAt,
      source: e.source,
      deletedAt: at,
    );
    await _persist();
  }
}

const _transactionsStorageKey = 'oscar.web.transactions.v1';
const _extraIncomeStorageKey = 'oscar.web.extra-income.v1';
const _extraIncomeTemplatesStorageKey = 'oscar.web.extra-income-templates.v1';
const _investmentsStorageKey = 'oscar.web.investments.v1';
const _fundsStorageKey = 'oscar.web.emergency-funds.v1';

Map<String, Object?> _transactionToJson(FinancialTransaction item) => {
  'id': item.id,
  'title': item.title,
  'kind': item.kind.name,
  'amount': item.originalAmountMinor,
  'currency': item.currency.isoCode,
  'month': item.month.databaseKey,
  'discountType': item.discountType.name,
  'discountValue': item.discountValue,
  'recurring': item.recurring,
  'installment': item.installmentLabel,
  'deletedAt': item.deletedAt?.toIso8601String(),
};

FinancialTransaction _transactionFromJson(Map<String, dynamic> json) =>
    FinancialTransaction(
      id: json['id'] as String,
      title: json['title'] as String,
      kind: TransactionKind.values.byName(json['kind'] as String),
      originalAmountMinor: json['amount'] as int,
      currency: _currencyFromIso(json['currency'] as String),
      month: _monthFromKey(json['month'] as String),
      discountType: DiscountType.values.byName(json['discountType'] as String),
      discountValue: json['discountValue'] as int,
      recurring: json['recurring'] as bool,
      installmentLabel: json['installment'] as String?,
      deletedAt: _dateFromJson(json['deletedAt']),
    );

Map<String, Object?> _extraToJson(ExtraIncomeEntry item) => {
  'id': item.id,
  'kind': item.kind.name,
  'name': item.name,
  'description': item.description,
  'amount': item.amountMinor,
  'currency': item.currency.isoCode,
  'month': item.month.databaseKey,
  'recurring': item.recurring,
  'included': item.includeInFinancialIncome,
  'template': item.recurrenceTemplateId,
  'deletedAt': item.deletedAt?.toIso8601String(),
};

ExtraIncomeEntry _extraFromJson(Map<String, dynamic> json) => ExtraIncomeEntry(
  id: json['id'] as String,
  kind: ExtraIncomeKind.values.byName(json['kind'] as String),
  name: json['name'] as String,
  description: json['description'] as String,
  amountMinor: json['amount'] as int,
  currency: _currencyFromIso(json['currency'] as String),
  month: _monthFromKey(json['month'] as String),
  recurring: json['recurring'] as bool,
  includeInFinancialIncome: json['included'] as bool,
  recurrenceTemplateId: json['template'] as String?,
  deletedAt: _dateFromJson(json['deletedAt']),
);

ExtraIncomeRecurrenceTemplate _templateFromEntry(
  ExtraIncomeEntry entry,
  String id,
) => ExtraIncomeRecurrenceTemplate(
  id: id,
  kind: entry.kind,
  name: entry.name,
  description: entry.description,
  amountMinor: entry.amountMinor,
  currency: entry.currency,
  startMonth: entry.month,
  includeInFinancialIncome: entry.includeInFinancialIncome,
);

Map<String, Object?> _extraTemplateToJson(ExtraIncomeRecurrenceTemplate item) =>
    {
      'id': item.id,
      'kind': item.kind.name,
      'name': item.name,
      'description': item.description,
      'amount': item.amountMinor,
      'currency': item.currency.isoCode,
      'startMonth': item.startMonth.databaseKey,
      'included': item.includeInFinancialIncome,
      'active': item.active,
    };

ExtraIncomeRecurrenceTemplate _extraTemplateFromJson(
  Map<String, dynamic> json,
) => ExtraIncomeRecurrenceTemplate(
  id: json['id'] as String,
  kind: ExtraIncomeKind.values.byName(json['kind'] as String),
  name: json['name'] as String,
  description: json['description'] as String,
  amountMinor: json['amount'] as int,
  currency: _currencyFromIso(json['currency'] as String),
  startMonth: _monthFromKey(json['startMonth'] as String),
  includeInFinancialIncome: json['included'] as bool,
  active: json['active'] as bool,
);

Map<String, Object?> _positionToJson(InvestmentPosition item) => {
  'id': item.id,
  'providerId': item.identity.providerAssetId,
  'family': item.identity.family.storageValue,
  'symbol': item.identity.symbol,
  'name': item.identity.officialName,
  'exchange': item.identity.exchangeMic,
  'country': item.identity.countryCode,
  'currency': item.currency.isoCode,
  'isin': item.identity.isin,
  'principal': item.principalMinor,
  'return': item.monthlyReturnMinor,
  'month': item.month.databaseKey,
  'source': item.source,
  'quantity': item.quantity,
  'createdAt': item.createdAt.toIso8601String(),
  'updatedAt': item.updatedAt.toIso8601String(),
  'deletedAt': item.deletedAt?.toIso8601String(),
};

InvestmentPosition _positionFromJson(Map<String, dynamic> json) =>
    InvestmentPosition(
      id: json['id'] as String,
      identity: InstrumentIdentity(
        providerAssetId: json['providerId'] as String,
        family: AssetFamily.fromStorage(json['family'] as String),
        symbol: json['symbol'] as String,
        officialName: json['name'] as String,
        exchangeMic: json['exchange'] as String,
        countryCode: json['country'] as String,
        currency: _currencyFromIso(json['currency'] as String),
        isin: json['isin'] as String?,
      ),
      principalMinor: json['principal'] as int,
      monthlyReturnMinor: json['return'] as int,
      month: _monthFromKey(json['month'] as String),
      source: json['source'] as String,
      quantity: json['quantity'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      deletedAt: _dateFromJson(json['deletedAt']),
    );

CurrencyCode _currencyFromIso(String iso) =>
    CurrencyCode.values.firstWhere((currency) => currency.isoCode == iso);

YearMonth _monthFromKey(String key) {
  final parts = key.split('-');
  return YearMonth(int.parse(parts[0]), int.parse(parts[1]));
}

DateTime? _dateFromJson(Object? value) =>
    value == null ? null : DateTime.parse(value as String);

final class _MemoryAgendaRepository implements AgendaRepository {
  final _items = <AgendaEvent>[];
  @override
  Future<List<AgendaEvent>> eventsForMonth(YearMonth month) async => _items
      .where((e) => e.start.year == month.year && e.start.month == month.month)
      .toList();
  @override
  Future<void> save(AgendaEvent value) async {
    _items.removeWhere((e) => e.id == value.id);
    _items.add(value);
  }

  @override
  Future<void> softDelete(String id, DateTime at) async => _replace(id, at);
  @override
  Future<void> restore(String id) async => _replace(id, null);
  void _replace(String id, DateTime? at) {
    final i = _items.indexWhere((e) => e.id == id);
    if (i < 0) return;
    final e = _items[i];
    _items[i] = AgendaEvent(
      id: e.id,
      title: e.title,
      notes: e.notes,
      category: e.category,
      start: e.start,
      end: e.end,
      timezoneId: e.timezoneId,
      recurrence: e.recurrence,
      reminderPreset: e.reminderPreset,
      serviceValueMinor: e.serviceValueMinor,
      serviceCurrency: e.serviceCurrency,
      serviceCompleted: e.serviceCompleted,
      createdAt: e.createdAt,
      updatedAt: e.updatedAt,
      deletedAt: at,
    );
  }
}
