import '../domain/agenda_event.dart';

enum ReminderPermissionState { unknown, granted, denied }

abstract interface class LocalNotificationScheduler {
  Future<ReminderPermissionState> ensurePermission();
  Future<void> replaceForEvent(AgendaEvent event);
  Future<void> cancelForEvent(String eventId);
}

final class DisabledNotificationScheduler
    implements LocalNotificationScheduler {
  const DisabledNotificationScheduler();
  @override
  Future<void> cancelForEvent(String eventId) async {}
  @override
  Future<ReminderPermissionState> ensurePermission() async =>
      ReminderPermissionState.denied;
  @override
  Future<void> replaceForEvent(AgendaEvent event) async {}
}
