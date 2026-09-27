import 'package:flutter_test/flutter_test.dart';
import 'package:oscar_financas/core/money/money.dart';
import 'package:oscar_financas/core/time/year_month.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/asset_family.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/instrument_identity.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/investment_holding.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/investment_position.dart';

void main() {
  final september = const YearMonth(2026, 9);
  final august = const YearMonth(2026, 8);
  final now = DateTime.utc(2026, 9);

  InvestmentPosition position({
    required String id,
    required String providerId,
    required AssetFamily family,
    required String symbol,
    required int principal,
    required int returnMinor,
    String? quantity,
    YearMonth? month,
  }) => InvestmentPosition(
    id: id,
    identity: InstrumentIdentity(
      providerAssetId: providerId,
      family: family,
      symbol: symbol,
      officialName: symbol,
      exchangeMic: family == AssetFamily.crypto ? 'CMC' : 'XNAS',
      countryCode: family == AssetFamily.crypto ? 'GLOBAL' : 'US',
      currency: CurrencyCode.usd,
    ),
    principalMinor: principal,
    monthlyReturnMinor: returnMinor,
    quantity: quantity,
    month: month ?? september,
    createdAt: now,
    updatedAt: now,
  );

  test(
    'groups repeated lots by instrument and sums their values/quantities',
    () {
      final holdings = InvestmentHolding.group([
        position(
          id: 'aapl-1',
          providerId: 'US-AAPL',
          family: AssetFamily.equity,
          symbol: 'AAPL',
          principal: 10000,
          returnMinor: 500,
          month: august,
        ),
        position(
          id: 'aapl-2',
          providerId: 'us-aapl',
          family: AssetFamily.equity,
          symbol: 'AAPL',
          principal: 20000,
          returnMinor: -100,
        ),
        position(
          id: 'btc-1',
          providerId: 'cmc-1',
          family: AssetFamily.crypto,
          symbol: 'BTC',
          principal: 4000,
          returnMinor: 0,
          quantity: '0.125',
        ),
        position(
          id: 'btc-2',
          providerId: 'cmc-1',
          family: AssetFamily.crypto,
          symbol: 'BTC',
          principal: 6000,
          returnMinor: 0,
          quantity: '0.075',
        ),
      ]);

      expect(holdings, hasLength(2));
      final apple = holdings.singleWhere(
        (holding) => holding.identity.symbol == 'AAPL',
      );
      expect(apple.positions.map((item) => item.id), ['aapl-1', 'aapl-2']);
      expect(apple.principalMinor, 30000);
      expect(apple.monthlyReturnMinor, 400);
      expect(apple.currentValueMinor, 30400);

      final bitcoin = holdings.singleWhere(
        (holding) => holding.identity.symbol == 'BTC',
      );
      expect(bitcoin.quantity, '0.2');
      expect(bitcoin.currentValueMinor, 10000);
    },
  );

  test(
    'distinct instruments and families stay separate; removed lots are ignored',
    () {
      final holdings = InvestmentHolding.group([
        position(
          id: 'aapl',
          providerId: 'us-aapl',
          family: AssetFamily.equity,
          symbol: 'AAPL',
          principal: 100,
          returnMinor: 0,
        ),
        position(
          id: 'aapl-fund',
          providerId: 'us-aapl-fund',
          family: AssetFamily.etf,
          symbol: 'AAPL',
          principal: 100,
          returnMinor: 0,
        ),
      ]);

      expect(holdings, hasLength(2));
    },
  );
}
