import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/money/money.dart';
import '../../../core/time/year_month.dart';
import '../application/extra_income_contribution_port.dart';
import '../domain/extra_income_entry.dart';
import '../domain/extra_income_repository.dart';

final class SqliteExtraIncomeRepository
    implements ExtraIncomeRepository, ExtraIncomeContributionPort {
  SqliteExtraIncomeRepository(this._provider);

  final LazyAppDatabase _provider;

  @override
  Future<List<ExtraIncomeEntry>> entriesFor(YearMonth month) async {
    await materializeRecurringEntries(month);
    final db = (await _provider.instance).raw;
    final rows = await db.query(
      'extra_income_entries',
      where: 'year_month = ?',
      whereArgs: [month.databaseKey],
      orderBy: 'created_at ASC, id ASC',
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Future<List<ExtraIncomeEntry>> includedEntriesFor(YearMonth month) async =>
      (await entriesFor(month))
          .where((entry) => entry.active && entry.includeInFinancialIncome)
          .toList(growable: false);

  @override
  Future<int> includedMinorUnitsFor(YearMonth month) async {
    await materializeRecurringEntries(month);
    final db = (await _provider.instance).raw;
    final rows = await db.rawQuery(
      '''SELECT COALESCE(SUM(amount_minor), 0) AS total
         FROM extra_income_entries
         WHERE year_month = ? AND include_in_financial_income = 1
           AND deleted_at IS NULL''',
      [month.databaseKey],
    );
    return (rows.single['total'] as num).toInt();
  }

  @override
  Future<void> saveEntry(ExtraIncomeEntry entry) async {
    final db = (await _provider.instance).raw;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((transaction) async {
      String? templateId = entry.recurrenceTemplateId;
      if (entry.recurring && templateId == null) {
        templateId = 'template:${entry.id}';
      }
      if (templateId != null) {
        final templateRows = await transaction.query(
          'extra_income_templates',
          columns: ['start_month'],
          where: 'id = ?',
          whereArgs: [templateId],
          limit: 1,
        );
        final templateValues = {
          'id': templateId,
          'kind': entry.kind.name,
          'name': entry.name,
          'description': entry.description,
          'amount_minor': entry.amountMinor,
          'currency_code': entry.currency.isoCode,
          'start_month': templateRows.isEmpty
              ? entry.month.databaseKey
              : templateRows.single['start_month'],
          'include_in_financial_income': entry.includeInFinancialIncome ? 1 : 0,
          'active': entry.recurring ? 1 : 0,
          'created_at': now,
          'updated_at': now,
        };
        if (templateRows.isEmpty) {
          await transaction.insert('extra_income_templates', templateValues);
        } else {
          templateValues.remove('id');
          templateValues.remove('created_at');
          await transaction.update(
            'extra_income_templates',
            templateValues,
            where: 'id = ?',
            whereArgs: [templateId],
          );
        }
      }
      await transaction.insert(
        'extra_income_entries',
        _toRow(entry, now, recurrenceTemplateId: templateId),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  @override
  Future<void> materializeRecurringEntries(YearMonth month) async {
    final db = (await _provider.instance).raw;
    final templates = await db.query(
      'extra_income_templates',
      where: 'active = 1 AND start_month <= ?',
      whereArgs: [month.databaseKey],
    );
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((transaction) async {
      for (final template in templates) {
        final templateId = template['id'] as String;
        await transaction.insert('extra_income_entries', {
          'id': '$templateId:${month.databaseKey}',
          'kind': template['kind'],
          'name': template['name'],
          'description': template['description'],
          'amount_minor': template['amount_minor'],
          'currency_code': template['currency_code'],
          'year_month': month.databaseKey,
          'recurring': 1,
          'include_in_financial_income':
              template['include_in_financial_income'],
          'recurrence_template_id': templateId,
          'created_at': now,
          'updated_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  @override
  Future<void> softDelete(String id, DateTime deletedAt) async {
    final db = (await _provider.instance).raw;
    await db.update(
      'extra_income_entries',
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
      'extra_income_entries',
      {
        'deleted_at': null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Map<String, Object?> _toRow(
    ExtraIncomeEntry entry,
    String now, {
    String? recurrenceTemplateId,
  }) => {
    'id': entry.id,
    'kind': entry.kind.name,
    'name': entry.name,
    'description': entry.description,
    'amount_minor': entry.amountMinor,
    'currency_code': entry.currency.isoCode,
    'year_month': entry.month.databaseKey,
    'recurring': entry.recurring ? 1 : 0,
    'include_in_financial_income': entry.includeInFinancialIncome ? 1 : 0,
    'recurrence_template_id':
        recurrenceTemplateId ?? entry.recurrenceTemplateId,
    'deleted_at': entry.deletedAt?.toUtc().toIso8601String(),
    'created_at': now,
    'updated_at': now,
  };

  ExtraIncomeEntry _fromRow(Map<String, Object?> row) {
    final month = (row['year_month'] as String).split('-');
    return ExtraIncomeEntry(
      id: row['id'] as String,
      kind: ExtraIncomeKind.values.byName(row['kind'] as String),
      name: row['name'] as String,
      description: row['description'] as String,
      amountMinor: row['amount_minor'] as int,
      currency: CurrencyCode.values.byName(
        (row['currency_code'] as String).toLowerCase(),
      ),
      month: YearMonth(int.parse(month[0]), int.parse(month[1])),
      recurring: (row['recurring'] as int) == 1,
      includeInFinancialIncome:
          (row['include_in_financial_income'] as int) == 1,
      recurrenceTemplateId: row['recurrence_template_id'] as String?,
      deletedAt: row['deleted_at'] == null
          ? null
          : DateTime.parse(row['deleted_at'] as String),
    );
  }
}
