import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oscar_financas/features/screen_3_investments/data/coinmarketcap_repository.dart';
import 'package:oscar_financas/features/screen_3_investments/data/initial_asset_catalog.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/asset_catalog.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/asset_family.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/asset_market_series.dart';

void main() {
  test(
    'catalog searches every listed family and BHIA3 by partial ticker',
    () async {
      const catalog = LocalAssetCatalogRepository(initialAssetCatalog);
      for (final family in AssetFamily.values.where(
        (e) => e != AssetFamily.otherManual,
      )) {
        final examples = initialAssetCatalog.where((e) => e.family == family);
        expect(examples, isNotEmpty, reason: family.name);
        final asset = examples.first;
        expect(
          (await catalog.search(asset.symbol))
              .any((e) => e.providerAssetId == asset.providerAssetId),
          isTrue,
        );
      }
      expect(
        (await catalog.search('bhi')).any((e) => e.symbol == 'BHIA3'),
        isTrue,
      );
      expect(
        (await catalog.search('bitcoin'))
            .any((e) => e.providerAssetId == 'cmc-1'),
        isTrue,
      );
    },
  );
  test('only held crypto IDs are sent once; failed and absent responses keep cached status', () async {
    var requests = 0;
    var mode = 0;
    final repository = CoinMarketCapRepository(
      baseUri: Uri.parse('http://localhost/'),
      client: MockClient((request) async {
        requests++;
        expect(request.url.queryParameters['ids'], '1');
        if (mode == 1) return http.Response('unavailable', 503);
        return http.Response(
          jsonEncode({
            'data': mode == 2
                ? []
                : [
                    {
                      'id': '1',
                      'priceUsd': '60000.123456',
                      'change24h': 1.25,
                      'observedAt': '2026-09-19T12:00:00Z',
                      'stale': false,
                      'history': [
                        {'price': '60000.123456'},
                      ],
                    },
                  ],
          }),
          200,
        );
      }),
    );
    final btc = initialAssetCatalog.firstWhere(
      (e) => e.providerAssetId == 'cmc-1',
    );
    final stock = initialAssetCatalog.firstWhere(
      (e) => e.family == AssetFamily.equity,
    );
    expect(await repository.latestFor([]), isEmpty);
    expect(await repository.latestFor([stock]), isEmpty);
    expect(requests, 0);
    final fresh = await repository.latestFor([btc, btc, stock]);
    expect(requests, 1);
    expect(fresh.keys, ['cmc-1']);
    expect(fresh['cmc-1']!.unitPriceUsd, '60000.123456');
    expect(fresh['cmc-1']!.status, AssetMarketSeriesStatus.current);
    for (mode = 1; mode <= 2; mode++) {
      final stale = await repository.latestFor([btc]);
      expect(stale['cmc-1']!.status, AssetMarketSeriesStatus.cached);
      expect(stale['cmc-1']!.unitPriceUsd, '60000.123456');
    }
  });
}
