import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oscar_financas/core/cache/cache_store.dart';
import 'package:oscar_financas/core/money/money.dart';
import 'package:oscar_financas/features/screen_3_investments/data/awesome_api_fx_repository.dart';
import 'package:oscar_financas/features/screen_3_investments/data/persistent_asset_market_repository.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/asset_family.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/asset_market_series.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/fx_quote_set.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/instrument_identity.dart';

void main() {
  test('20 app openings in six hours use one FX provider request', () async {
    final store = _MemoryStore();
    var now = DateTime.utc(2026, 9, 25, 12);
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response(
        '{"USDBRL":{"bid":"5.20"},"EURBRL":{"bid":"6.10"},"INRBRL":{"bid":"0.062"}}',
        200,
      );
    });
    AwesomeApiFxRepository repository() => AwesomeApiFxRepository(
      apiKey: 'test-key',
      client: client,
      cacheStore: store,
      clock: () => now,
    );

    final first = repository();
    final simultaneous = await Future.wait([
      first.latest(CurrencyCode.brl),
      first.latest(CurrencyCode.usd),
    ]);
    expect(simultaneous.first!.status, QuoteStatus.current);
    expect(calls, 1);
    for (var opening = 0; opening < 20; opening++) {
      expect(
        (await repository().latest(CurrencyCode.eur))!.status,
        QuoteStatus.cached,
      );
    }
    expect(calls, 1);

    now = now.add(const Duration(hours: 6, seconds: 1));
    expect(
      (await repository().latest(CurrencyCode.brl))!.status,
      QuoteStatus.current,
    );
    expect(calls, 2);
  });

  test('provider failure has a persisted retry cooldown', () async {
    final store = _MemoryStore();
    var now = DateTime.utc(2026, 9, 25, 12);
    var calls = 0;
    var fail = false;
    final client = MockClient((_) async {
      calls++;
      return fail
          ? http.Response('unavailable', 503)
          : http.Response(
              '{"USDBRL":{"bid":"5.20"},"EURBRL":{"bid":"6.10"},"INRBRL":{"bid":"0.062"}}',
              200,
            );
    });
    AwesomeApiFxRepository repository() => AwesomeApiFxRepository(
      apiKey: 'test-key',
      client: client,
      cacheStore: store,
      clock: () => now,
    );

    await repository().latest(CurrencyCode.brl);
    now = now.add(const Duration(hours: 7));
    fail = true;
    expect(
      (await repository().latest(CurrencyCode.brl))!.status,
      QuoteStatus.cached,
    );
    for (var opening = 0; opening < 20; opening++) {
      await repository().latest(CurrencyCode.brl);
    }
    expect(calls, 2);
  });

  test('FX failure before the first cache is cooled down across app openings', () async {
    final store = _MemoryStore();
    var now = DateTime.utc(2026, 9, 25, 12);
    var calls = 0;
    var fail = true;
    final client = MockClient((_) async {
      calls++;
      return fail
          ? http.Response('unavailable', 503)
          : http.Response(
              '{"USDBRL":{"bid":"5.20"},"EURBRL":{"bid":"6.10"},"INRBRL":{"bid":"0.062"}}',
              200,
            );
    });
    AwesomeApiFxRepository repository() => AwesomeApiFxRepository(
      apiKey: 'test-key',
      client: client,
      cacheStore: store,
      clock: () => now,
    );

    await repository().latest(CurrencyCode.brl);
    for (var opening = 0; opening < 20; opening++) {
      await repository().latest(CurrencyCode.brl);
    }
    expect(calls, 1);

    now = now.add(const Duration(minutes: 30, seconds: 1));
    fail = false;
    expect(
      (await repository().latest(CurrencyCode.brl))?.status,
      QuoteStatus.current,
    );
    expect(calls, 2);
  });

  test('20 app openings reuse stored market quotes', () async {
    final store = _MemoryStore();
    var now = DateTime.utc(2026, 9, 25, 12);
    final provider = _CountingMarket(() => now);
    PersistentAssetMarketRepository repository() =>
        PersistentAssetMarketRepository(
          delegate: provider,
          store: store,
          clock: () => now,
        );

    await repository().latestFor([_stock]);
    for (var opening = 0; opening < 20; opening++) {
      final result = await repository().latestFor([_stock]);
      expect(
        result[_stock.providerAssetId]!.status,
        AssetMarketSeriesStatus.cached,
      );
    }
    expect(provider.calls, 1);
    now = now.add(const Duration(hours: 6, seconds: 1));
    await repository().latestFor([_stock]);
    expect(provider.calls, 2);
  });

  test('manual FX update waits six hours after a successful quote', () async {
    final store = _MemoryStore();
    var now = DateTime.utc(2026, 9, 25, 12);
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response(
        '{"USDBRL":{"bid":"5.20"},"EURBRL":{"bid":"6.10"},"INRBRL":{"bid":"0.062"}}',
        200,
      );
    });
    AwesomeApiFxRepository repository() => AwesomeApiFxRepository(
      apiKey: 'test-key',
      client: client,
      cacheStore: store,
      clock: () => now,
    );

    await repository().latest(CurrencyCode.brl);
    await repository().latest(CurrencyCode.brl, forceRefresh: true);
    expect(calls, 1);
    for (var tap = 0; tap < 20; tap++) {
      await repository().latest(CurrencyCode.brl, forceRefresh: true);
    }
    expect(calls, 1);
    now = now.add(const Duration(hours: 6, seconds: 1));
    await repository().latest(CurrencyCode.brl, forceRefresh: true);
    expect(calls, 2);
    expect(
      await repository().nextRefreshAt(),
      now.add(const Duration(hours: 6)),
    );
  });

  test(
    'failed manual FX update does not start another six-hour wait',
    () async {
      final store = _MemoryStore();
      var now = DateTime.utc(2026, 9, 25, 12);
      var calls = 0;
      var fail = false;
      final client = MockClient((_) async {
        calls++;
        return fail
            ? http.Response('unavailable', 503)
            : http.Response(
                '{"USDBRL":{"bid":"5.20"},"EURBRL":{"bid":"6.10"},"INRBRL":{"bid":"0.062"}}',
                200,
              );
      });
      AwesomeApiFxRepository repository() => AwesomeApiFxRepository(
        apiKey: 'test-key',
        client: client,
        cacheStore: store,
        clock: () => now,
      );

      await repository().latest(CurrencyCode.brl);
      now = now.add(const Duration(hours: 6, seconds: 1));
      fail = true;
      final failed = repository();
      expect(
        (await failed.latest(CurrencyCode.brl, forceRefresh: true))!.status,
        QuoteStatus.cached,
      );
      expect(
        await failed.nextRefreshAt(),
        now.add(const Duration(minutes: 30)),
      );
      expect(calls, 2);

      now = now.add(const Duration(minutes: 30, seconds: 1));
      fail = false;
      final retried = repository();
      expect(
        (await retried.latest(CurrencyCode.brl, forceRefresh: true))!.status,
        QuoteStatus.current,
      );
      expect(calls, 3);
      expect(await retried.nextRefreshAt(), now.add(const Duration(hours: 6)));
    },
  );

  test(
    'manual market update waits six hours after a successful quote',
    () async {
      final store = _MemoryStore();
      var now = DateTime.utc(2026, 9, 25, 12);
      final provider = _CountingMarket(() => now);
      PersistentAssetMarketRepository repository() =>
          PersistentAssetMarketRepository(
            delegate: provider,
            store: store,
            clock: () => now,
          );

      await repository().latestFor([_stock]);
      await repository().latestFor([_stock], forceRefresh: true);
      expect(provider.calls, 1);
      for (var pull = 0; pull < 20; pull++) {
        await repository().latestFor([_stock], forceRefresh: true);
      }
      expect(provider.calls, 1);
      now = now.add(const Duration(hours: 6, seconds: 1));
      await repository().latestFor([_stock], forceRefresh: true);
      expect(provider.calls, 2);
    },
  );

  test(
    'home quote skips crypto history; investments request it once',
    () async {
      final store = _MemoryStore();
      final now = DateTime.utc(2026, 9, 25, 12);
      final provider = _CountingMarket(() => now);
      PersistentAssetMarketRepository repository() =>
          PersistentAssetMarketRepository(
            delegate: provider,
            store: store,
            clock: () => now,
          );

      await repository().latestFor([_crypto], includeHistory: false);
      expect(provider.historyRequests, 0);
      await repository().latestFor([_crypto], includeHistory: true);
      expect(provider.historyRequests, 1);
      await repository().latestFor([_crypto], includeHistory: true);
      expect(provider.historyRequests, 1);
    },
  );

  test(
    'last genuine history survives a quote-only refresh and restart',
    () async {
      final store = _MemoryStore();
      var now = DateTime.utc(2026, 9, 25, 12);
      var closes = <int>[100, 110, 120];
      final provider = _VariableMarket(() => now, () => closes);
      PersistentAssetMarketRepository repository() =>
          PersistentAssetMarketRepository(
            delegate: provider,
            store: store,
            clock: () => now,
          );
      expect(
        (await repository().latestFor([_crypto]))['cmc-1']!.closeValuesMinor,
        [100, 110, 120],
      );
      now = now.add(const Duration(hours: 7));
      closes = <int>[];
      final refreshed = await repository().latestFor([_crypto]);
      expect(refreshed['cmc-1']!.closeValuesMinor, [100, 110, 120]);
      expect(
        (await repository().latestFor([_crypto]))['cmc-1']!.closeValuesMinor,
        [100, 110, 120],
      );
    },
  );

  test('missing market cache respects failure cooldown before retrying', () async {
    final store = _MemoryStore();
    final provider = _RecoveringMarket();
    var now = DateTime.utc(2026, 9, 25, 12);
    PersistentAssetMarketRepository repository() => PersistentAssetMarketRepository(
      delegate: provider,
      store: store,
      clock: () => now,
      failureCooldown: const Duration(minutes: 30),
    );
    expect(await repository().latestFor([_crypto]), isEmpty);
    expect(await repository().latestFor([_crypto]), isEmpty);
    expect(provider.calls, 1);
    now = now.add(const Duration(minutes: 30, seconds: 1));
    expect(
      (await repository().latestFor([_crypto]))['cmc-1']!.closeValuesMinor,
      [100, 110],
    );
    expect(provider.calls, 2);
  });

  test('manual market refresh can recover a quote during failure cooldown', () async {
    final store = _MemoryStore();
    final provider = _RecoveringMarket();
    final repository = PersistentAssetMarketRepository(
      delegate: provider,
      store: store,
      failureCooldown: const Duration(minutes: 30),
    );

    expect(await repository.latestFor([_crypto]), isEmpty);
    final refreshed = await repository.latestFor([_crypto], forceRefresh: true);

    expect(provider.calls, 2);
    expect(refreshed['cmc-1']?.closeValuesMinor, [100, 110]);
  });

  test('retries one time for failure rows written by the older policy', () async {
    final store = _MemoryStore()
      ..values['market.assets.v1'] =
          '{"cmc-1":{"retryAfter":"2026-09-25T13:00:00.000Z"}}';
    var now = DateTime.utc(2026, 9, 25, 12, 10);
    final provider = _RecoveringMarket();
    final repository = PersistentAssetMarketRepository(
      delegate: provider,
      store: store,
      clock: () => now,
      failureCooldown: const Duration(minutes: 30),
    );

    expect(await repository.latestFor([_crypto]), isEmpty);
    expect(provider.calls, 1);
    expect(await repository.latestFor([_crypto]), isEmpty);
    expect(provider.calls, 1);
    now = now.add(const Duration(minutes: 31));
    expect(
      (await repository.latestFor([_crypto]))['cmc-1']?.closeValuesMinor,
      [100, 110],
    );
    expect(provider.calls, 2);
  });
}

