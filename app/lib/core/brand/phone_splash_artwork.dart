import 'package:flutter/widgets.dart';

abstract final class PhoneSplashArtwork {
  static const portuguese = 'assets/images/oscar_splash_phone_pt.webp';
  static const english = 'assets/images/oscar_splash_phone_en.webp';

  static String forLocale(Locale locale) =>
      locale.languageCode == 'pt' ? portuguese : english;
}

abstract final class TabletSplashArtwork {
  static const portuguese = 'assets/images/oscar_splash_tablet_pt.webp';
  static const english = 'assets/images/oscar_splash_tablet_en.webp';

  static String forLocale(Locale locale) =>
      locale.languageCode == 'pt' ? portuguese : english;
}
