import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oscar_financas/app/services/create_app_services_web.dart';
import 'package:oscar_financas/app/theme/app_theme.dart';
import 'package:oscar_financas/core/localization/app_strings.dart';
import 'package:oscar_financas/core/money/money.dart';
import 'package:oscar_financas/core/time/year_month.dart';
import 'package:oscar_financas/features/screen_2_extra_income/presentation/extra_income_page.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/fx_quote_set.dart';
import 'package:oscar_financas/shared/controllers/financial_visibility_controller.dart';

void main() {
  testWidgets('populated extra-income months have finite scrollable bodies', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final visibility = FinancialVisibilityController(preferences);
    addTearDown(visibility.dispose);
    final services = createAppServices();
    await services.ensureInitialDemoData(
      month: const YearMonth(2026, 9),
      currency: CurrencyCode.usd,
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
        home: ExtraIncomePage(
          onDestinationSelected: (_) {},
          visibilityController: visibility,
          repository: services.extraIncomeRepository,
          currency: CurrencyCode.usd,
          fxRepository: const OfflineDemonstrationFxRepository(),
          actionsEnabled: true,
          onBlocked: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Freelance service', skipOffstage: false), findsWidgets);
    expect(find.text('Pool cleaning', skipOffstage: false), findsWidgets);
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    expect(scrollable.position.maxScrollExtent, lessThan(1500));
    for (var index = 0; index < 6; index++) {
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(scrollable.position.maxScrollExtent, lessThan(1500));
    }
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(scrollable.position.maxScrollExtent, lessThan(1500));
  });
}
