import 'package:flutter_test/flutter_test.dart';
import 'package:oscar_financas/core/money/money.dart';
import 'package:oscar_financas/core/time/year_month.dart';
import 'package:oscar_financas/features/screen_0_home/application/home_investment_totals.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/asset_family.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/asset_market_series.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/instrument_identity.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/investment_position.dart';

void main() {
  final month = const YearMonth(2026, 9);

  InvestmentPosition position({
    required String id,
    required AssetFamily family,
    required int principal,
    required int monthlyReturn,
    String? quantity,
    bool deleted = false,
  }) {
    final now = DateTime.utc(2026, 9);
    return InvestmentPosition(
      id: id,
      identity: InstrumentIdentity(
        providerAssetId: id,
        family: family,
        symbol: id,
        officialName: id,
        exchangeMic: family == AssetFamily.crypto ? 'CMC' : 'MANUAL',
        countryCode: 'US',
        currency: CurrencyCode.usd,
      ),
      principalMinor: principal,
      monthlyReturnMinor: monthlyReturn,
      quantity: quantity,
      month: month,
      createdAt: now,
      updatedAt: now,
      deletedAt: deleted ? now : null,
    );
  }

  test('separates assets and crypto and calculates monthly asset return', () {
    final totals = HomeInvestmentTotals.fromPositions(
      [
        position(
          id: 'stock-1',
          family: AssetFamily.equity,
          principal: 100000,
          monthlyReturn: 2400,
        ),
        position(
          id: 'bond-1',
          family: AssetFamily.bankFixedIncome,
          principal: 50000,
          monthlyReturn: 1200,
        ),
        position(
          id: 'crypto-1',
          family: AssetFamily.crypto,
          principal: 5000,
          monthlyReturn: 0,
          quantity: '1',
        ),
        position(
          id: 'removed',
          family: AssetFamily.crypto,
          principal: 4000,
          monthlyReturn: 0,
          deleted: true,
        ),
      ],
      baseCurrency: CurrencyCode.usd,
      fx: null,
    );

    expect(totals.assetsCount, 2);
    expect(totals.assetsValueMinor, 153600);
    expect(totals.assetsMonthlyChangeBasisPoints, 240);
    expect(totals.cryptoCount, 1);
    expect(totals.cryptoValueMinor, 5000);
    expect(totals.totalValueMinor, 158600);
    expect(totals.cryptoDailyChangeBasisPoints, isNull);
  });

  test('uses current crypto value and weighted 24-hour market movement', () {
    final crypto = position(
      id: 'crypto-1',
      family: AssetFamily.crypto,
      principal: 5000,
      monthlyReturn: 0,
      quantity: '0.5',
    );
    final totals =
        HomeInvestmentTotals.fromPositions(
          [crypto],
          baseCurrency: CurrencyCode.usd,
          fx: null,
        ).withCryptoMarketData({
          'crypto-1': AssetMarketSeries(
            identity: crypto.identity,
            closeValuesMinor: const [],
            observedAt: DateTime.utc(2026, 9),
            status: AssetMarketSeriesStatus.current,
            unitPriceUsd: '200',
            dayChangeBasisPoints: -110,
          ),
        });

    expect(totals.cryptoValueMinor, 10000);
    expect(totals.cryptoDailyChangeBasisPoints, -110);
    expect(totals.totalValueMinor, 10000);
  });

  test('does not show a partial crypto movement as a portfolio total', () {
    final first = position(
      id: 'crypto-1',
      family: AssetFamily.crypto,
      principal: 5000,
      monthlyReturn: 0,
      quantity: '1',
    );
    final second = position(
      id: 'crypto-2',
      family: AssetFamily.crypto,
      principal: 5000,
      monthlyReturn: 0,
      quantity: '1',
    );
    final totals =
        HomeInvestmentTotals.fromPositions(
          [first, second],
          baseCurrency: CurrencyCode.usd,
          fx: null,
        ).withCryptoMarketData({
          'crypto-1': AssetMarketSeries(
            identity: first.identity,
            closeValuesMinor: const [],
            observedAt: DateTime.utc(2026, 9),
            status: AssetMarketSeriesStatus.current,
            unitPriceUsd: '200',
            dayChangeBasisPoints: 140,
          ),
        });

    expect(totals.cryptoCount, 2);
    expect(totals.cryptoDailyChangeBasisPoints, isNull);
  });

  test('counts unique instruments while summing every saved position', () {
    final firstLot = position(
      id: 'aapl-lot-1',
      family: AssetFamily.equity,
      principal: 10000,
      monthlyReturn: 200,
    );
    final secondLot = InvestmentPosition(
      id: 'aapl-lot-2',
      identity: InstrumentIdentity(
        providerAssetId: firstLot.identity.providerAssetId,
        family: firstLot.identity.family,
        symbol: firstLot.identity.symbol,
        officialName: firstLot.identity.officialName,
        exchangeMic: firstLot.identity.exchangeMic,
        countryCode: firstLot.identity.countryCode,
        currency: firstLot.identity.currency,
      ),
      principalMinor: 20000,
      monthlyReturnMinor: 300,
      month: month,
      createdAt: DateTime.utc(2026, 9),
      updatedAt: DateTime.utc(2026, 9),
    );

    final totals = HomeInvestmentTotals.fromPositions(
      [firstLot, secondLot],
      baseCurrency: CurrencyCode.usd,
      fx: null,
    );

    expect(totals.assetsCount, 1);
    expect(totals.assetsValueMinor, 30500);
  });
}
