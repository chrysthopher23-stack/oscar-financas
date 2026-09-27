import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:oscar_financas/app/services/create_app_services_web.dart';
import 'package:oscar_financas/core/localization/app_locale.dart';
import 'package:oscar_financas/core/money/money.dart';
import 'package:oscar_financas/core/time/year_month.dart';
import 'package:oscar_financas/features/screen_3_investments/data/initial_asset_catalog.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/asset_catalog.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/asset_market_series.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/fx_quote_set.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/instrument_identity.dart';
import 'package:oscar_financas/features/screen_3_investments/presentation/investments_page.dart';
import 'package:oscar_financas/shared/controllers/financial_visibility_controller.dart';

import '../resumed_flows_test.dart' show host;

void main() {
  for (final locale in SupportedAppLocale.values) {
    testWidgets(
      '${locale.tag}: populated investments remain localized at 360px',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 740));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        SharedPreferences.setMockInitialValues({});
        final visibility = FinancialVisibilityController(
          await SharedPreferences.getInstance(),
        );
        addTearDown(visibility.dispose);
        final services = createAppServices();
        await services.ensureInitialDemoData(
          month: YearMonth.now(),
          currency: CurrencyCode.brl,
        );
        await tester.pumpWidget(
          host(
            locale,
            InvestmentsPage(
              onDestinationSelected: (_) {},
              visibilityController: visibility,
              repository: services.investmentRepository,
              catalog: const LocalAssetCatalogRepository(initialAssetCatalog),
              fxRepository: const OfflineDemonstrationFxRepository(),
              marketRepository: const _NoNetworkMarket(),
              currency: CurrencyCode.brl,
              actionsEnabled: true,
              onBlocked: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (var i = 0; i < 6; i++) {
          await tester.drag(find.byType(ListView).first, const Offset(0, -300));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}

final class _NoNetworkMarket implements AssetMarketRepository {
  const _NoNetworkMarket();
  @override
  Future<Map<String, AssetMarketSeries>> latestFor(
    List<InstrumentIdentity> identities, {
    bool includeHistory = true,
    bool forceRefresh = false,
  }) async => {};
}
