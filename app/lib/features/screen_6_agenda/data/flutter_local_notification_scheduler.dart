import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../application/notification_contracts.dart';
import '../domain/agenda_event.dart';

final class FlutterLocalNotificationScheduler
    implements LocalNotificationScheduler {
  FlutterLocalNotificationScheduler() {
    tz_data.initializeTimeZones();
  }

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> _initialize() async {
    if (_initialized) return;
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialized = true;
  }

  @override
  Future<ReminderPermissionState> ensurePermission() async {
    await _initialize();
    final android = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    final ios = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    final granted = android ?? ios ?? true;
    return granted
        ? ReminderPermissionState.granted
        : ReminderPermissionState.denied;
  }

  @override
  Future<void> replaceForEvent(AgendaEvent event) async {
    await _initialize();
    await cancelForEvent(event.id);
    final offsets = switch (event.reminderPreset) {
      ReminderPreset.atTime => const [Duration.zero],
      ReminderPreset.oneDayAndAtTime => const [
        Duration(days: 1),
        Duration.zero,
      ],
      ReminderPreset.threeDaysOneDayAndAtTime => const [
        Duration(days: 3),
        Duration(days: 1),
        Duration.zero,
      ],
    };
    for (var index = 0; index < offsets.length; index++) {
      final instant = event.start.subtract(offsets[index]);
      if (!instant.isAfter(DateTime.now())) continue;
      await _plugin.zonedSchedule(
        _notificationId(event.id, index),
        event.title,
        offsets[index] == Duration.zero
            ? 'Seu compromisso é agora.'
            : 'Você tem um compromisso em breve.',
        tz.TZDateTime.from(instant.toUtc(), tz.UTC),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'agenda_reminders',
            'Lembretes da Agenda',
            channelDescription:
                'Avisos locais dos compromissos salvos no Oscar Finanças',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: event.id,
      );
    }
  }

  @override
  Future<void> cancelForEvent(String eventId) async {
    await _initialize();
    for (var index = 0; index < 3; index++) {
      await _plugin.cancel(_notificationId(eventId, index));
    }
  }

  static int _notificationId(String eventId, int offsetIndex) {
    var hash = 0x811c9dc5;
    for (final unit in eventId.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
    }
    return (hash + offsetIndex) & 0x7fffffff;
  }
}
