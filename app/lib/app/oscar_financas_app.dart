import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/brand/product_identity.dart';
import '../core/brand/phone_splash_artwork.dart';
import '../core/localization/app_locale.dart';
import '../core/localization/app_strings.dart';
import '../features/auth_gateway/auth_gateway.dart';
import '../shared/controllers/financial_visibility_controller.dart';
import '../shared/scroll/invisible_scroll_behavior.dart';
import 'navigation/app_shell.dart';
import 'navigation/navigation_controller.dart';
import 'services/app_services.dart';
import 'settings/app_preferences_controller.dart';
import 'theme/app_theme.dart';

final class OscarFinancasApp extends StatefulWidget {
  const OscarFinancasApp({
    super.key,
    required this.auth,
    required this.navigation,
    required this.preferences,
    required this.financialVisibility,
    this.servicesFactory,
  });
  final AuthGatewayController auth;
  final NavigationController navigation;
  final AppPreferencesController preferences;
  final FinancialVisibilityController financialVisibility;
  final AppServices Function()? servicesFactory;
  @override
  State<OscarFinancasApp> createState() => _OscarFinancasAppState();
}

final class _OscarFinancasAppState extends State<OscarFinancasApp>
    with WidgetsBindingObserver {
  Timer? _splashTimer;
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _splashTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showSplash = false);
    });
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.preferences.hideValuesOnBackground &&
        (state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden)) {
      widget.financialVisibility.hide();
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.auth, widget.preferences]),
    builder: (context, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: ProductIdentity.appName,
      builder: (context, child) {
        if (!kIsWeb || child == null) return child ?? const SizedBox.shrink();
        final media = MediaQuery.of(context);
        return LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : media.size.width;
            final availableHeight = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : media.size.height;
            final useFullViewport =
                availableHeight <= 0 || availableWidth / availableHeight <= .75;
            final frameWidth = useFullViewport
                ? availableWidth
                : availableWidth
                      .clamp(0.0, availableHeight * .75)
                      .clamp(0.0, 768.0);
            final frameHeight = useFullViewport
                ? availableHeight
                : frameWidth / .75;
            final frameSize = Size(frameWidth, frameHeight);

            return ColoredBox(
              color: const Color(0xFF111315),
              child: Center(
                child: SizedBox.fromSize(
                  size: frameSize,
                  child: MediaQuery(
                    data: media.copyWith(size: frameSize),
                    child: child,
                  ),
                ),
              ),
            );
          },
        );
      },
      locale: widget.preferences.locale.locale,
      supportedLocales: SupportedAppLocale.values.map((item) => item.locale),
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (device, supported) {
        final resolved = SupportedAppLocale.resolve(device).locale;
        return supported.contains(resolved)
            ? resolved
            : const Locale('pt', 'BR');
      },
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: widget.preferences.themeMode,
      scrollBehavior: const InvisibleScrollBehavior(),
      home: _showSplash
          ? const _StartupPage()
          : switch (widget.auth.state.status) {
              AuthGatewayStatus.loading => const _StartupPage(),
              AuthGatewayStatus.signedIn => AppShell(
                navigation: widget.navigation,
                financialVisibility: widget.financialVisibility,
                preferences: widget.preferences,
                servicesFactory: widget.servicesFactory,
              ),
              _ => EntryPage(controller: widget.auth),
            },
    ),
  );
}

final class _StartupPage extends StatelessWidget {
  const _StartupPage();
  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final size = MediaQuery.sizeOf(context);
    final phone = size.shortestSide < 600;
    final artwork = phone
        ? PhoneSplashArtwork.forLocale(locale)
        : size.height >= size.width
        ? TabletSplashArtwork.forLocale(locale)
        : null;
    if (artwork != null) {
      return Scaffold(
        body: ColoredBox(
          color: const Color(0xFF102C48),
          child: SizedBox.expand(child: Image.asset(artwork, fit: BoxFit.fill)),
        ),
      );
    }
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
