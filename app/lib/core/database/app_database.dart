import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

final class AppDatabase {
  AppDatabase._(this.raw);

  static const schemaVersion = 4;
  final Database raw;

  static Future<AppDatabase> open() async {
    final root = await getDatabasesPath();
    final database = await openDatabase(
      p.join(root, 'oscar_financas.db'),
      version: schemaVersion,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await _createFoundation(db, version);
        await _createInvestments(db);
        await _createAgenda(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createInvestments(db);
        if (oldVersion < 3) await _createAgenda(db);
        if (oldVersion < 4) {
          await db.execute(
            'ALTER TABLE investment_positions ADD COLUMN quantity TEXT',
          );
        }
        await db.update('schema_meta', {
          'schema_version': newVersion,
          'migrated_at': DateTime.now().toUtc().toIso8601String(),
        });
      },
    );
    return AppDatabase._(database);
  }

  static Future<void> _createFoundation(Database db, int version) async {
    await db.execute('''CREATE TABLE schema_meta (
      schema_version INTEGER NOT NULL,
      migrated_at TEXT NOT NULL
    )''');
    await db.insert('schema_meta', {
      'schema_version': version,
      'migrated_at': DateTime.now().toUtc().toIso8601String(),
    });
    await db.execute('''CREATE TABLE app_settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE transactions (
      id TEXT PRIMARY KEY,
      kind TEXT NOT NULL,
      title TEXT NOT NULL,
      original_amount_minor INTEGER NOT NULL CHECK(original_amount_minor >= 0),
      currency_code TEXT NOT NULL,
      discount_type TEXT NOT NULL,
      discount_value INTEGER NOT NULL DEFAULT 0,
      year_month TEXT NOT NULL,
      recurring INTEGER NOT NULL DEFAULT 0,
      installment_label TEXT,
      deleted_at TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''');
    await db.execute(
      'CREATE INDEX idx_transactions_month ON transactions(year_month, deleted_at)',
    );
    await db.execute('''CREATE TABLE monthly_summaries (
      year_month TEXT NOT NULL,
      currency_code TEXT NOT NULL,
      income_minor INTEGER NOT NULL,
      expense_minor INTEGER NOT NULL,
      extra_income_minor INTEGER NOT NULL,
      net_minor INTEGER NOT NULL,
      deficit_minor INTEGER NOT NULL,
      source_revision INTEGER NOT NULL,
      closed_at TEXT,
      PRIMARY KEY(year_month, currency_code)
    )''');
    await db.execute('''CREATE TABLE emergency_fund_settings (
      currency_code TEXT PRIMARY KEY,
      current_balance_minor INTEGER NOT NULL,
      target_months INTEGER NOT NULL,
      updated_at TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE extra_income_entries (
      id TEXT PRIMARY KEY,
      kind TEXT NOT NULL,
      name TEXT NOT NULL,
      description TEXT NOT NULL,
      amount_minor INTEGER NOT NULL CHECK(amount_minor >= 0),
      currency_code TEXT NOT NULL,
      year_month TEXT NOT NULL,
      recurring INTEGER NOT NULL DEFAULT 0,
      include_in_financial_income INTEGER NOT NULL DEFAULT 0,
      recurrence_template_id TEXT,
      deleted_at TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      UNIQUE(recurrence_template_id, year_month)
    )''');
    await db.execute(
      'CREATE INDEX idx_extra_income_month ON extra_income_entries(year_month, deleted_at)',
    );
    await db.execute('''CREATE TABLE extra_income_templates (
      id TEXT PRIMARY KEY,
      kind TEXT NOT NULL,
      name TEXT NOT NULL,
      description TEXT NOT NULL,
      amount_minor INTEGER NOT NULL,
      currency_code TEXT NOT NULL,
      start_month TEXT NOT NULL,
      include_in_financial_income INTEGER NOT NULL DEFAULT 0,
      active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''');
  }

  static Future<void> _createInvestments(Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS investment_positions (
      id TEXT PRIMARY KEY,
      asset_family TEXT NOT NULL,
      provider_asset_id TEXT,
      symbol TEXT NOT NULL,
      official_name TEXT NOT NULL,
      exchange_mic TEXT NOT NULL,
      country_code TEXT NOT NULL,
      isin TEXT,
      principal_minor INTEGER NOT NULL CHECK(principal_minor >= 0),
      monthly_return_minor INTEGER NOT NULL,
      currency_code TEXT NOT NULL,
      year_month TEXT NOT NULL,
      source TEXT NOT NULL,
      quantity TEXT,
      deleted_at TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_positions_month ON investment_positions(year_month, deleted_at)',
    );
    await db.execute('''CREATE TABLE IF NOT EXISTS investment_events (
      id TEXT PRIMARY KEY,
      position_id TEXT NOT NULL REFERENCES investment_positions(id),
      kind TEXT NOT NULL,
      amount_minor INTEGER NOT NULL,
      currency_code TEXT NOT NULL,
      occurred_at TEXT NOT NULL,
      created_at TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS simulation_scenarios (
      id TEXT PRIMARY KEY,
      initial_minor INTEGER NOT NULL,
      contribution_minor INTEGER NOT NULL,
      rate_scaled INTEGER NOT NULL,
      rate_periodicity TEXT NOT NULL,
      months INTEGER NOT NULL,
      currency_code TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS market_rate_snapshots (
      provider TEXT NOT NULL,
      kind TEXT NOT NULL,
      base_currency TEXT NOT NULL,
      quote_currency TEXT NOT NULL,
      value_scaled INTEGER NOT NULL,
      observed_at TEXT NOT NULL,
      fetched_at TEXT NOT NULL,
      expires_at TEXT NOT NULL,
      status TEXT NOT NULL,
      PRIMARY KEY(provider, kind, base_currency, quote_currency)
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS inflation_snapshots (
      provider TEXT NOT NULL,
      currency_code TEXT NOT NULL,
      index_kind TEXT NOT NULL,
      reference_month TEXT NOT NULL,
      monthly_rate_scaled INTEGER NOT NULL,
      observed_at TEXT NOT NULL,
      fetched_at TEXT NOT NULL,
      source_url TEXT NOT NULL,
      status TEXT NOT NULL,
      PRIMARY KEY(currency_code, reference_month)
    )''');
  }

  static Future<void> _createAgenda(Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS agenda_events (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      notes TEXT NOT NULL,
      category TEXT NOT NULL,
      local_start TEXT NOT NULL,
      local_end TEXT,
      timezone_id TEXT NOT NULL,
      recurrence TEXT NOT NULL,
      reminder_preset TEXT NOT NULL,
      service_value_minor INTEGER,
      service_currency TEXT,
      service_completed INTEGER NOT NULL DEFAULT 0,
      deleted_at TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_agenda_start ON agenda_events(local_start, deleted_at)',
    );
    await db.execute('''CREATE TABLE IF NOT EXISTS scheduled_reminders (
      notification_id INTEGER PRIMARY KEY,
      event_id TEXT NOT NULL REFERENCES agenda_events(id),
      scheduled_at_utc TEXT NOT NULL,
      status TEXT NOT NULL,
      UNIQUE(event_id, scheduled_at_utc)
    )''');
  }

  Future<void> close() => raw.close();
}

final class LazyAppDatabase {
  Future<AppDatabase>? _opening;
  Future<AppDatabase> get instance => _opening ??= AppDatabase.open();
}
