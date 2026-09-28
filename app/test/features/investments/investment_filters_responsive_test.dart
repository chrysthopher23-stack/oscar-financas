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
  testWidgets('investment search suggestions stay inside the viewport', (
    tester,
  ) async {
    const viewport = Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = viewport;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
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
    final searchField = find.byType(TextField).first;
    await tester.ensureVisible(searchField);
    await tester.pumpAndSettle();
    await tester.tap(searchField);
    await tester.enterText(searchField, 'MXRF11');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    final overlay = find.byKey(
      const ValueKey('investmentSearchResultsOverlay'),
    );
    expect(overlay, findsOneWidget);
    final overlayRect = tester.getRect(overlay);
    expect(overlayRect.top, greaterThanOrEqualTo(0));
    expect(overlayRect.left, greaterThanOrEqualTo(0));
    expect(overlayRect.right, lessThanOrEqualTo(viewport.width));
    expect(overlayRect.bottom, lessThanOrEqualTo(viewport.height));
    expect(overlayRect.height, lessThan(viewport.height * .5));

    final suggestions = find.descendant(
      of: overlay,
      matching: find.byType(ListView),
    );
    expect(suggestions, findsOneWidget);
    final scrollable = find.descendant(
      of: suggestions,
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.maxScrollExtent, 0);

    await tester.tap(
      find.text('MXRF11 · Maxi Renda Fundo de Investimento Imobiliário'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Confirmar posição'), findsWidgets);
    final sheet = find.byKey(const ValueKey('oscarBoundedModalSheet'));
    expect(sheet, findsOneWidget);
    final sheetRect = tester.getRect(sheet);
    expect(sheetRect.height, lessThanOrEqualTo(viewport.height * .88));
    expect(sheetRect.bottom, lessThanOrEqualTo(viewport.height));
    expect(tester.takeException(), isNull);
  });

  testWidgets('investment filters fit at 320 px without horizontal scroll', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 700);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
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
