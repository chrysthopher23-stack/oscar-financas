import 'package:flutter/material.dart' as material;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oscar_financas/app/theme/app_theme.dart';
import 'package:oscar_financas/core/localization/app_locale.dart';
import 'package:oscar_financas/core/localization/app_strings.dart';
import 'package:oscar_financas/core/time/year_month.dart';
import 'package:oscar_financas/features/screen_6_agenda/application/notification_contracts.dart';
import 'package:oscar_financas/features/screen_6_agenda/domain/agenda_event.dart';
import 'package:oscar_financas/features/screen_6_agenda/domain/agenda_repository.dart';
import 'package:oscar_financas/features/screen_6_agenda/presentation/agenda_page.dart';

void main() {
  testWidgets('agenda recurrence field stays bounded in all locales', (
    tester,
  ) async {
    tester.view.physicalSize = const material.Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final appLocale in SupportedAppLocale.values) {
      await tester.pumpWidget(
        material.MaterialApp(
          theme: AppTheme.dark(),
          locale: appLocale.locale,
          supportedLocales: SupportedAppLocale.values
              .map((item) => item.locale)
              .toList(),
          localizationsDelegates: const [
            AppStrings.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: material.Scaffold(
            body: AgendaPage(
              onDestinationSelected: (_) {},
              repository: _AgendaRepository(),
              scheduler: const DisabledNotificationScheduler(),
              defaultReminder: ReminderPreset.threeDaysOneDayAndAtTime,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: appLocale.tag);

      tester
          .state<AgendaPageTestApi>(find.byType(AgendaPage))
          .showEventFormForTest(DateTime(2026, 9, 15));
      await tester.pumpAndSettle();

      final field = find.byKey(
        const material.ValueKey('agenda-recurrence-dropdown'),
      );
      expect(field, findsAtLeastNWidgets(1), reason: appLocale.tag);
      final recurrenceControl = field.first;
      expect(
        tester.getSize(recurrenceControl).height,
        lessThan(80),
        reason: appLocale.tag,
      );
      expect(
        tester.getSize(recurrenceControl).width,
        greaterThan(200),
        reason: appLocale.tag,
      );
      expect(tester.takeException(), isNull, reason: appLocale.tag);

      await tester.ensureVisible(recurrenceControl);
      await tester.pumpAndSettle();
      await tester.tap(recurrenceControl);
      await tester.pumpAndSettle();
      expect(
        find.text(AppStrings(appLocale).text('Semanal')).last,
        findsOneWidget,
        reason: appLocale.tag,
      );
      expect(tester.takeException(), isNull, reason: appLocale.tag);
    }
  });
}

final class _AgendaRepository implements AgendaRepository {
  @override
  Future<List<AgendaEvent>> eventsForMonth(YearMonth month) async => const [];

  @override
  Future<void> restore(String id) async {}

  @override
  Future<void> save(AgendaEvent event) async {}

  @override
  Future<void> softDelete(String id, DateTime deletedAt) async {}
}
