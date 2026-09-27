import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oscar_financas/core/money/money.dart';
import 'package:oscar_financas/features/screen_3_investments/data/hg_brasil_market_repository.dart';
import 'package:oscar_financas/features/screen_3_investments/data/routed_asset_market_repository.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/asset_family.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/asset_market_series.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/instrument_identity.dart';

void main() {
  const brazilian = InstrumentIdentity(
    providerAssetId: 'br-petr4',
    family: AssetFamily.equity,
    symbol: 'PETR4',
    officialName: 'Petrobras',
    exchangeMic: 'BVMF',
    countryCode: 'BR',
    currency: CurrencyCode.brl,
  );
  const international = InstrumentIdentity(
    providerAssetId: 'us-bnd',
    family: AssetFamily.etf,
    symbol: 'BND',
    officialName: 'Vanguard Total Bond Market ETF',
    exchangeMic: 'ARCX',
    countryCode: 'US',
    currency: CurrencyCode.usd,
  );

  test('HG requests only unique Brazilian holdings', () async {
    var calls = 0;
    final repository = HgBrasilMarketRepository(
      apiKey: 'test-key',
      client: MockClient((request) async {
        calls++;
        expect(request.url.queryParameters['symbol'], 'PETR4');
        return http.Response('''{
          "valid_key": true,
          "results": {
            "PETR4": {
              "price": 31.50,
              "change_percent": 5.0,
              "updated_at": "2026-09-07 12:00:00"
            }
          }
        }''', 200);
      }),
    );

    final result = await repository.latestFor([
      brazilian,
      brazilian,
      international,
    ]);

    expect(calls, 1);
    expect(result.keys, ['br-petr4']);
    expect(result['br-petr4']!.closeValuesMinor, [3000, 3150]);
  });

  test('routes Brazil to HG and international holdings to Alpha', () async {
    final hg = _RecordingRepository({'br-petr4': _series(brazilian)});
    final alpha = _RecordingRepository({'us-bnd': _series(international)});
    final repository = RoutedAssetMarketRepository(
      brazilianRepository: hg,
      globalRepository: alpha,
    );

    final result = await repository.latestFor([
      brazilian,
      brazilian,
      international,
    ]);

    expect(hg.requested.single.map((item) => item.symbol), ['PETR4']);
    expect(alpha.requested.single.map((item) => item.symbol), ['BND']);
    expect(result.keys, containsAll(['br-petr4', 'us-bnd']));
  });

  test('uses Alpha only when HG cannot provide a Brazilian quote', () async {
    final hg = _RecordingRepository({});
    final alpha = _RecordingRepository({'br-petr4': _series(brazilian)});
    final repository = RoutedAssetMarketRepository(
      brazilianRepository: hg,
      globalRepository: alpha,
    );

    final result = await repository.latestFor([brazilian]);

    expect(hg.requested.single.single.symbol, 'PETR4');
    expect(alpha.requested.single.single.symbol, 'PETR4');
    expect(result, contains('br-petr4'));
  });
}

AssetMarketSeries _series(InstrumentIdentity identity) => AssetMarketSeries(
  identity: identity,
  closeValuesMinor: const [100, 110],
  observedAt: DateTime(2026, 9, 7),
  status: AssetMarketSeriesStatus.current,
);

final class _RecordingRepository implements AssetMarketRepository {
  _RecordingRepository(this.responses);

  final Map<String, AssetMarketSeries> responses;
  final List<List<InstrumentIdentity>> requested = [];

  @override
  Future<Map<String, AssetMarketSeries>> latestFor(
    List<InstrumentIdentity> identities, {
    bool includeHistory = true,
    bool forceRefresh = false,
  }) async {
    requested.add(List.of(identities));
    return {
      for (final identity in identities)
        if (responses.containsKey(identity.providerAssetId))
          identity.providerAssetId: responses[identity.providerAssetId]!,
    };
  }
}
