import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/localization/app_strings.dart';
import '../controllers/month_controller.dart';

final class MonthSelector extends StatelessWidget {
  const MonthSelector({super.key, required this.controller});

  final MonthController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final value = controller.focusedMonth;
        // intl expects Flutter's locale identifier (for example, de_DE),
        // rather than the BCP-47 tag (de-DE). The latter can fall back to
        // English month symbols in some locales.
        final locale = Localizations.localeOf(context).toString();
        final label = _capitalizeInitial(
          DateFormat.yMMMM(locale).format(DateTime(value.year, value.month)),
        );
        final strings = AppStrings.of(context);

        return Row(
          children: [
            _MonthArrow(
              tooltip: strings.text('month.previous'),
              icon: Icons.chevron_left,
              onPressed: controller.canGoPrevious
                  ? () => controller.changeMonth(-1)
                  : null,
            ),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            _MonthArrow(
              tooltip: strings.text('month.next'),
              icon: Icons.chevron_right,
              onPressed: () => controller.changeMonth(1),
            ),
          ],
        );
      },
    );
  }
}

String _capitalizeInitial(String value) {
  if (value.isEmpty) return value;
  final runes = value.runes;
  final first = String.fromCharCode(runes.first);
  return '${first.toUpperCase()}${String.fromCharCodes(runes.skip(1))}';
}

final class _MonthArrow extends StatelessWidget {
  const _MonthArrow({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    icon: Icon(icon),
    padding: EdgeInsets.zero,
    visualDensity: VisualDensity.compact,
    constraints: const BoxConstraints.tightFor(width: 36, height: 40),
  );
}