const _stock = InstrumentIdentity(
  providerAssetId: 'us-aapl',
  family: AssetFamily.equity,
  symbol: 'AAPL',
  officialName: 'Apple',
  exchangeMic: 'XNAS',
  countryCode: 'US',
  currency: CurrencyCode.usd,
);

const _crypto = InstrumentIdentity(
  providerAssetId: 'cmc-1',
  family: AssetFamily.crypto,
  symbol: 'BTC',
  officialName: 'Bitcoin',
  exchangeMic: 'CMC',
  countryCode: 'GLOBAL',
  currency: CurrencyCode.usd,
);

final class _MemoryStore implements CacheStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

final class _CountingMarket implements AssetMarketRepository {
  _CountingMarket(this.clock);
  final DateTime Function() clock;
  int calls = 0;
  int historyRequests = 0;

  @override
  Future<Map<String, AssetMarketSeries>> latestFor(
    List<InstrumentIdentity> identities, {
    bool includeHistory = true,
    bool forceRefresh = false,
  }) async {
    calls++;
    if (includeHistory &&
        identities.any((item) => item.family == AssetFamily.crypto)) {
      historyRequests++;
    }
    return {
      for (final item in identities)
        item.providerAssetId: AssetMarketSeries(
          identity: item,
          closeValuesMinor: includeHistory ? const [100, 110] : const [110],
          observedAt: clock(),
          status: AssetMarketSeriesStatus.current,
        ),
    };
  }
}

