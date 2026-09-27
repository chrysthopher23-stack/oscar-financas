enum AgendaCategory { personal, scheduledService, professional }

enum EventRecurrence { none, weekly, monthly, yearly }

enum ReminderPreset { atTime, oneDayAndAtTime, threeDaysOneDayAndAtTime }

final class AgendaEvent {
  const AgendaEvent({
    required this.id,
    required this.title,
    required this.notes,
    required this.category,
    required this.start,
    required this.timezoneId,
    required this.recurrence,
    required this.reminderPreset,
    required this.createdAt,
    required this.updatedAt,
    this.end,
    this.serviceValueMinor,
    this.serviceCurrency,
    this.serviceCompleted = false,
    this.deletedAt,
  });
  final String id;
  final String title;
  final String notes;
  final AgendaCategory category;
  final DateTime start;
  final DateTime? end;
  final String timezoneId;
  final EventRecurrence recurrence;
  final ReminderPreset reminderPreset;
  final int? serviceValueMinor;
  final String? serviceCurrency;
  final bool serviceCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool occursOn(DateTime day) {
    final target = DateTime(day.year, day.month, day.day);
    final origin = DateTime(start.year, start.month, start.day);
    if (target.isBefore(origin)) return false;
    return switch (recurrence) {
      EventRecurrence.none => target == origin,
      EventRecurrence.weekly => target.difference(origin).inDays % 7 == 0,
      EventRecurrence.monthly => target.day == origin.day,
      EventRecurrence.yearly =>
        target.month == origin.month && target.day == origin.day,
    };
  }
}
