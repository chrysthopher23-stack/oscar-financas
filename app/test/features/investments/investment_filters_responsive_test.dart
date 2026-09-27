import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oscar_financas/app/theme/app_theme.dart';
import 'package:oscar_financas/core/localization/app_locale.dart';
import 'package:oscar_financas/core/localization/app_strings.dart';
import 'package:oscar_financas/core/money/money.dart';
import 'package:oscar_financas/core/time/year_month.dart';
import 'package:oscar_financas/features/screen_3_investments/data/initial_asset_catalog.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/asset_catalog.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/asset_market_series.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/fx_quote_set.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/instrument_identity.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/investment_position.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/investment_repository.dart';
import 'package:oscar_financas/features/screen_3_investments/presentation/investments_page.dart';
import 'package:oscar_financas/shared/controllers/financial_visibility_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('investment filters fit at 320 px without horizontal scroll', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final visibility = FinancialVisibilityController(
      await SharedPreferences.getInstance(),
    );
    addTearDown(visibility.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt', 'BR'),
        supportedLocales: SupportedAppLocale.values.map((e) => e.locale),
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light(),
        home: InvestmentsPage(
          onDestinationSelected: (_) {},
          visibilityController: visibility,
          repository: _EmptyInvestments(),
          catalog: const LocalAssetCatalogRepository(initialAssetCatalog),
          fxRepository: const OfflineDemonstrationFxRepository(),
          marketRepository: const _EmptyMarket(),
          currency: CurrencyCode.brl,
          actionsEnabled: true,
          onBlocked: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).first, const Offset(0, -420));
    await tester.pumpAndSettle();
    for (final label in const [
      'Renda Fixa',
      'Imobiliários',
      'Ações e ETFs',
      'Criptoativos',
    ]) {
      expect(
        find.ancestor(of: find.text(label), matching: find.byType(ChoiceChip)),
        findsOneWidget,
      );
    }
    expect(
      tester
          .widgetList<ListView>(find.byType(ListView))
          .every((list) => list.scrollDirection != Axis.horizontal),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}

final class _EmptyInvestments implements InvestmentRepository {
  @override
  Future<List<InvestmentPosition>> listForMonth(YearMonth month) async => [];

  @override
  Future<void> restore(String id) async {}

  @override
  Future<void> save(InvestmentPosition position) async {}

  @override
  Future<void> softDelete(String id, DateTime deletedAt) async {}
}

final class _EmptyMarket implements AssetMarketRepository {
  const _EmptyMarket();

  @override
  Future<Map<String, AssetMarketSeries>> latestFor(
    List<InstrumentIdentity> identities, {
    bool includeHistory = true,
    bool forceRefresh = false,
  }) async => {};
}
