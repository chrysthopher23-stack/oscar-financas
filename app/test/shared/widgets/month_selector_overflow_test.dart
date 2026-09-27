import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
