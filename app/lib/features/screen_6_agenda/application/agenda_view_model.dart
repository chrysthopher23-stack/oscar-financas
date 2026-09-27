import 'package:flutter/foundation.dart';

import '../../../core/time/year_month.dart';
import '../../../shared/controllers/month_controller.dart';
import '../domain/agenda_event.dart';
import '../domain/agenda_repository.dart';
import 'notification_contracts.dart';

final class AgendaViewModel extends ChangeNotifier {
  AgendaViewModel({
    required this.repository,
    required this.scheduler,
    required this.monthController,
  }) {
    monthController.addListener(load);
  }
  final AgendaRepository repository;
  final LocalNotificationScheduler scheduler;
  final MonthController monthController;
  List<AgendaEvent> events = const [];
  AgendaCategory category = AgendaCategory.personal;
  bool loading = true;
  String? notice;

  YearMonth get month => monthController.focusedMonth;

  Future<void> load() async {
    loading = true;
    notifyListeners();
    try {
      events = await repository.eventsForMonth(month);
      notice = null;
    } catch (_) {
      notice = 'Não foi possível carregar a Agenda.';
    }
    loading = false;
    notifyListeners();
  }

  void selectCategory(AgendaCategory value) {
    category = value;
    notifyListeners();
  }

  List<AgendaEvent> eventsOn(DateTime day) => events
      .where((event) => event.category == category && event.occursOn(day))
      .toList(growable: false);

  Future<void> save(AgendaEvent event) async {
    await repository.save(event);
    final permission = await scheduler.ensurePermission();
    if (permission == ReminderPermissionState.granted) {
      await scheduler.replaceForEvent(event);
      notice = 'Compromisso salvo e lembrete local agendado.';
    } else {
      notice = 'Compromisso salvo. O alerta está desativado porque a permissão não foi concedida.';
    }
    await load();
  }

  Future<void> remove(AgendaEvent event) async {
    await scheduler.cancelForEvent(event.id);
    await repository.softDelete(event.id, DateTime.now().toUtc());
    await load();
  }

  Future<void> restore(AgendaEvent event) async {
    await repository.restore(event.id);
    await scheduler.replaceForEvent(event);
    await load();
  }

  @override
  void dispose() {
    monthController.removeListener(load);
    super.dispose();
  }
}
