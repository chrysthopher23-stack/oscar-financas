import '../../core/money/money.dart';
import '../../core/time/year_month.dart';
import '../../core/database/app_database.dart';
import '../../features/screen_1_financial/data/sqlite_financial_repository.dart';
import '../../features/screen_1_financial/domain/financial_repository.dart';
import '../../features/screen_1_financial/domain/financial_transaction.dart';
import '../../features/screen_2_extra_income/application/extra_income_contribution_port.dart';
import '../../features/screen_2_extra_income/data/sqlite_extra_income_repository.dart';
import '../../features/screen_2_extra_income/domain/extra_income_repository.dart';
import '../../features/screen_3_investments/data/sqlite_investment_repository.dart';
import '../../features/screen_3_investments/domain/investment_repository.dart';
import '../../features/screen_6_agenda/application/notification_contracts.dart';
import '../../features/screen_6_agenda/data/flutter_local_notification_scheduler.dart';
import '../../features/screen_6_agenda/data/sqlite_agenda_repository.dart';
import '../../features/screen_6_agenda/domain/agenda_repository.dart';
import '../../features/screen_4_objectives/data/shared_preferences_objective_repository.dart';
import '../../features/screen_4_objectives/domain/objective_repository.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_services.dart';
import 'initial_demo_data.dart';

AppServices createAppServices() => _NativeAppServices();

final class _NativeAppServices implements AppServices {
  _NativeAppServices() {
    _database = LazyAppDatabase();
    financialRepository = SqliteFinancialRepository(_database);
    final extraIncome = SqliteExtraIncomeRepository(_database);
    extraIncomeRepository = extraIncome;
    extraIncomeContributionPort = extraIncome;
    investmentRepository = SqliteInvestmentRepository(_database);
    objectiveRepository = const SharedPreferencesObjectiveRepository();
    agendaRepository = SqliteAgendaRepository(_database);
    notificationScheduler = FlutterLocalNotificationScheduler();
  }

  late final LazyAppDatabase _database;

