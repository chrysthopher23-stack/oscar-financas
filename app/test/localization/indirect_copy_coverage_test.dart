import 'package:flutter_test/flutter_test.dart';
import 'package:oscar_financas/core/localization/app_locale.dart';
import 'package:oscar_financas/shared/widgets/localized_global_completion.dart';
import 'package:oscar_financas/shared/widgets/localized_legal_body_catalog.dart';
import 'package:oscar_financas/shared/widgets/localized_stage5_catalog.dart';
import 'package:oscar_financas/shared/widgets/localized_text.dart';

void main() {
  test('list, card and legal copy is translated in every released locale', () {
    final phrases = <String>{
      ...stage5UiTranslations[SupportedAppLocale.enUs]!.keys,
      ...localizedLegalBodies[SupportedAppLocale.deDe]!.keys,
      ...globalUiTranslations[SupportedAppLocale.enUs]!.keys,
    };
    final missing = <String>[];
    for (final locale in SupportedAppLocale.values) {
      if (locale == SupportedAppLocale.ptBr) continue;
      for (final phrase in phrases) {
        if (uiTextForLocale(locale, phrase) == phrase) {
          missing.add('${locale.tag}: $phrase');
        }
      }
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
  });

  test('dynamic interface copy translates without changing user content', () {
    for (final locale in SupportedAppLocale.values.where(
      (item) => item != SupportedAppLocale.ptBr,
    )) {
      expect(
        () => uiTextForLocale(locale, 'Meu aluguel especial'),
        throwsStateError,
      );
      expect(
        uiTextForLocale(
          locale,
          'Meu aluguel especial · 10 será removido deste mês.',
        ),
        contains('Meu aluguel especial'),
      );
      expect(
        uiTextForLocale(locale, 'Fluxo do mês: Não calculado'),
        isNot('Fluxo do mês: Não calculado'),
      );
    }
  });
}
