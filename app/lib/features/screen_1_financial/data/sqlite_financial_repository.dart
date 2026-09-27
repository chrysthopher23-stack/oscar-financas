import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/money/money.dart';
import '../../../core/time/year_month.dart';
import '../../../shared/formatting/installment_formatter.dart';
import '../domain/financial_repository.dart';
import '../domain/financial_transaction.dart';
import '../domain/monthly_summary.dart';

final class SqliteFinancialRepository implements FinancialRepository {
  SqliteFinancialRepository(this._provider);

  final LazyAppDatabase _provider;

  @override
  Future<List<FinancialTransaction>> transactionsFor(YearMonth month) async {
    final db = (await _provider.instance).raw;
    final rows = await db.query(
      'transactions',
      where: 'year_month = ?',
      whereArgs: [month.databaseKey],
      orderBy: 'created_at ASC, id ASC',
    );
    return rows.map(_transactionFromRow).toList(growable: false);
  }

  @override
  Future<List<FinancialTransaction>> emergencyFundContributions(
    CurrencyCode currency,
  ) async {
    final db = (await _provider.instance).raw;
    final titles = FinancialTransaction.legacyEmergencyFundTitles.toList();
    final rows = await db.query(
      'transactions',
      where: '''kind = 'expense' AND deleted_at IS NULL
        AND currency_code = ?
        AND (id LIKE 'emergency-fund:%'
          OR LOWER(TRIM(title)) IN (${List.filled(titles.length, '?').join(', ')}))''',
      whereArgs: [currency.isoCode, ...titles],
      orderBy: 'year_month ASC, created_at ASC, id ASC',
    );
    return rows.map(_transactionFromRow).toList(growable: false);
  }

