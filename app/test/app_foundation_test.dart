import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oscar_financas/app/navigation/app_destination.dart';
import 'package:oscar_financas/app/navigation/navigation_controller.dart';
import 'package:oscar_financas/app/oscar_financas_app.dart';
import 'package:oscar_financas/app/services/create_app_services_web.dart'
    as web;
import 'package:oscar_financas/app/settings/app_preferences_controller.dart';
import 'package:oscar_financas/core/brand/phone_splash_artwork.dart';
import 'package:oscar_financas/features/auth_gateway/application/auth_gateway_controller.dart';
import 'package:oscar_financas/features/auth_gateway/data/local_access_session_repository.dart';
import 'package:oscar_financas/shared/controllers/financial_visibility_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('future languages fall back to English splash art', () {
    expect(
      PhoneSplashArtwork.forLocale(const Locale('es', 'ES')),
      PhoneSplashArtwork.english,
    );
    expect(
      PhoneSplashArtwork.forLocale(const Locale('pt', 'BR')),
      PhoneSplashArtwork.portuguese,
    );
    expect(
      TabletSplashArtwork.forLocale(const Locale('es', 'ES')),
      TabletSplashArtwork.english,
    );
    expect(
      TabletSplashArtwork.forLocale(const Locale('pt', 'BR')),
      TabletSplashArtwork.portuguese,
    );
  });

  Future<({OscarFinancasApp app, AuthGatewayController auth})> createApp({
    Locale deviceLocale = const Locale('pt', 'BR'),
  }) async {
    SharedPreferences.setMockInitialValues({
      'history.personal-start.v1': true,
      'welcome.examples.seen.v1': true,
    });
    final storage = await SharedPreferences.getInstance();
    final auth = AuthGatewayController(
      sessionRepository: LocalAccessSessionRepository(storage),
      identityGateway: const DevelopmentIdentityGateway(),
    );
    await auth.restore();
    return (
      app: OscarFinancasApp(
        auth: auth,
        navigation: NavigationController(),
        preferences: AppPreferencesController(storage, deviceLocale),
        financialVisibility: FinancialVisibilityController(storage),
        servicesFactory: web.createAppServices,
      ),
      auth: auth,
    );
  }

  testWidgets('entry offers Google, Apple and guest access', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = await createApp();
    await tester.pumpWidget(fixture.app);
    await tester.pump(const Duration(milliseconds: 2100));
    await tester.pumpAndSettle();

    expect(find.text('Entrar com Google'), findsOneWidget);
    expect(find.text('Entrar com Apple'), findsOneWidget);
    expect(find.text('Continuar sem conta'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/images/oscar_splash_phone_pt.webp',
      ),
      findsOneWidget,
    );
  });

  testWidgets('English phone uses English splash and localized login', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = await createApp(deviceLocale: const Locale('en', 'US'));
    await tester.pumpWidget(fixture.app);
    await tester.pump(const Duration(milliseconds: 2100));
    await tester.pumpAndSettle();

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);
    expect(find.text('Continue without an account'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/images/oscar_splash_phone_pt.webp',
      ),
      findsNothing,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                PhoneSplashArtwork.english,
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'Portuguese portrait tablet uses its artwork on splash and login',
    (tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = await createApp();
      await tester.pumpWidget(fixture.app);

      final tabletArtwork = find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                TabletSplashArtwork.portuguese,
      );
      expect(tabletArtwork, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 2100));
      await tester.pumpAndSettle();

      expect(tabletArtwork, findsOneWidget);
      expect(find.text('Entrar com Google'), findsOneWidget);
      expect(find.text('Entrar com Apple'), findsOneWidget);
      expect(find.text('Continuar sem conta'), findsOneWidget);
    },
  );

  testWidgets('English portrait tablet uses English artwork and login', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(768, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = await createApp(deviceLocale: const Locale('en', 'US'));
    await tester.pumpWidget(fixture.app);

    final tabletArtwork = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName == TabletSplashArtwork.english,
    );
    expect(tabletArtwork, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2100));
    await tester.pumpAndSettle();

    expect(tabletArtwork, findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);
    expect(find.text('Continue without an account'), findsOneWidget);
  });

  testWidgets('guest access opens the app and the drawer includes My Account', (
    tester,
  ) async {
    final fixture = await createApp();
    await tester.pumpWidget(fixture.app);
    await tester.pump(const Duration(milliseconds: 2100));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar sem conta'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.menu), findsOneWidget);
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(AppDestination.values, hasLength(12));
    expect(
      AppDestination.values.indexOf(AppDestination.objectives),
      AppDestination.values.indexOf(AppDestination.investments) + 1,
    );
    expect(AppDestination.objectives.route, '/screen-4');
    expect(AppDestination.values.last, AppDestination.settings);
    expect(AppDestination.settings.route, '/screen-11');
    expect(
      AppDestination.values.indexOf(AppDestination.account),
      AppDestination.values.indexOf(AppDestination.club) + 1,
    );
    expect(find.text('Oscar Finanças'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.text('Objetivos'),
      ),
      findsOneWidget,
    );
    await tester.drag(
      find.descendant(of: find.byType(Drawer), matching: find.byType(ListView)),
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Minha Conta'));
    await tester.pumpAndSettle();
    expect(find.text('Dados do perfil'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('Cópia de segurança e recuperação'), findsOneWidget);
  });
}
