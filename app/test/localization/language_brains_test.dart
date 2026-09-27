import 'package:flutter_test/flutter_test.dart';
import 'package:oscar_financas/core/localization/app_locale.dart';
import 'package:oscar_financas/core/localization/language_brain.dart';

void main() {
  test('all language brains have the same complete contract', () {
    final expected = const LanguageBrain(SupportedAppLocale.ptBr).messages.keys
        .toSet();
    for (final locale in SupportedAppLocale.values) {
      final brain = LanguageBrain(locale);
      expect(brain.messages.keys.toSet(), expected, reason: locale.tag);
      expect(
        brain.messages.values.every((value) => value.trim().isNotEmpty),
        isTrue,
      );
      expect(() => brain.message('missing.key'), throwsStateError);
    }
  });
  test('parameters preserve user names even when they match product copy', () {
    for (final locale in SupportedAppLocale.values) {
      final brain = LanguageBrain(locale);
      expect(
        brain.message('Cadastrar “{name}” manualmente', {
          'name': 'Gastos Petrobras Apple',
        }),
        contains('Gastos Petrobras Apple'),
      );
    }
  });

  test('home summary uses the requested title casing across locales', () {
    expect(
      const LanguageBrain(SupportedAppLocale.enUs)
          .message('Resumo de {month}', {'month': 'September'}),
      'September Summary',
    );
    expect(
      const LanguageBrain(SupportedAppLocale.frFr)
          .message('home.block.financial'),
      'Tableau de Bord Financier',
    );
    expect(
      const LanguageBrain(SupportedAppLocale.frFr)
          .message('home.block.extraIncome'),
      'Revenus Supplémentaires',
    );
    expect(
      const LanguageBrain(SupportedAppLocale.hiIn)
          .message('home.block.objectives'),
      'लक्ष्य',
    );
  });
}
