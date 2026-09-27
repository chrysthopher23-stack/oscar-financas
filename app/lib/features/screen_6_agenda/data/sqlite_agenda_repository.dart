import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/time/year_month.dart';
import '../domain/agenda_event.dart';
import '../domain/agenda_repository.dart';

final class SqliteAgendaRepository implements AgendaRepository {
  const SqliteAgendaRepository(this._database);
  final LazyAppDatabase _database;

  @override
  Future<List<AgendaEvent>> eventsForMonth(YearMonth month) async {
    final db = (await _database.instance).raw;
    final monthStart = DateTime(month.year, month.month);
    final monthEnd = DateTime(month.year, month.month + 1);
    final rows = await db.query(
      'agenda_events',
      where: '''deleted_at IS NULL AND (
        (recurrence = 'none' AND local_start >= ? AND local_start < ?)
        OR (recurrence != 'none' AND local_start < ?)
      )''',
      whereArgs: [
        monthStart.toIso8601String(),
        monthEnd.toIso8601String(),
        monthEnd.toIso8601String(),
      ],
      orderBy: 'local_start ASC',
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Future<void> save(AgendaEvent event) async {
    final db = (await _database.instance).raw;
    await db.insert(
      'agenda_events',
      _toRow(event),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> softDelete(String id, DateTime deletedAt) async {
    final db = (await _database.instance).raw;
    await db.update(
      'agenda_events',
      {'deleted_at': deletedAt.toUtc().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> restore(String id) async {
    final db = (await _database.instance).raw;
    await db.update(
      'agenda_events',
      {'deleted_at': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Map<String, Object?> _toRow(AgendaEvent event) => {
    'id': event.id,
    'title': event.title,
    'notes': event.notes,
    'category': event.category.name,
    'local_start': event.start.toIso8601String(),
    'local_end': event.end?.toIso8601String(),
    'timezone_id': event.timezoneId,
    'recurrence': event.recurrence.name,
    'reminder_preset': event.reminderPreset.name,
    'service_value_minor': event.serviceValueMinor,
    'service_currency': event.serviceCurrency,
    'service_completed': event.serviceCompleted ? 1 : 0,
    'deleted_at': event.deletedAt?.toUtc().toIso8601String(),
    'created_at': event.createdAt.toUtc().toIso8601String(),
    'updated_at': event.updatedAt.toUtc().toIso8601String(),
  };

  static AgendaEvent _fromRow(Map<String, Object?> row) => AgendaEvent(
    id: row['id'] as String,
    title: row['title'] as String,
    notes: row['notes'] as String,
    category: AgendaCategory.values.byName(row['category'] as String),
    start: DateTime.parse(row['local_start'] as String),
    end: row['local_end'] == null
        ? null
        : DateTime.parse(row['local_end'] as String),
    timezoneId: row['timezone_id'] as String,
    recurrence: EventRecurrence.values.byName(row['recurrence'] as String),
    reminderPreset: ReminderPreset.values.byName(
      row['reminder_preset'] as String,
    ),
    serviceValueMinor: row['service_value_minor'] as int?,
    serviceCurrency: row['service_currency'] as String?,
    serviceCompleted: (row['service_completed'] as int) == 1,
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
    deletedAt: row['deleted_at'] == null
        ? null
        : DateTime.parse(row['deleted_at'] as String),
  );
}