  @override
  Future<void> ensureInitialDemoData({
    required YearMonth month,
    required CurrencyCode currency,
  }) async {
    if ((await SharedPreferences.getInstance()).getBool(
          'history.personal-start.v1',
        ) ==
        true) {
      return;
    }
    final database = (await _database.instance).raw;

    const legacyReserveCleanup = 'migration.remove-legacy-emergency-fund.v1';
    final cleanupDone = await database.query(
      'app_settings',
      columns: ['key'],
      where: 'key = ?',
      whereArgs: [legacyReserveCleanup],
      limit: 1,
    );
    if (cleanupDone.isEmpty) {
      final legacyTitles = FinancialTransaction.legacyEmergencyFundTitles
          .toList(growable: false);
      await database.delete(
        'transactions',
        where:
            "id LIKE 'emergency-fund:%' OR LOWER(TRIM(title)) IN (${List.filled(legacyTitles.length, '?').join(', ')})",
        whereArgs: legacyTitles,
      );
      await database.delete('emergency_fund_settings');
      await database.rawInsert(
        'INSERT OR REPLACE INTO app_settings(key, value, updated_at) VALUES(?, ?, ?)',
        [
          legacyReserveCleanup,
          'complete',
          DateTime.now().toUtc().toIso8601String(),
        ],
      );
    }

    Future<bool> shouldSeed(String marker, String table) async {
      final marked = await database.query(
        'app_settings',
        columns: ['key'],
        where: 'key = ?',
        whereArgs: [marker],
        limit: 1,
      );
      if (marked.isNotEmpty) return false;
      final count = await database.rawQuery(
        'SELECT COUNT(*) AS total FROM $table WHERE deleted_at IS NULL',
      );
      return (count.single['total'] as num).toInt() == 0;
    }

    Future<void> mark(String marker) => database.rawInsert(
      'INSERT OR REPLACE INTO app_settings(key, value, updated_at) VALUES(?, ?, ?)',
      [marker, 'complete', DateTime.now().toUtc().toIso8601String()],
    );

    const cleanDemoMarker = 'demo.seed.clean.v4';
    final cleanMarker = await database.query(
      'app_settings',
      columns: ['key'],
      where: 'key = ?',
      whereArgs: [cleanDemoMarker],
      limit: 1,
    );
    if (cleanMarker.isEmpty) {
      await database.delete(
        'transactions',
        where: 'id LIKE ?',
        whereArgs: ['demo:%'],
      );
      await database.delete(
        'extra_income_entries',
        where: 'id LIKE ?',
        whereArgs: ['demo:%'],
      );
      await database.delete(
        'investment_positions',
        where: 'id LIKE ?',
        whereArgs: ['demo:%'],
      );
      await mark(cleanDemoMarker);
    }

    const financialMarker = 'demo.seed.financial.v4';
    if (await shouldSeed(financialMarker, 'transactions')) {
      await seedFinancialDemo(
        repository: financialRepository,
        month: month,
        currency: CurrencyCode.usd,
      );
    }
    await mark(financialMarker);

    const extraMarker = 'demo.seed.extra.v4';
    if (await shouldSeed(extraMarker, 'extra_income_entries')) {
      await seedExtraIncomeDemo(
        repository: extraIncomeRepository,
        month: month,
        currency: CurrencyCode.usd,
      );
    }
    await mark(extraMarker);

    const investmentMarker = 'demo.seed.investments.v4';
    if (await shouldSeed(investmentMarker, 'investment_positions')) {
      await seedInvestmentDemo(repository: investmentRepository, month: month);
    }
    await mark(investmentMarker);

    const objectivesDemoMarker = 'demo.seed.objectives.emergency-six-month.v1';
    final objectivesDemoMarked = await database.query(
      'app_settings',
      columns: ['key'],
      where: 'key = ?',
      whereArgs: [objectivesDemoMarker],
      limit: 1,
    );
    if (objectivesDemoMarked.isEmpty) {
      await seedEmergencyObjectiveDemo(
        objectives: objectiveRepository,
        financial: financialRepository,
        currentMonth: month,
      );
      await mark(objectivesDemoMarker);
    }

    const first100kDemoMarker = 'demo.seed.objectives.first-100k.v1';
    final first100kDemoMarked = await database.query(
      'app_settings',
      columns: ['key'],
      where: 'key = ?',
      whereArgs: [first100kDemoMarker],
      limit: 1,
    );
    if (first100kDemoMarked.isEmpty) {
      await seedFirst100kObjectiveDemo(
        objectives: objectiveRepository,
        financial: financialRepository,
        currentMonth: month,
      );
      await mark(first100kDemoMarker);
    }

    const ownHomeDemoMarker = 'demo.seed.objectives.own-home-eight-month.v1';
    final ownHomeDemoMarked = await database.query(
      'app_settings',
      columns: ['key'],
      where: 'key = ?',
      whereArgs: [ownHomeDemoMarker],
      limit: 1,
    );
    if (ownHomeDemoMarked.isEmpty) {
      await seedOwnHomeObjectiveDemo(
        objectives: objectiveRepository,
        financial: financialRepository,
        currentMonth: month,
      );
      await mark(ownHomeDemoMarker);
    }

    const newCarDemoMarker = 'demo.seed.objectives.new-car-2031.v1';
    final newCarDemoMarked = await database.query(
      'app_settings',
      columns: ['key'],
      where: 'key = ?',
      whereArgs: [newCarDemoMarker],
      limit: 1,
    );
    if (newCarDemoMarked.isEmpty) {
      await seedNewCar2031ObjectiveDemo(
        objectives: objectiveRepository,
        financial: financialRepository,
        currentMonth: month,
      );
      await mark(newCarDemoMarker);
    }

    const timeframeMarker = 'migration.demo-objective-timeframes.v1';
    final timeframeMarked = await database.query(
      'app_settings',
      columns: ['key'],
      where: 'key = ?',
      whereArgs: [timeframeMarker],
      limit: 1,
    );
    if (timeframeMarked.isEmpty) {
      await migrateDemoObjectiveTimeframes(
        objectives: objectiveRepository,
        financial: financialRepository,
        currentMonth: month,
      );
      await mark(timeframeMarker);
    }

    const objectiveRateMarker = 'migration.emergency-objective-rate-4.v1';
    final objectiveRateMarked = await database.query(
      'app_settings',
      columns: ['key'],
      where: 'key = ?',
      whereArgs: [objectiveRateMarker],
      limit: 1,
    );
    if (objectiveRateMarked.isEmpty) {
      await migrateEmergencyObjectiveDemoRate(objectiveRepository);
      await mark(objectiveRateMarker);
    }

    const ownHomeRateMarker = 'migration.own-home-objective-rate-10.v1';
    final ownHomeRateMarked = await database.query(
      'app_settings',
      columns: ['key'],
      where: 'key = ?',
      whereArgs: [ownHomeRateMarker],
      limit: 1,
    );
    if (ownHomeRateMarked.isEmpty) {
      await migrateOwnHomeObjectiveDemoRate(objectiveRepository);
      await mark(ownHomeRateMarker);
    }

    const objectiveMetadataMarker = 'migration.objectives.remove-investment.v1';
    final objectiveMetadataMarked = await database.query(
      'app_settings',
      columns: ['key'],
      where: 'key = ?',
      whereArgs: [objectiveMetadataMarker],
      limit: 1,
    );
    if (objectiveMetadataMarked.isEmpty) {
      await removeObjectiveInvestmentMetadata(objectiveRepository);
      await mark(objectiveMetadataMarker);
    }

    const realAssetsMarker = 'demo.seed.investments.real-assets.v2';
    final realAssetsMarked = await database.query(
      'app_settings',
      columns: ['key'],
      where: 'key = ?',
      whereArgs: [realAssetsMarker],
      limit: 1,
    );
    if (realAssetsMarked.isEmpty) {
      final migratedAt = DateTime.now().toUtc().toIso8601String();
      final replacements = <Map<String, Object>>[
        {
          'legacy_symbol': 'SELIC',
          'asset_family': 'equity',
          'provider_asset_id': 'br-petr4',
          'symbol': 'PETR4',
          'official_name': 'Petróleo Brasileiro S.A. — Petrobras',
          'exchange_mic': 'BVMF',
          'country_code': 'BR',
          'currency_code': 'BRL',
        },
        {
          'legacy_symbol': 'CDB',
          'asset_family': 'government_bond',
          'provider_asset_id': 'us-bnd',
          'symbol': 'BND',
          'official_name': 'Vanguard Total Bond Market ETF',
          'exchange_mic': 'ARCX',
          'country_code': 'US',
          'currency_code': 'USD',
        },
        {
          'legacy_symbol': 'FII11',
          'asset_family': 'real_estate_vehicle',
          'provider_asset_id': 'fr-urw',
          'symbol': 'URW',
          'official_name': 'Unibail-Rodamco-Westfield',
          'exchange_mic': 'XPAR',
          'country_code': 'FR',
          'currency_code': 'EUR',
        },
        {
          'legacy_symbol': 'OSCR3',
          'asset_family': 'equity',
          'provider_asset_id': 'in-reliance',
          'symbol': 'RELIANCE',
          'official_name': 'Reliance Industries Limited',
          'exchange_mic': 'XBOM',
          'country_code': 'IN',
          'currency_code': 'INR',
        },
      ];
      for (final replacement in replacements) {
        final legacySymbol = replacement.remove('legacy_symbol');
        await database.update(
          'investment_positions',
          {...replacement, 'updated_at': migratedAt},
          where: 'source = ? AND symbol = ?',
          whereArgs: ['demo', legacySymbol],
        );
      }
      await mark(realAssetsMarker);
    }

    const realisticCopyMarker = 'demo.copy.realistic.v3';
    final realisticCopyMarked = await database.query(
      'app_settings',
      columns: ['key'],
      where: 'key = ?',
      whereArgs: [realisticCopyMarker],
      limit: 1,
    );
    if (realisticCopyMarked.isEmpty) {
      final updatedAt = DateTime.now().toUtc().toIso8601String();
      const financialTitles = <String, String>{
        'Salário simulado': 'Salário',
        'Aluguel simulado': 'Aluguel',
        'Luz simulada': 'Luz',
        'Água simulada': 'Água',
        'Internet simulada': 'Internet',
        'Mercado simulado': 'Mercado',
        'Faculdade simulada': 'Faculdade',
        'Carro simulado': 'Carro',
        'TV simulada': 'TV',
      };
      for (final entry in financialTitles.entries) {
        await database.update(
          'transactions',
          {'title': entry.value, 'updated_at': updatedAt},
          where: 'id LIKE ? AND title = ?',
          whereArgs: ['%demo:financial:%', entry.key],
        );
      }
      await database.update(
        'transactions',
        {'title': 'Reserva de emergência', 'updated_at': updatedAt},
        where: 'id LIKE ? AND title = ?',
        whereArgs: ['emergency-fund:%', 'Reserva de emergência simulada'],
      );
      const extraNames = <String, String>{
        'Freelance de design simulado': 'Freelance de design',
        'Manutenção de computador simulada': 'Manutenção de computador',
        'Venda de bicicleta simulada': 'Venda de bicicleta',
        'Venda de doces simulada': 'Venda de doces',
      };
      const extraDescriptions = <String, String>{
        'Projeto pontual simulado': 'Projeto pontual',
        'Serviço técnico simulado': 'Serviço técnico',
        'Venda ocasional simulada': 'Venda ocasional',
        'Renda complementar simulada': 'Renda complementar',
      };
      for (final entry in extraNames.entries) {
        await database.update(
          'extra_income_entries',
          {'name': entry.value, 'updated_at': updatedAt},
          where: 'id LIKE ? AND name = ?',
          whereArgs: ['demo:extra:%', entry.key],
        );
      }
      for (final entry in extraDescriptions.entries) {
        await database.update(
          'extra_income_entries',
          {'description': entry.value, 'updated_at': updatedAt},
          where: 'id LIKE ? AND description = ?',
          whereArgs: ['demo:extra:%', entry.key],
        );
      }
      await mark(realisticCopyMarker);
    }
  }

