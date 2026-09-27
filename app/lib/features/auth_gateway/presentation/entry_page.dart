import 'package:flutter/material.dart' hide Text;
import 'package:oscar_financas/shared/widgets/localized_text.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/brand/product_identity.dart';
import '../../../core/brand/phone_splash_artwork.dart';
import '../../../core/localization/app_strings.dart';
import '../application/auth_gateway_controller.dart';
import '../domain/access_mode.dart';

final class EntryPage extends StatelessWidget {
  const EntryPage({super.key, required this.controller});

  final AuthGatewayController controller;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final locale = Localizations.localeOf(context);
    final size = MediaQuery.sizeOf(context);
    final phone = size.shortestSide < 600;
    final artwork = phone
        ? PhoneSplashArtwork.forLocale(locale)
        : size.height >= size.width
        ? TabletSplashArtwork.forLocale(locale)
        : null;
    if (artwork != null) {
      return _IllustratedEntryPage(
        controller: controller,
        strings: strings,
        artwork: artwork,
      );
    }
    return Scaffold(
      body: SafeArea(
        minimum: const EdgeInsets.all(24),
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) {
                  final busy =
                      controller.state.status == AuthGatewayStatus.signingIn;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.auto_graph_rounded,
                        size: 64,
                        color: AppColors.gold,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        ProductIdentity.appName,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ProductIdentity.tagline,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: AppColors.gold),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        strings.text('entry.welcome'),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 36),
                      _ProviderButton(
                        icon: Icons.g_mobiledata_rounded,
                        label: strings.text('entry.google'),
                        onPressed: busy
                            ? null
                            : () => controller.signIn(AccessMode.google),
                      ),
                      const SizedBox(height: 12),
                      _ProviderButton(
                        icon: Icons.apple,
                        label: strings.text('entry.apple'),
                        onPressed: busy
                            ? null
                            : () => controller.signIn(AccessMode.apple),
                      ),
                      const SizedBox(height: 18),
                      TextButton(
                        onPressed: busy
                            ? null
                            : controller.continueWithoutAccount,
                        child: Text(strings.text('entry.guest')),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock_outline, size: 18),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(strings.text('entry.disclaimer')),
                          ),
                        ],
                      ),
                      if (busy) ...[
                        const SizedBox(height: 24),
                        const LinearProgressIndicator(),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _IllustratedEntryPage extends StatelessWidget {
  const _IllustratedEntryPage({
    required this.controller,
    required this.strings,
    required this.artwork,
  });

  final AuthGatewayController controller;
  final AppStrings strings;
  final String artwork;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF102C48)),
        Image.asset(artwork, fit: BoxFit.fill),
        const Align(
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            heightFactor: 0.38,
            widthFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xE6092039)],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          minimum: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: ListenableBuilder(
                listenable: controller,
                builder: (context, _) {
                  final busy =
                      controller.state.status == AuthGatewayStatus.signingIn;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _LuxuryEntryButton(
                        icon: Icons.g_mobiledata_rounded,
                        label: strings.text('entry.google'),
                        onPressed: busy
                            ? null
                            : () => controller.signIn(AccessMode.google),
                      ),
                      const SizedBox(height: 10),
                      _LuxuryEntryButton(
                        icon: Icons.apple,
                        label: strings.text('entry.apple'),
                        onPressed: busy
                            ? null
                            : () => controller.signIn(AccessMode.apple),
                      ),
                      const SizedBox(height: 10),
                      _LuxuryEntryButton(
                        icon: null,
                        label: strings.text('entry.guest'),
                        onPressed: busy
                            ? null
                            : controller.continueWithoutAccount,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

final class _LuxuryEntryButton extends StatelessWidget {
  const _LuxuryEntryButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData? icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.gold,
      backgroundColor: const Color(0xF5080A0E),
      disabledForegroundColor: AppColors.gold.withValues(alpha: 0.45),
      side: const BorderSide(color: AppColors.gold, width: 1.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    ),
  );
}

final class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 26),
      label: Text(label),
    );
  }
}
