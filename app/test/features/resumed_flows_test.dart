import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oscar_financas/app/services/create_app_services_web.dart';
import 'package:oscar_financas/app/theme/app_theme.dart';
import 'package:oscar_financas/core/localization/app_locale.dart';
import 'package:oscar_financas/core/localization/app_strings.dart';
import 'package:oscar_financas/core/localization/language_brain.dart';
import 'package:oscar_financas/core/money/money.dart';
import 'package:oscar_financas/core/time/year_month.dart';
import 'package:oscar_financas/features/screen_1_financial/presentation/financial_page.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/fx_quote_set.dart';
import 'package:oscar_financas/features/screen_8_plans/application/entitlement_controller.dart';
import 'package:oscar_financas/features/screen_8_plans/domain/access_policy.dart';
import 'package:oscar_financas/features/screen_8_plans/presentation/plans_page.dart';
import 'package:oscar_financas/shared/controllers/financial_visibility_controller.dart';

Widget host(SupportedAppLocale locale, Widget child) => MaterialApp(
  locale: locale.locale,
  supportedLocales: SupportedAppLocale.values.map((e) => e.locale),
  localizationsDelegates: const [
    AppStrings.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: AppTheme.light(),
  home: child,
);

void main() {
  for (final locale in SupportedAppLocale.values) {
    testWidgets(
      '${locale.tag}: populated footer hides and restores without reload',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 740));
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          debugPrint(details.toString());
          originalOnError?.call(details);
        };
        addTearDown(() => FlutterError.onError = originalOnError);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        SharedPreferences.setMockInitialValues({});
        final visibility = FinancialVisibilityController(
          await SharedPreferences.getInstance(),
        );
        addTearDown(visibility.dispose);
        final services = createAppServices();
        await services.ensureInitialDemoData(
          month: YearMonth.now(),
          currency: CurrencyCode.brl,
        );
        await tester.pumpWidget(
          host(
            locale,
            FinancialPage(
              onDestinationSelected: (_) {},
              visibilityController: visibility,
              repository: services.financialRepository,
              extraIncomePort: services.extraIncomeContributionPort,
              currency: CurrencyCode.brl,
              fxRepository: const OfflineDemonstrationFxRepository(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final footer = tester
            .widget<Scaffold>(find.byType(Scaffold).first)
            .bottomNavigationBar!;
        final footerFinder = find.byWidget(footer);
        expect(
          find.descendant(of: footerFinder, matching: find.text('••••')),
          findsNothing,
        );
        await visibility.toggle();
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: footerFinder, matching: find.text('••••')),
          findsNWidgets(3),
        );
        await visibility.toggle();
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: footerFinder, matching: find.text('••••')),
          findsNothing,
        );
        for (var i = 0; i < 5; i++) {
          await tester.drag(find.byType(ListView).first, const Offset(0, -420));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      },
    );
    testWidgets(
      '${locale.tag}: plans and blocked invitation render at 320 px',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 740));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final entitlements = EntitlementController();
        addTearDown(entitlements.dispose);
        final brain = LanguageBrain(locale);
        await tester.pumpWidget(
          host(
            locale,
            PlansPage(
              onDestinationSelected: (_) {},
              entitlements: entitlements,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.text(
            brain.message('Escolha a clareza que acompanha seu momento'),
          ),
          findsNothing,
        );
        expect(
          find.text(
            brain.message(
              'Todos os planos preservam seus dados e a navegação completa. Recursos avançados são explicados no ponto de uso.',
            ),
          ),
          findsNothing,
        );
        expect(
          find.text(
            brain.message(
              'Toque em um plano para visualizar os recursos disponíveis.',
            ),
          ),
          findsNothing,
        );
        await tester.tap(find.text(brain.message('Anual')));
        await tester.pumpAndSettle();
        for (var i = 0; i < 8; i++) {
          await tester.drag(find.byType(ListView).first, const Offset(0, -400));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        expect(
          find.text(
            brain.message('Investimentos, busca internacional, ações e ETFs'),
          ),
          findsOneWidget,
        );
        expect(
          brain.messages.containsKey(
            'Investimentos, busca internacional, ações, ETFs e calculadora',
          ),
          isFalse,
        );
        await tester.tap(find.text(brain.message('Convidar')));
        await tester.pumpAndSettle();
        expect(
          find.text(
            brain.message(
              'O convite de amigos está indisponível nesta versão.',
            ),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('choosing Pro on the plans screen activates its features', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final entitlements = EntitlementController();
    addTearDown(entitlements.dispose);
    await tester.pumpWidget(
      host(
        SupportedAppLocale.ptBr,
        PlansPage(onDestinationSelected: (_) {}, entitlements: entitlements),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Plano Pro'), 320);
    final proCard = find
        .ancestor(of: find.text('Plano Pro'), matching: find.byType(Card))
        .first;
    final choosePro = find.descendant(
      of: proCard,
      matching: find.byType(FilledButton),
    );
    await tester.ensureVisible(choosePro);
    await tester.pumpAndSettle();
    await tester.tap(choosePro);
    await tester.pumpAndSettle();

    expect(entitlements.tier, PlanTier.pro);
    expect(entitlements.evaluate(CapabilityId.investments).allowed, isTrue);
    expect(entitlements.evaluate(CapabilityId.objectives).allowed, isTrue);
    expect(tester.takeException(), isNull);
  });
}
