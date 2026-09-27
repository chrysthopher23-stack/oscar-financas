part of '../agenda_page.dart';

final class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.month,
    required this.selectedDay,
    required this.eventsOn,
    required this.onDaySelected,
  });
  final YearMonth month;
  final DateTime? selectedDay;
  final List<AgendaEvent> Function(DateTime) eventsOn;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final gridStart = first.subtract(Duration(days: first.weekday % 7));
    final today = DateTime.now();
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
      child: Column(
        children: [
          const Row(
            children: [
              _Weekday('DOM'),
              _Weekday('SEG'),
              _Weekday('TER'),
              _Weekday('QUA'),
              _Weekday('QUI'),
              _Weekday('SEX'),
              _Weekday('SÁB'),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 42,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: .82,
              ),
              itemBuilder: (context, index) {
                final day = gridStart.add(Duration(days: index));
                final events = eventsOn(day);
                final inMonth =
                    day.month == month.month && day.year == month.year;
                final isToday =
                    day.year == today.year &&
                    day.month == today.month &&
                    day.day == today.day;
                final selected =
                    selectedDay != null &&
                    day.year == selectedDay!.year &&
                    day.month == selectedDay!.month &&
                    day.day == selectedDay!.day;
                return Semantics(
                  button: true,
                  label: uiText(
                    context,
                    '${day.day}/${day.month}/${day.year}, ${events.length} compromissos',
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onDaySelected(day),
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : isToday
                              ? AppColors.emerald
                              : Colors.transparent,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${day.day}',
                            style: TextStyle(
                              color: inMonth
                                  ? null
                                  : Theme.of(context).disabledColor,
                              fontWeight: isToday ? FontWeight.bold : null,
                            ),
                          ),
                          if (events.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFFD4AF37),
                                  ),
                                ),
                                if (events.length > 1)
                                  Text(
                                    ' ${events.length}',
                                    style: const TextStyle(fontSize: 10),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

final class _Weekday extends StatelessWidget {
  const _Weekday(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Center(
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    ),
  );
}
