import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oscar_financas/app/settings/app_preferences_controller.dart';
import 'package:oscar_financas/app/theme/app_theme.dart';
import 'package:oscar_financas/core/localization/app_locale.dart';
import 'package:oscar_financas/core/localization/app_strings.dart';
import 'package:oscar_financas/core/money/money.dart';
import 'package:oscar_financas/shared/widgets/localized_text.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/fx_quote_set.dart';
import 'package:oscar_financas/features/screen_11_settings/presentation/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final supported in SupportedAppLocale.values) {
    testWidgets('${supported.tag}: settings stays responsive at 320 px', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({
        'regional.locale': supported.tag,
        'regional.locale_manual': true,
        'appearance.theme': 'light',
      });
      final storage = await SharedPreferences.getInstance();
      final preferences = AppPreferencesController(storage, supported.locale);
      addTearDown(preferences.dispose);

      await tester.pumpWidget(
        MaterialApp(
          locale: supported.locale,
          supportedLocales: SupportedAppLocale.values.map((e) => e.locale),
          localizationsDelegates: const [
            AppStrings.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.light(),
          home: SettingsPage(
            preferences: preferences,
            fxRepository: const OfflineDemonstrationFxRepository(),
            onDestinationSelected: (_) {},
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView).first, const Offset(0, -480));
      await tester.pumpAndSettle();
      expect(find.byType(SegmentedButton<ThemeMode>), findsOneWidget);
      expect(tester.takeException(), isNull);
      for (var step = 0; step < 8; step++) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -420));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(
        find.text(uiTextForLocale(supported, 'Sobre o aplicativo')),
        findsOneWidget,
      );
      expect(find.text('Oscar Finanças'), findsOneWidget);
      expect(
        find.text(
          uiTextForLocale(
            supported,
            'Clareza que transforma escolhas em patrimônio',
          ),
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets('refresh button shows a persisted countdown at 320 px', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final storage = await SharedPreferences.getInstance();
    final preferences = AppPreferencesController(
      storage,
      SupportedAppLocale.ptBr.locale,
    );
    addTearDown(preferences.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: SupportedAppLocale.ptBr.locale,
        supportedLocales: SupportedAppLocale.values.map((e) => e.locale),
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light(),
        home: SettingsPage(
          preferences: preferences,
          fxRepository: const _ScheduledFx(),
          onDestinationSelected: (_) {},
        ),
      ),
    );
    await tester.pump();
    final countdown = find.textContaining(RegExp(r'\d{2}:\d{2}:\d{2}'));
    await tester.scrollUntilVisible(
      countdown,
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(countdown, findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.ancestor(of: countdown, matching: find.byType(FilledButton)),
    );
    expect(button.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
}

final class _ScheduledFx implements FxRepository, FxRefreshSchedule {
  const _ScheduledFx();

  @override
  Future<DateTime?> nextRefreshAt() async =>
      DateTime.now().toUtc().add(const Duration(hours: 6));

  @override
  Future<FxQuoteSet?> latest(CurrencyCode base, {bool forceRefresh = false}) =>
      const OfflineDemonstrationFxRepository().latest(base);
}
