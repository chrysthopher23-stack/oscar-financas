import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oscar_financas/core/time/year_month.dart';
import 'package:oscar_financas/app/navigation/app_destination.dart';
import 'package:oscar_financas/core/localization/app_strings.dart';
import 'package:oscar_financas/shared/controllers/financial_visibility_controller.dart';
import 'package:oscar_financas/shared/controllers/month_controller.dart';
import 'package:oscar_financas/shared/widgets/oscar_feature_scaffold.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const locales = <Locale>[
    Locale('pt', 'BR'),
    Locale('en', 'US'),
    Locale('de', 'DE'),
    Locale('fr', 'FR'),
    Locale('hi', 'IN'),
  ];

  for (final locale in locales) {
    testWidgets(
      '${locale.toLanguageTag()}: narrow financial header has no overflow',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 700));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        SharedPreferences.setMockInitialValues({});
        final storage = await SharedPreferences.getInstance();
        final month = MonthController();
        final visibility = FinancialVisibilityController(storage);
        addTearDown(month.dispose);
        addTearDown(visibility.dispose);

        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            supportedLocales: locales,
            localizationsDelegates: const [
              AppStrings.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: OscarFeatureScaffold(
              destination: AppDestination.financial,
              onDestinationSelected: (_) {},
              headerKind: FeatureHeaderKind.financialMonth,
              monthController: month,
              visibilityController: visibility,
              body: const SizedBox.expand(),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('month title uses a capital initial in every supported locale', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storage = await SharedPreferences.getInstance();
    final month = MonthController(initialMonth: const YearMonth(2026, 9));
    final visibility = FinancialVisibilityController(storage);
    addTearDown(month.dispose);
    addTearDown(visibility.dispose);

    for (final locale in locales) {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: locales,
          localizationsDelegates: const [
            AppStrings.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: OscarFeatureScaffold(
            destination: AppDestination.financial,
            onDestinationSelected: (_) {},
            headerKind: FeatureHeaderKind.financialMonth,
            monthController: month,
            visibilityController: visibility,
            body: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final title = tester.widgetList<Text>(find.byType(Text)).firstWhere(
        (text) => text.data?.contains('2026') ?? false,
      );
      expect(title.data, isNotEmpty, reason: locale.toLanguageTag());
      if (locale.languageCode != 'hi') {
        expect(
          title.data!.runes.first,
          inInclusiveRange('A'.runes.first, 'Z'.runes.first),
          reason: '${locale.toLanguageTag()}: ${title.data}',
        );
      }
    }
  });
}
