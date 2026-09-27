import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:oscar_financas/core/localization/app_locale.dart';
import 'package:oscar_financas/shared/widgets/localized_text.dart';

void main() {
  test('reviewed static product copy is available in all five locales', () {
    final phrases = <String>{};
    final root = Directory('lib/features');
    final pattern = RegExp(r"Text\(\s*'([^'\$]*)'", multiLine: true);
    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (!entity.path.replaceAll('\\', '/').contains('/presentation/')) {
        continue;
      }
      final source = entity.readAsStringSync();
      for (final match in pattern.allMatches(source)) {
        final phrase = match.group(1)!.replaceAll(r'\n', '\n');
        if (phrase.trim().isNotEmpty) phrases.add(phrase);
      }
    }
    const universal = {
      'Oscar Finanças',
      'Oscar Score',
      '100%',
      r'R$',
      r'$',
      '€',
      '₹',
      '••••',
      '−',
      '+',
    };
    final missing = <String>[];
    for (final locale in SupportedAppLocale.values.where(
      (item) => item != SupportedAppLocale.ptBr,
    )) {
      for (final phrase in phrases) {
        if (universal.contains(phrase)) continue;
        if (uiTextForLocale(locale, phrase) == phrase) {
          missing.add('${locale.tag}: $phrase');
        }
      }
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
  });

  test('unsupported locale resolves only to the configured fallback', () {
    expect(
      SupportedAppLocale.resolve(const Locale('ru', 'RU')),
      SupportedAppLocale.ptBr,
    );
    expect(
      SupportedAppLocale.resolve(const Locale('hi', 'FJ')),
      SupportedAppLocale.hiIn,
    );
  });

  test('empty-score guidance is translated in every supported locale', () {
    const source = 'Cadastre uma entrada para calcular seu Oscar Score.';
    const expected = {
      SupportedAppLocale.ptBr:
          'Cadastre uma entrada para calcular seu Oscar Score.',
      SupportedAppLocale.enUs: 'Add an income to calculate your Oscar Score.',
      SupportedAppLocale.deDe:
          'Erfassen Sie Einnahmen, um Ihren Oscar Score zu berechnen.',
      SupportedAppLocale.frFr:
          'Ajoutez un revenu pour calculer votre Oscar Score.',
      SupportedAppLocale.hiIn: 'अपना Oscar Score जानने के लिए आय दर्ज करें।',
    };
    for (final locale in SupportedAppLocale.values) {
      expect(uiTextForLocale(locale, source), expected[locale]);
    }
  });
}
