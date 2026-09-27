import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oscar_financas/app/theme/app_colors.dart';
import 'package:oscar_financas/app/theme/app_theme.dart';

void main() {
  for (final theme in <(String, ThemeData)>[
    ('light', AppTheme.light()),
    ('dark', AppTheme.dark()),
  ]) {
    testWidgets('${theme.$1}: selected segmented label stays readable', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: theme.$2,
          home: Scaffold(
            body: Center(
              child: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('Automático'),
                  ),
                  ButtonSegment(value: ThemeMode.light, label: Text('Claro')),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Escuro')),
                ],
                selected: const {ThemeMode.light},
                onSelectionChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final selectedContext = tester.element(find.text('Claro'));
      expect(DefaultTextStyle.of(selectedContext).style.color, AppColors.snow);
      expect(tester.takeException(), isNull);
    });
  }
}
