import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/auth_gateway/application/auth_gateway_controller.dart';
import '../features/auth_gateway/data/local_access_session_repository.dart';
import '../shared/controllers/financial_visibility_controller.dart';
import 'navigation/navigation_controller.dart';
import 'oscar_financas_app.dart';
import 'settings/app_preferences_controller.dart';

final class AppBootstrap {
  AppBootstrap._({
    required this.auth,
    required this.navigation,
    required this.preferences,
    required this.financialVisibility,
  });
  final AuthGatewayController auth;
  final NavigationController navigation;
  final AppPreferencesController preferences;
  final FinancialVisibilityController financialVisibility;

  static Future<AppBootstrap> create() async {
    final storage = await SharedPreferences.getInstance();
    final deviceLocale = PlatformDispatcher.instance.locale;
    final auth = AuthGatewayController(
      sessionRepository: LocalAccessSessionRepository(storage),
      identityGateway: const DevelopmentIdentityGateway(),
    );
    final preferences = AppPreferencesController(storage, deviceLocale);
    final visibility = FinancialVisibilityController(storage);
    if (preferences.hideValuesOnOpen) await visibility.hide();
    final bootstrap = AppBootstrap._(
      auth: auth,
      navigation: NavigationController(),
      preferences: preferences,
      financialVisibility: visibility,
    );
    await auth.restore();
    return bootstrap;
  }

  Widget buildApp() => OscarFinancasApp(
    auth: auth,
    navigation: navigation,
    preferences: preferences,
    financialVisibility: financialVisibility,
  );
}