final class _VariableMarket implements AssetMarketRepository {
  _VariableMarket(this.clock, this.closes);
  final DateTime Function() clock;
  final List<int> Function() closes;

  @override
  Future<Map<String, AssetMarketSeries>> latestFor(
    List<InstrumentIdentity> identities, {
    bool includeHistory = true,
    bool forceRefresh = false,
  }) async => {
    for (final identity in identities)
      identity.providerAssetId: AssetMarketSeries(
        identity: identity,
        closeValuesMinor: closes(),
        observedAt: clock(),
        status: AssetMarketSeriesStatus.current,
        unitPriceUsd: '123.45',
      ),
  };
}

final class _RecoveringMarket implements AssetMarketRepository {
  int calls = 0;

  @override
  Future<Map<String, AssetMarketSeries>> latestFor(
    List<InstrumentIdentity> identities, {
    bool includeHistory = true,
    bool forceRefresh = false,
  }) async {
    calls++;
    if (calls == 1) throw StateError('proxy unavailable');
    return {
      for (final identity in identities)
        identity.providerAssetId: AssetMarketSeries(
          identity: identity,
          closeValuesMinor: const [100, 110],
          observedAt: DateTime.utc(2026, 9, 26),
          status: AssetMarketSeriesStatus.current,
        ),
    };
  }
}
