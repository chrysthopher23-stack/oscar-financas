import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as material show Text;
import 'package:oscar_financas/shared/widgets/localized_text.dart';

import '../../../app/navigation/app_destination.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/time/year_month.dart';
import '../../../shared/controllers/month_controller.dart';
import '../../../shared/widgets/oscar_feature_scaffold.dart';
import '../application/agenda_view_model.dart';
import '../application/notification_contracts.dart';
import '../domain/agenda_event.dart';
import '../domain/agenda_repository.dart';

part 'widgets/agenda_calendar_grid.dart';

final class AgendaPage extends StatefulWidget {
  const AgendaPage({
    super.key,
    required this.onDestinationSelected,
    required this.repository,
    required this.scheduler,
    required this.defaultReminder,
    this.minimumMonth,
  });
  final ValueChanged<AppDestination> onDestinationSelected;
  final AgendaRepository repository;
  final LocalNotificationScheduler scheduler;
  final ReminderPreset defaultReminder;
  final YearMonth? minimumMonth;
  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

final class _AgendaPageState extends State<AgendaPage> {
  late final MonthController _monthController;
  late final AgendaViewModel _viewModel;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _monthController = MonthController(
      minimumMonth: widget.minimumMonth,
      currentMonthFloor: true,
    );
    _viewModel = AgendaViewModel(
      repository: widget.repository,
      scheduler: widget.scheduler,
      monthController: _monthController,
    )..load();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _monthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OscarFeatureScaffold(
    destination: AppDestination.agenda,
    onDestinationSelected: widget.onDestinationSelected,
    headerKind: FeatureHeaderKind.agendaMonth,
    monthController: _monthController,
    body: ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) => Column(
        children: [
          if (_viewModel.notice != null)
            MaterialBanner(
              content: Text(_viewModel.notice!),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _viewModel.notice = null),
                  child: const Text('Fechar'),
                ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: SegmentedButton<AgendaCategory>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: AgendaCategory.personal,
                  label: Text(
                    'Compromissos\npessoais',
                    textAlign: TextAlign.center,
                  ),
                ),
                ButtonSegment(
                  value: AgendaCategory.scheduledService,
                  label: Text(
                    'Serviços\nagendados',
                    textAlign: TextAlign.center,
                  ),
                ),
                ButtonSegment(
                  value: AgendaCategory.professional,
                  label: Text(
                    'Compromissos\nprofissionais',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              selected: {_viewModel.category},
              onSelectionChanged: (value) =>
                  _viewModel.selectCategory(value.first),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity.abs() < 220) return;
                _monthController.changeMonth(velocity < 0 ? 1 : -1);
              },
              child: _CalendarGrid(
                month: _viewModel.month,
                selectedDay: _selectedDay,
                eventsOn: _viewModel.eventsOn,
                onDaySelected: _openDay,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _openDay(DateTime day) async {
    setState(() => _selectedDay = day);
    final events = _viewModel.eventsOn(day);
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .55,
        maxChildSize: .88,
        builder: (context, scrollController) => Column(
          children: [
            ListTile(
              title: Text(
                '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}/${day.year}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              trailing: IconButton(
                tooltip: uiText(context, 'Fechar'),
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(sheetContext),
              ),
            ),
            Expanded(
              child: events.isEmpty
                  ? const Center(child: Text('Nenhum compromisso neste dia.'))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: events.length,
                      itemBuilder: (context, index) {
                        final event = events[index];
                        return ListTile(
                          leading: Text(
                            '${event.start.hour.toString().padLeft(2, '0')}:${event.start.minute.toString().padLeft(2, '0')}',
                          ),
                          title: material.Text(event.title),
                          subtitle: material.Text(event.notes),
                          onTap: () => _showEventDetails(event, sheetContext),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _showEventForm(day);
                },
                icon: const Icon(Icons.add),
                label: const Text('Adicionar compromisso'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEventForm(DateTime day) async {
    final title = TextEditingController();
    final notes = TextEditingController();
    var time = const TimeOfDay(hour: 9, minute: 0);
    var recurrence = EventRecurrence.none;
    var reminder = widget.defaultReminder;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Novo compromisso',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: title,
                  decoration: InputDecoration(
                    labelText: uiText(context, 'Título *'),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notes,
                  decoration: InputDecoration(
                    labelText: uiText(context, 'Observação opcional'),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.schedule),
                  label: Text('Horário · ${time.format(context)}'),
                  onPressed: () async {
                    final selected = await showTimePicker(
                      context: context,
                      initialTime: time,
                    );
                    if (selected != null) setSheetState(() => time = selected);
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<EventRecurrence>(
                  isExpanded: true,
                  initialValue: recurrence,
                  decoration: InputDecoration(
                    labelText: uiText(context, 'Recorrência'),
                  ),
                  items:
                      const {
                            EventRecurrence.none: 'Nenhuma',
                            EventRecurrence.weekly: 'Semanal',
                            EventRecurrence.monthly: 'Mensal',
                            EventRecurrence.yearly: 'Anual',
                          }.entries
                          .map(
                            (entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                  onChanged: (value) =>
                      setSheetState(() => recurrence = value!),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<ReminderPreset>(
                  isExpanded: true,
                  initialValue: reminder,
                  decoration: InputDecoration(
                    labelText: uiText(context, 'Lembretes locais'),
                  ),
                  items:
                      const {
                            ReminderPreset.atTime: 'No horário',
                            ReminderPreset.oneDayAndAtTime:
                                '1 dia antes e no horário',
                            ReminderPreset.threeDaysOneDayAndAtTime:
                                '3 dias antes, 1 dia antes e no horário',
                          }.entries
                          .map(
                            (entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                  onChanged: (value) => setSheetState(() => reminder = value!),
                ),
                const SizedBox(height: 10),
                const Text(
                  'O aplicativo agenda notificações locais. A entrega depende das permissões, economia de bateria, modo silencioso e políticas do aparelho.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () async {
                    if (title.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Informe o título do compromisso.'),
                        ),
                      );
                      return;
                    }
                    final now = DateTime.now();
                    await _viewModel.save(
                      AgendaEvent(
                        id: 'agenda-${now.microsecondsSinceEpoch}',
                        title: title.text.trim(),
                        notes: notes.text.trim(),
                        category: _viewModel.category,
                        start: DateTime(
                          day.year,
                          day.month,
                          day.day,
                          time.hour,
                          time.minute,
                        ),
                        timezoneId: now.timeZoneName,
                        recurrence: recurrence,
                        reminderPreset: reminder,
                        createdAt: now.toUtc(),
                        updatedAt: now.toUtc(),
                      ),
                    );
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  },
                  child: const Text('Salvar'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showEventDetails(
    AgendaEvent event,
    BuildContext daySheetContext,
  ) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: material.Text(event.title),
        content: material.Text(
          '${event.start.hour.toString().padLeft(2, '0')}:${event.start.minute.toString().padLeft(2, '0')}\n${event.notes}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Fechar'),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (remove != true) return;
    await _viewModel.remove(event);
    if (!mounted || !daySheetContext.mounted) return;
    Navigator.pop(daySheetContext);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Compromisso excluído.'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: uiText(context, 'Desfazer'),
          onPressed: () => _viewModel.restore(event),
        ),
      ),
    );
  }
}
