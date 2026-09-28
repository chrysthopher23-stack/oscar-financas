import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oscar_financas/app/theme/app_theme.dart';
import 'package:oscar_financas/core/localization/app_locale.dart';
import 'package:oscar_financas/core/localization/app_strings.dart';
import 'package:oscar_financas/core/money/money.dart';
import 'package:oscar_financas/features/screen_7_calculator/domain/compound_projection.dart';
import 'package:oscar_financas/features/screen_7_calculator/presentation/calculator_page.dart';

void main() {
  for (final supported in SupportedAppLocale.values) {
    testWidgets('${supported.tag}: calculator stays responsive at 320 px', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

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
          home: CalculatorPage(
            onDestinationSelected: (_) {},
            currency: CurrencyCode.brl,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.text(AppStrings(supported).text('screen.calculator')),
        findsOneWidget,
      );
      expect(find.byType(SegmentedButton<RatePeriodicity>), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -360));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byType(FilledButton));
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('R\$'), findsOneWidget);
    });
  }
}
