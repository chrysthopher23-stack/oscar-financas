import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oscar_financas/app/theme/app_theme.dart';
import 'package:oscar_financas/core/localization/app_locale.dart';
import 'package:oscar_financas/core/localization/app_strings.dart';
import 'package:oscar_financas/core/localization/language_brain.dart';
import 'package:oscar_financas/core/money/money.dart';
import 'package:oscar_financas/core/time/year_month.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/investment_portfolio_history.dart';
import 'package:oscar_financas/features/screen_3_investments/presentation/widgets/portfolio_chart.dart';
import 'package:oscar_financas/shared/formatting/money_formatter.dart';

void main() {
  for (final language in SupportedAppLocale.values) {
    testWidgets('portfolio periods fit at 320 px in ${language.tag}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final currency = language == SupportedAppLocale.hiIn
          ? CurrencyCode.inr
          : CurrencyCode.brl;
      await tester.pumpWidget(
        MaterialApp(
          locale: language.locale,
          supportedLocales: SupportedAppLocale.values.map(
            (item) => item.locale,
          ),
          localizationsDelegates: const [
            AppStrings.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: PortfolioChart(
                valuesHidden: false,
                formatter: MoneyFormatter(
                  locale: language.tag,
                  currency: currency,
                ),
                history: const [
                  PortfolioHistoryPoint(
                    month: YearMonth(2026, 7),
                    principalMinor: 100000,
                    returnMinor: 1000,
                  ),
                  PortfolioHistoryPoint(
                    month: YearMonth(2026, 8),
                    principalMinor: 130000,
                    returnMinor: 2000,
                  ),
                  PortfolioHistoryPoint(
                    month: YearMonth(2026, 9),
                    principalMinor: 150000,
                    returnMinor: 3000,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ChoiceChip), findsNWidgets(5));
      final selectedLabel = LanguageBrain(language).message('3 meses');
      final chip = find.ancestor(
        of: find.text(selectedLabel),
        matching: find.byType(ChoiceChip),
      );
      expect(tester.widget<ChoiceChip>(chip).selected, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('privacy eye hides chart amounts, trend and expanded details', (
    tester,
  ) async {
    final history = const [
      PortfolioHistoryPoint(
        month: YearMonth(2026, 9),
        principalMinor: 150000,
        returnMinor: 3000,
      ),
    ];

    Widget chart({required bool hidden}) => MaterialApp(
      locale: const Locale('pt', 'BR'),
      supportedLocales: SupportedAppLocale.values.map((item) => item.locale),
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: PortfolioChart(
            history: history,
            formatter: MoneyFormatter(
              locale: 'pt-BR',
              currency: CurrencyCode.brl,
            ),
            valuesHidden: hidden,
          ),
        ),
      ),
    );

    await tester.pumpWidget(chart(hidden: false));
    await tester.tap(find.text('Ver valores mês a mês'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1.530,00'), findsWidgets);

    await tester.pumpWidget(chart(hidden: true));
    await tester.pumpAndSettle();
    expect(find.textContaining('1.530,00'), findsNothing);
    expect(find.textContaining('30,00'), findsNothing);
    expect(find.text('••••'), findsNWidgets(3));
    expect(find.byKey(const Key('portfolio-trend-plot')), findsNothing);

    await tester.pumpWidget(chart(hidden: false));
    await tester.pumpAndSettle();
    expect(find.textContaining('1.530,00'), findsWidgets);
  });
}
