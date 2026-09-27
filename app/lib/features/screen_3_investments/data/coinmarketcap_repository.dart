import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/money/money.dart';
import '../domain/asset_catalog.dart';
import '../domain/asset_family.dart';
import '../domain/asset_market_series.dart';
import '../domain/instrument_identity.dart';

final class CoinMarketCapRepository implements AssetMarketRepository {
  CoinMarketCapRepository({http.Client? client, Uri? baseUri})
    : _client = client ?? http.Client(),
      _baseUri =
          baseUri ??
          (kIsWeb
              ? Uri.base
              : Uri.tryParse(const String.fromEnvironment('MARKET_PROXY_URL')));
  final http.Client _client;
  final Uri? _baseUri;
  final Map<String, AssetMarketSeries> _cache = {};

  Uri? _endpoint(String path, Map<String, String> query) {
    final base = _baseUri;
    if (base == null || !base.hasAuthority) return null;
    return base.resolve(path).replace(queryParameters: query);
  }

  @override
  Future<Map<String, AssetMarketSeries>> latestFor(
    List<InstrumentIdentity> identities, {
    bool includeHistory = true,
    bool forceRefresh = false,
  }) async {
    final selected = {
      for (final item in identities)
        if (item.family == AssetFamily.crypto &&
            RegExp(r'^cmc-\d+$').hasMatch(item.providerAssetId))
          item.providerAssetId: item,
    };
    if (selected.isEmpty) return {};
    final keys = selected.keys.toList();
    for (var start = 0; start < keys.length; start += 100) {
      final batch = keys.sublist(start, (start + 100).clamp(0, keys.length));
      // Until this request confirms a quote, retained data is only cached.
      // This also covers non-200 responses and missing items in a valid response.
      for (final id in batch) {
        final previous = _cache[id];
        if (previous != null) {
          _cache[id] = AssetMarketSeries(
            identity: previous.identity,
            closeValuesMinor: previous.closeValuesMinor,
            observedAt: previous.observedAt,
            status: AssetMarketSeriesStatus.cached,
            unitPriceUsd: previous.unitPriceUsd,
            dayChangeBasisPoints: previous.dayChangeBasisPoints,
          );
        }
      }
      final uri = _endpoint('/api/crypto/quotes', {
        'ids': batch.map((id) => id.substring(4)).join(','),
        if (includeHistory) 'history': '1',
        if (forceRefresh) 'refresh': '1',
      });
      if (uri == null) continue;
      try {
        final response = await _client
            .get(uri)
            .timeout(const Duration(seconds: 20));
        if (response.statusCode != 200) continue;
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        for (final item in payload['data'] as List) {
          final id = 'cmc-${item['id']}';
          if (!selected.containsKey(id)) continue;
          final price = '${item['priceUsd']}';
          if (double.tryParse(price) == null) continue;
          final history = <int>[];
          for (final point in item['history'] as List? ?? const []) {
            if (point is! Map) continue;
            final number = double.tryParse('${point['price']}');
            if (number == null || !number.isFinite || number < 0) continue;
            history.add((number * 10000000000).round());
          }
          final previousHistory = _cache[id]?.closeValuesMinor;
          _cache[id] = AssetMarketSeries(
            identity: selected[id]!,
            closeValuesMinor: history.length >= 2
                ? history
                : previousHistory != null && previousHistory.length >= 2
                ? previousHistory
                : history,
            observedAt: DateTime.parse(item['observedAt'] as String),
            status: item['stale'] == true
                ? AssetMarketSeriesStatus.cached
                : AssetMarketSeriesStatus.current,
            unitPriceUsd: price,
            dayChangeBasisPoints: ((item['change24h'] as num) * 100).round(),
          );
        }
      } catch (_) {
        for (final id in batch) {
          final previous = _cache[id];
          if (previous != null) {
            _cache[id] = AssetMarketSeries(
              identity: previous.identity,
              closeValuesMinor: previous.closeValuesMinor,
              observedAt: previous.observedAt,
              status: AssetMarketSeriesStatus.cached,
              unitPriceUsd: previous.unitPriceUsd,
              dayChangeBasisPoints: previous.dayChangeBasisPoints,
            );
          }
        }
      }
    }
    return {
      for (final id in selected.keys)
        if (_cache.containsKey(id)) id: _cache[id]!,
    };
  }

  Future<List<InstrumentIdentity>> search(String query) async {
    final uri = _endpoint('/api/crypto/search', {'q': query});
    if (uri == null || query.trim().length < 2) return [];
    try {
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return [];
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return [
        for (final row in payload['data'] as List)
          InstrumentIdentity(
            providerAssetId: 'cmc-${row['id']}',
            family: AssetFamily.crypto,
            symbol: row['symbol'] as String,
            officialName: row['name'] as String,
            exchangeMic: 'CMC',
            countryCode: 'GLOBAL',
            currency: CurrencyCode.usd,
          ),
      ];
    } catch (_) {
      return [];
    }
  }
}

final class CombinedAssetCatalog implements AssetCatalogRepository {
  const CombinedAssetCatalog(this.local, this.crypto);
  final AssetCatalogRepository local;
  final CoinMarketCapRepository crypto;
  @override
  Future<List<InstrumentIdentity>> search(
    String query, {
    int limit = 20,
  }) async {
    final localItems = await local.search(query, limit: limit);
    final remote = await crypto.search(query);
    return {
      for (final item in [...localItems, ...remote]) item.providerAssetId: item,
    }.values.take(limit).toList();
  }
}
