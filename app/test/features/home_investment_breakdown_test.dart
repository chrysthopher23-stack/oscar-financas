import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oscar_financas/core/localization/app_locale.dart';
import 'package:oscar_financas/core/localization/app_strings.dart';
import 'package:oscar_financas/core/money/money.dart';
import 'package:oscar_financas/features/screen_0_home/application/home_investment_totals.dart';
import 'package:oscar_financas/features/screen_0_home/presentation/widgets/investment_breakdown.dart';
import 'package:oscar_financas/shared/formatting/money_formatter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final locale in SupportedAppLocale.values) {
    testWidgets(
      '${locale.tag}: breakdown fits a narrow screen and is localized',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final strings = AppStrings(locale);
        await tester.pumpWidget(
          MaterialApp(
            locale: locale.locale,
            supportedLocales: SupportedAppLocale.values
                .map((item) => item.locale)
                .toList(),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              AppStrings.delegate,
            ],
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(12),
                child: InvestmentBreakdown(
                  totals: const HomeInvestmentTotals(
                    assetsValueMinor: 2890000,
                    assetsCount: 8,
                    assetsMonthlyChangeBasisPoints: 240,
                    cryptoValueMinor: 237293,
                    cryptoCount: 4,
                    cryptoDailyChangeBasisPoints: -110,
                  ),
                  formatter: MoneyFormatter(
                    locale: locale.tag,
                    currency: CurrencyCode.brl,
                  ),
                  locale: locale.tag,
                  valuesHidden: false,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(strings.text('Ativos')), findsOneWidget);
        expect(find.text(strings.text('Criptoativos')), findsOneWidget);
        expect(
          find.text(strings.text('{count} ativos', {'count': '8'})),
          findsOneWidget,
        );
        expect(
          find.text(strings.text('{count} criptoativos', {'count': '4'})),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.trending_up_rounded), findsOneWidget);
        expect(find.byIcon(Icons.trending_down_rounded), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