  @override
  Future<void> saveTransaction(FinancialTransaction transaction) async {
    final db = (await _provider.instance).raw;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.insert('transactions', {
      'id': transaction.id,
      'kind': transaction.kind.name,
      'title': transaction.title,
      'original_amount_minor': transaction.originalAmountMinor,
      'currency_code': transaction.currency.isoCode,
      'discount_type': transaction.discountType.name,
      'discount_value': transaction.discountValue,
      'year_month': transaction.month.databaseKey,
      'recurring': transaction.recurring ? 1 : 0,
      'installment_label': transaction.installmentLabel,
      'deleted_at': transaction.deletedAt?.toUtc().toIso8601String(),
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<FinancialTransaction>> materializeRecurringTransactions(
    YearMonth month,
    CurrencyCode currency,
  ) async {
    final db = (await _provider.instance).raw;
    final currentRows = await db.query(
      'transactions',
      where: 'year_month = ? AND currency_code = ?',
      whereArgs: [month.databaseKey, currency.isoCode],
    );
    final currentKeys = currentRows
        .map((row) => '${row['kind']}|${row['title']}')
        .toSet();
    final priorRows = await db.query(
      'transactions',
      where: 'year_month < ? AND currency_code = ?',
      whereArgs: [month.databaseKey, currency.isoCode],
      orderBy: 'year_month DESC, updated_at DESC, id DESC',
    );
    final latestByKey = <String, Map<String, Object?>>{};
    for (final row in priorRows) {
      final key = '${row['kind']}|${row['title']}';
      latestByKey.putIfAbsent(key, () => row);
    }
    final created = <FinancialTransaction>[];
    for (final entry in latestByKey.entries) {
      final row = entry.value;
      final source = _transactionFromRow(row);
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
          row['deleted_at'] != null ||
          (!source.recurring && !pendingInstallment)) {
        continue;
      }
      final occurrence = FinancialTransaction(
        id: source.id.contains('emergency-fund:')
            ? 'emergency-fund:${currency.isoCode}:${month.databaseKey}'
            : pendingInstallment
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
  Future<void> softDelete(String id, DateTime deletedAt) async {
    final db = (await _provider.instance).raw;
    await db.update(
      'transactions',
      {
        'deleted_at': deletedAt.toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> restore(String id) async {
    final db = (await _provider.instance).raw;
    await db.update(
      'transactions',
      {
        'deleted_at': null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<List<int>> completedExpenseTotalsBefore(
    YearMonth month,
    CurrencyCode currency, {
    int limit = 3,
  }) async {
    final db = (await _provider.instance).raw;
    final rows = await db.rawQuery(
      '''SELECT year_month, SUM(
        CASE discount_type
          WHEN 'fixed' THEN MAX(original_amount_minor - discount_value, 0)
          WHEN 'percentage' THEN MAX(original_amount_minor - ((original_amount_minor * discount_value + 5000) / 10000), 0)
          ELSE original_amount_minor
        END
      ) AS total
      FROM transactions
      WHERE kind = 'expense' AND deleted_at IS NULL
        AND id NOT LIKE 'emergency-fund:%'
        AND LOWER(TRIM(title)) NOT IN (${FinancialTransaction.legacyEmergencyFundTitles.map((_) => '?').join(', ')})
        AND currency_code = ? AND year_month < ?
      GROUP BY year_month
      ORDER BY year_month DESC
      LIMIT ?''',
      [
        ...FinancialTransaction.legacyEmergencyFundTitles,
        currency.isoCode,
        month.databaseKey,
        limit,
      ],
    );
    return rows.map((row) => (row['total'] as num?)?.round() ?? 0).toList();
  }

  @override
  Future<({int balanceMinor, int targetMonths})> emergencyFund(
    CurrencyCode currency,
  ) async {
    final db = (await _provider.instance).raw;
    final rows = await db.query(
      'emergency_fund_settings',
      where: 'currency_code = ?',
      whereArgs: [currency.isoCode],
      limit: 1,
    );
    if (rows.isEmpty) return (balanceMinor: 0, targetMonths: 3);
    return (
      balanceMinor: rows.first['current_balance_minor'] as int,
      targetMonths: rows.first['target_months'] as int,
    );
  }

  @override
  Future<void> saveEmergencyFund({
    required CurrencyCode currency,
    required int balanceMinor,
    required int targetMonths,
  }) async {
    final db = (await _provider.instance).raw;
    await db.insert('emergency_fund_settings', {
      'currency_code': currency.isoCode,
      'current_balance_minor': balanceMinor,
      'target_months': targetMonths,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> saveSummary(MonthlySummary summary) async {
    final db = (await _provider.instance).raw;
    await db.transaction((transaction) async {
      await transaction.insert('monthly_summaries', {
        'year_month': summary.month.databaseKey,
        'currency_code': summary.currency.isoCode,
        'income_minor': summary.incomeMinor,
        'expense_minor': summary.expenseMinor,
        'extra_income_minor': summary.extraIncomeMinor,
        'net_minor': summary.netMinor,
        'deficit_minor': summary.deficitMinor,
        'source_revision': summary.sourceRevision,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  FinancialTransaction _transactionFromRow(Map<String, Object?> row) {
    final parts = (row['year_month'] as String).split('-');
    return FinancialTransaction(
      id: row['id'] as String,
      title: row['title'] as String,
      kind: TransactionKind.values.byName(row['kind'] as String),
      originalAmountMinor: row['original_amount_minor'] as int,
      currency: CurrencyCode.values.byName(
        (row['currency_code'] as String).toLowerCase(),
      ),
      month: YearMonth(int.parse(parts[0]), int.parse(parts[1])),
      discountType: DiscountType.values.byName(row['discount_type'] as String),
      discountValue: row['discount_value'] as int,
      recurring: (row['recurring'] as int) == 1,
      installmentLabel: row['installment_label'] as String?,
      deletedAt: row['deleted_at'] == null
          ? null
          : DateTime.parse(row['deleted_at'] as String),
    );
  }
}
