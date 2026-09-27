import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oscar_financas/app/settings/app_preferences_controller.dart';
import 'package:oscar_financas/app/history_experience_copy.dart';
import 'package:oscar_financas/app/theme/app_theme.dart';
import 'package:oscar_financas/core/localization/app_locale.dart';
import 'package:oscar_financas/core/localization/app_strings.dart';
import 'package:oscar_financas/core/money/money.dart';
import 'package:oscar_financas/core/time/year_month.dart';
import 'package:oscar_financas/features/screen_0_home/presentation/home_page.dart';
import 'package:oscar_financas/features/screen_1_financial/domain/financial_repository.dart';
import 'package:oscar_financas/features/screen_1_financial/domain/financial_transaction.dart';
import 'package:oscar_financas/features/screen_2_extra_income/domain/extra_income_entry.dart';
import 'package:oscar_financas/features/screen_2_extra_income/domain/extra_income_repository.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/asset_market_series.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/fx_quote_set.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/instrument_identity.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/investment_position.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/investment_repository.dart';
import 'package:oscar_financas/features/screen_4_objectives/domain/financial_objective.dart';
import 'package:oscar_financas/features/screen_4_objectives/domain/objective_repository.dart';
import 'package:oscar_financas/shared/controllers/financial_visibility_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final language in SupportedAppLocale.values) {
    testWidgets('welcome opens in ${language.tag}', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final shared = await SharedPreferences.getInstance();
      final preferences = AppPreferencesController(shared, language.locale);
      final visibility = FinancialVisibilityController(shared);
      final copy = HistoryExperienceCopy(language);
      await tester.pumpWidget(
        MaterialApp(
          locale: preferences.locale.locale,
          supportedLocales: SupportedAppLocale.values.map(
            (item) => item.locale,
          ),
          localizationsDelegates: const [
            AppStrings.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.light(),
          home: HomePage(
            onDestinationSelected: (_) {},
            visibilityController: visibility,
            preferences: preferences,
            financialRepository: _FinancialRepository(),
            extraIncomeRepository: _ExtraIncomeRepository(),
            investmentRepository: _InvestmentRepository(),
            objectiveRepository: _ObjectiveRepository([]),
            assetMarketRepository: _AssetMarketRepository(),
            fxRepository: _FxRepository(),
            initialData: Future<void>.value(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(copy.welcomeTitle), findsOneWidget);
      expect(find.text(copy.welcomeBody), findsOneWidget);
      expect(find.text(copy.explore), findsOneWidget);
      expect(
        find.text(HistoryExperienceCopy(SupportedAppLocale.ptBr).welcomeTitle),
        language == SupportedAppLocale.ptBr ? findsOneWidget : findsNothing,
      );
      await tester.tap(find.text(copy.explore));
      await tester.pumpAndSettle();
      expect(find.text(copy.welcomeTitle), findsNothing);
      expect(shared.getBool('welcome.examples.seen.v1'), isTrue);
      preferences.dispose();
      visibility.dispose();
    });
  }

  testWidgets('home objective summary stays content-sized on a narrow screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final shared = await SharedPreferences.getInstance();
    final preferences = AppPreferencesController(
      shared,
      const Locale('pt', 'BR'),
    );
    final visibility = FinancialVisibilityController(shared);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt', 'BR'),
        supportedLocales: SupportedAppLocale.values.map((item) => item.locale),
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light(),
        home: HomePage(
          onDestinationSelected: (_) {},
          visibilityController: visibility,
          preferences: preferences,
          financialRepository: _FinancialRepository(),
          extraIncomeRepository: _ExtraIncomeRepository(),
          investmentRepository: _InvestmentRepository(),
          objectiveRepository: _ObjectiveRepository([
            FinancialObjective(
              id: 'emergency',
              name: 'Reserva de emergência',
              instrument: 'Treasury',
              targetMonths: 6,
              initialBalanceMinor: 0,
              targetAmountMinor: 2000000,
              annualRateBasisPoints: 400,
              monthlyContributionMinor: 30000,
              frequency: ObjectiveContributionFrequency.monthly,
              startMonth: const YearMonth(2026, 4),
              currency: CurrencyCode.brl,
            ),
            FinancialObjective(
              id: 'world-trip',
              name: 'Viajar pelo mundo em 80 dias',
              instrument: 'Savings',
              targetMonths: 12,
              initialBalanceMinor: 10000,
              targetAmountMinor: 800000,
              annualRateBasisPoints: 0,
              monthlyContributionMinor: 20000,
              frequency: ObjectiveContributionFrequency.monthly,
              startMonth: const YearMonth(2026, 8),
              currency: CurrencyCode.brl,
            ),
          ]),
          assetMarketRepository: _AssetMarketRepository(),
          fxRepository: _FxRepository(),
          initialData: Future<void>.value(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Reserva de emergência'));
    await tester.ensureVisible(find.text('Viajar pelo mundo em 80 dias'));
    await tester.pumpAndSettle();

    expect(find.text('Reserva de emergência'), findsOneWidget);
    expect(find.text('Viajar pelo mundo em 80 dias'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final nameSize = tester.getSize(find.text('Reserva de emergência'));
    expect(nameSize.height, lessThan(80));

    preferences.dispose();
    visibility.dispose();
  });
}

final class _FinancialRepository extends Fake implements FinancialRepository {
  @override
  Future<List<FinancialTransaction>> transactionsFor(YearMonth month) async =>
      [];

  @override
  Future<List<FinancialTransaction>> materializeRecurringTransactions(
    YearMonth month,
    CurrencyCode currency,
  ) async => [];
}

final class _ExtraIncomeRepository extends Fake
    implements ExtraIncomeRepository {
  @override
  Future<List<ExtraIncomeEntry>> entriesFor(YearMonth month) async => [];
}

final class _InvestmentRepository extends Fake implements InvestmentRepository {
  @override
  Future<List<InvestmentPosition>> listForMonth(YearMonth month) async => [];
}

final class _ObjectiveRepository extends Fake implements ObjectiveRepository {
  _ObjectiveRepository(this.objectives);
  final List<FinancialObjective> objectives;

  @override
  Future<List<FinancialObjective>> loadAll() async => objectives;
}

final class _AssetMarketRepository extends Fake
    implements AssetMarketRepository {
  @override
  Future<Map<String, AssetMarketSeries>> latestFor(
    List<InstrumentIdentity> identities, {
    bool includeHistory = true,
    bool forceRefresh = false,
  }) async => {};
}

final class _FxRepository extends Fake implements FxRepository {
  @override
  Future<FxQuoteSet?> latest(
    CurrencyCode base, {
    bool forceRefresh = false,
  }) async => null;
}