  @override
  Future<void> resetPersonalHistory() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('history.personal-start.v1', true);
    final database = (await _database.instance).raw;
    final events = await database.query('agenda_events', columns: ['id']);
    for (final event in events) {
      await notificationScheduler.cancelForEvent(event['id'] as String);
    }
    await database.transaction((transaction) async {
      for (final table in const [
        'scheduled_reminders',
        'agenda_events',
        'investment_events',
        'investment_positions',
        'simulation_scenarios',
        'extra_income_entries',
        'extra_income_templates',
        'monthly_summaries',
        'emergency_fund_settings',
        'transactions',
      ]) {
        await transaction.delete(table);
      }
    });
    await (objectiveRepository as SharedPreferencesObjectiveRepository)
        .clearAll();
  }

  @override
  Future<YearMonth?> earliestRecordedMonth() async {
    final database = (await _database.instance).raw;
    final rows = await database.rawQuery('''
      SELECT MIN(month) AS first_month FROM (
        SELECT year_month AS month FROM transactions WHERE deleted_at IS NULL
        UNION ALL SELECT year_month FROM extra_income_entries WHERE deleted_at IS NULL
        UNION ALL SELECT start_month FROM extra_income_templates WHERE active = 1
        UNION ALL SELECT year_month FROM investment_positions WHERE deleted_at IS NULL
        UNION ALL SELECT SUBSTR(local_start, 1, 7) FROM agenda_events WHERE deleted_at IS NULL
      )
    ''');
    final key = rows.single['first_month'] as String?;
    YearMonth? earliest = key == null
        ? null
        : YearMonth(
            int.parse(key.substring(0, 4)),
            int.parse(key.substring(5, 7)),
          );
    for (final goal in await objectiveRepository.loadAll()) {
      if (earliest == null || goal.startMonth.compareTo(earliest) < 0) {
        earliest = goal.startMonth;
      }
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
  late final LocalNotificationScheduler notificationScheduler;
}
