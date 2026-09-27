import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'app_locale.dart';
import 'language_brain.dart';

final class AppStrings {
  const AppStrings(this.locale);

  final SupportedAppLocale locale;

  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings)!;

  String text(String key, [Map<String, String> arguments = const {}]) =>
      LanguageBrain(locale).message(key, arguments);

  static const LocalizationsDelegate<AppStrings> delegate =
      _AppStringsDelegate();
}

final class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) => SupportedAppLocale.values.any(
    (item) => item.locale.languageCode == locale.languageCode,
  );

  @override
  Future<AppStrings> load(Locale locale) =>
      SynchronousFuture(AppStrings(SupportedAppLocale.resolve(locale)));

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}
