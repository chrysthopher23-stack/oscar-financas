import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/money/money.dart';
import '../../../core/time/year_month.dart';
import '../domain/asset_family.dart';
import '../domain/instrument_identity.dart';
import '../domain/investment_position.dart';
import '../domain/investment_repository.dart';

final class SqliteInvestmentRepository implements InvestmentRepository {
  const SqliteInvestmentRepository(this._database);
  final LazyAppDatabase _database;

  @override
  Future<List<InvestmentPosition>> listForMonth(YearMonth month) async {
    final database = await _database.instance;
    final rows = await database.raw.query(
      'investment_positions',
      where: 'year_month <= ? AND deleted_at IS NULL',
      whereArgs: [month.databaseKey],
      orderBy: 'official_name COLLATE NOCASE',
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Future<void> save(InvestmentPosition position) async {
    final database = await _database.instance;
    await database.raw.insert(
      'investment_positions',
      _toRow(position),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> softDelete(String id, DateTime deletedAt) async {
    final database = await _database.instance;
    await database.raw.update(
      'investment_positions',
      {'deleted_at': deletedAt.toUtc().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> restore(String id) async {
    final database = await _database.instance;
    await database.raw.update(
      'investment_positions',
      {'deleted_at': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Map<String, Object?> _toRow(InvestmentPosition value) => {
    'id': value.id,
    'asset_family': value.identity.family.storageValue,
    'provider_asset_id': value.identity.providerAssetId,
    'symbol': value.identity.symbol,
    'official_name': value.identity.officialName,
    'exchange_mic': value.identity.exchangeMic,
    'country_code': value.identity.countryCode,
    'isin': value.identity.isin,
    'principal_minor': value.principalMinor,
    'monthly_return_minor': value.monthlyReturnMinor,
    'currency_code': value.currency.isoCode,
    'year_month': value.month.databaseKey,
    'source': value.source,
    'quantity': value.quantity,
    'deleted_at': value.deletedAt?.toUtc().toIso8601String(),
    'created_at': value.createdAt.toUtc().toIso8601String(),
    'updated_at': value.updatedAt.toUtc().toIso8601String(),
  };

  static InvestmentPosition _fromRow(Map<String, Object?> row) {
    final currency = CurrencyCode.values.firstWhere(
      (item) => item.isoCode == row['currency_code'],
    );
    final monthParts = (row['year_month'] as String).split('-');
    return InvestmentPosition(
      id: row['id'] as String,
      identity: InstrumentIdentity(
        providerAssetId: (row['provider_asset_id'] as String?) ?? '',
        family: AssetFamily.fromStorage(row['asset_family'] as String),
        symbol: row['symbol'] as String,
        officialName: row['official_name'] as String,
        exchangeMic: row['exchange_mic'] as String,
        countryCode: row['country_code'] as String,
        currency: currency,
        isin: row['isin'] as String?,
      ),
      principalMinor: row['principal_minor'] as int,
      monthlyReturnMinor: row['monthly_return_minor'] as int,
      month: YearMonth(int.parse(monthParts[0]), int.parse(monthParts[1])),
      source: row['source'] as String,
      quantity: row['quantity'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      deletedAt: row['deleted_at'] == null
          ? null
          : DateTime.parse(row['deleted_at'] as String),
    );
  }
}
