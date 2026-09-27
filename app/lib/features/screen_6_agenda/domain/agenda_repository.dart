import '../../../core/time/year_month.dart';
import 'agenda_event.dart';

abstract interface class AgendaRepository {
  Future<List<AgendaEvent>> eventsForMonth(YearMonth month);
  Future<void> save(AgendaEvent event);
  Future<void> softDelete(String id, DateTime deletedAt);
  Future<void> restore(String id);
}
