import 'package:flutter/widgets.dart';

enum SupportedAppLocale {
  ptBr(Locale('pt', 'BR'), 'Português (Brasil)'),
  enUs(Locale('en', 'US'), 'English (United States)'),
  deDe(Locale('de', 'DE'), 'Deutsch (Deutschland)'),
  frFr(Locale('fr', 'FR'), 'Français (France)'),
  hiIn(Locale('hi', 'IN'), 'हिन्दी (भारत)');

  const SupportedAppLocale(this.locale, this.nativeName);

  final Locale locale;
  final String nativeName;

  String get tag => '${locale.languageCode}-${locale.countryCode}';

  static SupportedAppLocale fromTag(String? tag) =>
      values.firstWhere((item) => item.tag == tag, orElse: () => ptBr);

  static SupportedAppLocale requireTag(String tag) {
    final language = tag.split(RegExp('[-_]')).first.toLowerCase();
    return values.firstWhere(
      (item) => item.locale.languageCode == language,
      orElse: () =>
          throw ArgumentError.value(tag, 'tag', 'Unsupported language'),
    );
  }

  static SupportedAppLocale resolve(Locale? deviceLocale) {
    return switch (deviceLocale?.languageCode) {
      'en' => enUs,
      'de' => deDe,
      'fr' => frFr,
      'hi' => hiIn,
      _ => ptBr,
    };
  }
}
