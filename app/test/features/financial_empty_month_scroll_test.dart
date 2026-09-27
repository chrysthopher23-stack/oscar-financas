import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oscar_financas/app/services/create_app_services_web.dart';
import 'package:oscar_financas/app/theme/app_theme.dart';
import 'package:oscar_financas/core/localization/app_strings.dart';
import 'package:oscar_financas/core/money/money.dart';
import 'package:oscar_financas/core/time/year_month.dart';
import 'package:oscar_financas/features/screen_1_financial/presentation/financial_page.dart';
import 'package:oscar_financas/features/screen_1_financial/domain/financial_transaction.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/fx_quote_set.dart';
import 'package:oscar_financas/shared/controllers/financial_visibility_controller.dart';

void main() {
  testWidgets('empty month after populated month has finite, reachable end', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({'history.personal-start.v1': true});
    final visibility = FinancialVisibilityController(
      await SharedPreferences.getInstance(),
    );
    addTearDown(visibility.dispose);
    final services = createAppServices();
    final firstMonth = YearMonth.now();
    await services.ensureInitialDemoData(
      month: firstMonth,
      currency: CurrencyCode.usd,
    );
    await services.financialRepository.saveTransaction(
      FinancialTransaction(
        id: 'one-time-income',
        title: 'One-time income',
        kind: TransactionKind.income,
        originalAmountMinor: 48000,
        currency: CurrencyCode.usd,
        month: firstMonth,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'US'),
        supportedLocales: const [Locale('en', 'US')],
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light(),
        home: FinancialPage(
          initialMonth: firstMonth,
          minimumMonth: firstMonth,
          onDestinationSelected: (_) {},
          visibilityController: visibility,
          repository: services.financialRepository,
          extraIncomePort: services.extraIncomeContributionPort,
          currency: CurrencyCode.usd,
          fxRepository: const OfflineDemonstrationFxRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('One-time income', skipOffstage: false), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find
                .ancestor(
                  of: find.byIcon(Icons.chevron_left),
                  matching: find.byType(IconButton),
                )
                .first,
          )
          .onPressed,
      isNull,
    );

    final listFinder = find.byType(ListView).first;
    final controller = tester
        .state<ScrollableState>(
          find.descendant(of: listFinder, matching: find.byType(Scrollable)),
        )
        .position;
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    expect(find.text('No income this month.'), findsOneWidget);
    expect(controller.maxScrollExtent, greaterThan(0));
    await tester.drag(listFinder, const Offset(0, -10000));
    await tester.pumpAndSettle();
    await tester.drag(listFinder, const Offset(0, -10000));
    await tester.pumpAndSettle();
    expect(controller.maxScrollExtent, lessThan(1500));
    expect(controller.pixels, closeTo(controller.maxScrollExtent, 1));
    expect(find.text('Oscar Score', skipOffstage: false), findsOneWidget);
    expect(tester.takeException(), isNull);

    for (var month = 0; month < 12; month++) {
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
      await tester.drag(listFinder, const Offset(0, -10000));
      await tester.pumpAndSettle();
      expect(controller.maxScrollExtent, lessThan(1500));
      expect(controller.pixels, closeTo(controller.maxScrollExtent, 1));
      expect(tester.takeException(), isNull);
    }
  });
}
