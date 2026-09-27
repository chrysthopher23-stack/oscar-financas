import 'package:flutter_test/flutter_test.dart';
import 'package:oscar_financas/core/money/money.dart';
import 'package:oscar_financas/core/time/year_month.dart';
import 'package:oscar_financas/features/screen_3_investments/application/investments_view_model.dart';
import 'package:oscar_financas/features/screen_3_investments/data/initial_asset_catalog.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/asset_catalog.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/asset_family.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/asset_market_series.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/fx_quote_set.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/instrument_identity.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/investment_position.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/investment_repository.dart';
import 'package:oscar_financas/shared/controllers/month_controller.dart';

void main() {
  test(
    'past month uses recorded holdings and skips live market requests',
    () async {
      final past = YearMonth.now().addMonths(-1);
      final earlier = past.addMonths(-1);
      const bitcoin = InstrumentIdentity(
        providerAssetId: 'cmc-1',
        family: AssetFamily.crypto,
        symbol: 'BTC',
        officialName: 'Bitcoin',
        exchangeMic: 'CMC',
        countryCode: 'GLOBAL',
        currency: CurrencyCode.usd,
      );
      InvestmentPosition holding(String id, YearMonth month, int amount) =>
          InvestmentPosition(
            id: id,
            identity: bitcoin,
            principalMinor: amount,
            monthlyReturnMinor: 100,
            month: month,
            createdAt: DateTime.utc(2026, 1),
            updatedAt: DateTime.utc(2026, 1),
            quantity: '0.01',
          );
      final repository = _Holdings([
        holding('earlier', earlier, 10000),
        holding('past', past, 20000),
        holding('future', past.addMonths(1), 50000),
      ]);
      final market = _MarketCalls();
      final controller = MonthController(initialMonth: past);
      final viewModel = InvestmentsViewModel(
        repository: repository,
        catalog: const LocalAssetCatalogRepository(initialAssetCatalog),
        fxRepository: const OfflineDemonstrationFxRepository(),
        marketRepository: market,
        monthController: controller,
        baseCurrency: CurrencyCode.usd,
      );
      addTearDown(viewModel.dispose);
      addTearDown(controller.dispose);
      await viewModel.load(waitForMarket: true);
      expect(market.calls, 0);
      expect(viewModel.state.marketSeries, isEmpty);
      expect(viewModel.displayPositions, hasLength(2));
      expect(viewModel.totalValueMinor, 30200);
      expect(viewModel.recordedAssetHistories['cmc-1']!.last, 30200);
      expect(viewModel.portfolioHistory.last.month, past);
    },
  );
}

final class _Holdings implements InvestmentRepository {
  _Holdings(this.items);
  final List<InvestmentPosition> items;
  @override
  Future<List<InvestmentPosition>> listForMonth(YearMonth month) async =>
      items.where((item) => item.month.compareTo(month) <= 0).toList();
  @override
  Future<void> save(InvestmentPosition position) async {}
  @override
  Future<void> softDelete(String id, DateTime deletedAt) async {}
  @override
  Future<void> restore(String id) async {}
}

final class _MarketCalls implements AssetMarketRepository {
  int calls = 0;
  @override
  Future<Map<String, AssetMarketSeries>> latestFor(
    List<InstrumentIdentity> identities, {
    bool includeHistory = true,
    bool forceRefresh = false,
  }) async {
    calls++;
    return {};
  }
}
