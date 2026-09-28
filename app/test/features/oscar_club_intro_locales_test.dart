import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oscar_financas/app/theme/app_theme.dart';
import 'package:oscar_financas/core/localization/app_locale.dart';
import 'package:oscar_financas/core/localization/app_strings.dart';
import 'package:oscar_financas/core/localization/language_brain.dart';
import 'package:oscar_financas/features/screen_9_oscar_club/application/partner_catalog_port.dart';
import 'package:oscar_financas/features/screen_9_oscar_club/domain/partner_offer.dart';
import 'package:oscar_financas/features/screen_9_oscar_club/presentation/oscar_club_page.dart';

const _shortIntro =
    'Benefícios úteis e transparentes para apoiar sua educação, bem-estar e vida prática.';
const _oldIntro =
    'Benefícios úteis e transparentes para apoiar sua educação, bem-estar e vida prática. Ofertas nunca alteram seu Oscar Score nem acessam seus dados financeiros.';

void main() {
  for (final locale in SupportedAppLocale.values) {
    testWidgets('${locale.tag}: centered Oscar Club intro uses full width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final brain = LanguageBrain(locale);

      await tester.pumpWidget(
        MaterialApp(
          locale: locale.locale,
          theme: AppTheme.light(),
          supportedLocales: SupportedAppLocale.values.map(
            (item) => item.locale,
          ),
          localizationsDelegates: const [
            AppStrings.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: OscarClubPage(
            onDestinationSelected: (_) {},
            catalog: const _EmptyPartnerCatalog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final introCard = find.byType(Card).first;
      final copy = find.text(brain.message(_shortIntro));
      expect(tester.takeException(), isNull);
      expect(find.descendant(of: introCard, matching: copy), findsOneWidget);
      expect(tester.widget<Text>(copy).textAlign, TextAlign.center);
      expect(tester.widget<Text>(copy).maxLines, isNull);
      expect(
        find.descendant(
          of: introCard,
          matching: find.text(brain.message('Oscar Clube')),
        ),
        findsNothing,
      );
      expect(brain.messages.containsKey(_oldIntro), isFalse);
      expect(
        find.descendant(
          of: introCard,
          matching: find.byIcon(Icons.handshake_outlined),
        ),
        findsNothing,
      );
    });
  }
}

final class _EmptyPartnerCatalog implements PartnerCatalogPort {
  const _EmptyPartnerCatalog();

  @override
  Future<List<PartnerOffer>> availableOffers({
    required String countryCode,
  }) async => const [];
}
