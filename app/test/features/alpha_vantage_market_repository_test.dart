import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oscar_financas/core/money/money.dart';
import 'package:oscar_financas/features/screen_3_investments/data/alpha_vantage_market_repository.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/asset_family.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/asset_market_series.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/instrument_identity.dart';

void main() {
  const petrobras = InstrumentIdentity(
    providerAssetId: 'br-petr4',
    family: AssetFamily.equity,
    symbol: 'PETR4',
    officialName: 'Petrobras',
    exchangeMic: 'BVMF',
    countryCode: 'BR',
    currency: CurrencyCode.brl,
  );
  const infosys = InstrumentIdentity(
    providerAssetId: 'in-infy',
    family: AssetFamily.equity,
    symbol: 'INFY',
    officialName: 'Infosys Limited',
    exchangeMic: 'XNSE',
    countryCode: 'IN',
    currency: CurrencyCode.inr,
  );

  test('requests only unique held assets and maps the market suffix', () async {
    var calls = 0;
    final repository = AlphaVantageMarketRepository(
      apiKey: 'test-key',
      requestSpacing: Duration.zero,
      client: MockClient((request) async {
        calls++;
        expect(request.url.queryParameters['symbol'], 'PETR4.SAO');
        return http.Response('''{
          "Time Series (Daily)": {
            "2026-08-31": {"4. close": "31.25"},
            "2026-09-01": {"4. close": "32.10"}
          }
        }''', 200);
      }),
    );

    final result = await repository.latestFor([petrobras, petrobras]);

    expect(calls, 1);
    expect(result.keys, ['br-petr4']);
    expect(result['br-petr4']!.closeValuesMinor, [3125, 3210]);
    expect(result['br-petr4']!.status, AssetMarketSeriesStatus.current);
  });

  test('keeps the last valid series when the provider later fails', () async {
    var succeeds = true;
    final repository = AlphaVantageMarketRepository(
      apiKey: 'test-key',
      requestSpacing: Duration.zero,
      cacheLifetime: Duration.zero,
      client: MockClient((_) async {
        if (!succeeds) return http.Response('unavailable', 503);
        return http.Response('''{
          "Time Series (Daily)": {
            "2026-08-31": {"4. close": "31.25"},
            "2026-09-01": {"4. close": "32.10"}
          }
        }''', 200);
      }),
    );

    await repository.latestFor([petrobras]);
    succeeds = false;
    final cached = await repository.latestFor([petrobras]);

    expect(cached['br-petr4']!.closeValuesMinor, [3125, 3210]);
    expect(cached['br-petr4']!.status, AssetMarketSeriesStatus.cached);
  });

  test('uses Alpha Vantage BSE symbol for Infosys listed at NSE', () async {
    final repository = AlphaVantageMarketRepository(
      apiKey: 'test-key',
      requestSpacing: Duration.zero,
      client: MockClient((request) async {
        expect(request.url.queryParameters['symbol'], 'INFY.BSE');
        return http.Response('''{
          "Time Series (Daily)": {
            "2026-09-24": {"4. close": "1598.00"},
            "2026-09-25": {"4. close": "1602.50"}
          }
        }''', 200);
      }),
    );

    final result = await repository.latestFor([infosys]);
    expect(result['in-infy']?.closeValuesMinor, [159800, 160250]);
  });
}
