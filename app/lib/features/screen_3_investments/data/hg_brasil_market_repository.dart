import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../domain/asset_market_series.dart';
import '../domain/instrument_identity.dart';

/// Supplies quotes only for Brazilian exchange-listed positions.
final class HgBrasilMarketRepository implements AssetMarketRepository {
  HgBrasilMarketRepository({required this.apiKey, http.Client? client})
    : _client = client ?? http.Client();

  final String apiKey;
  final http.Client _client;
  final Map<String, AssetMarketSeries> _cache = {};
  final Map<String, DateTime> _refreshedAt = {};
  static const _cacheLifetime = Duration(hours: 6);

  @override
  Future<Map<String, AssetMarketSeries>> latestFor(
    List<InstrumentIdentity> identities, {
    bool includeHistory = true,
    bool forceRefresh = false,
  }) async {
    final brazilian = <String, InstrumentIdentity>{
      for (final identity in identities)
        if (identity.countryCode.toUpperCase() == 'BR' &&
            identity.exchangeMic == 'BVMF' &&
            identity.providerAssetId.isNotEmpty)
          identity.providerAssetId: identity,
    }.values.toList(growable: false);
    final results = await Future.wait(
      brazilian.map(
        (identity) => _latestForIdentity(identity, forceRefresh: forceRefresh),
      ),
    );
    return {
      for (var index = 0; index < results.length; index++)
        if (results[index] != null)
          brazilian[index].providerAssetId: results[index]!,
    };
  }

  Future<AssetMarketSeries?> _latestForIdentity(
    InstrumentIdentity identity, {
    required bool forceRefresh,
  }) async {
    try {
      final cached = _cache[identity.providerAssetId];
      final refreshedAt = _refreshedAt[identity.providerAssetId];
      if (!forceRefresh &&
          cached != null &&
          refreshedAt != null &&
          DateTime.now().toUtc().difference(refreshedAt) < _cacheLifetime) {
        return cached;
      }
      if (apiKey.trim().isEmpty && !kIsWeb) {
        return _cached(identity.providerAssetId);
      }
      final uri = apiKey.trim().isEmpty
          ? Uri.base.resolve(
              '/api/assets/hg?symbol=${Uri.encodeQueryComponent(identity.symbol)}${forceRefresh ? '&refresh=1' : ''}',
            )
          : Uri.https('api.hgbrasil.com', '/finance/stock_price', {
              'key': apiKey,
              'symbol': identity.symbol,
            });
      final response = await _client.get(uri);
      if (response.statusCode != 200) throw const FormatException();
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final results = payload['results'];
      if (results is! Map<String, dynamic>) throw const FormatException();
      final rawQuote =
          results[identity.symbol] ??
          results[identity.symbol.toLowerCase()] ??
          (results.length == 1 ? results.values.first : null);
      if (rawQuote is! Map<String, dynamic>) throw const FormatException();
      final price = double.tryParse('${rawQuote['price'] ?? ''}');
      if (price == null || price <= 0) throw const FormatException();
      final change =
          double.tryParse('${rawQuote['change_percent'] ?? ''}') ?? 0;
      final latest = (price * 100).round();
      final divisor = 1 + change / 100;
      final previous = divisor <= 0 ? latest : (latest / divisor).round();
      final series = AssetMarketSeries(
        identity: identity,
        closeValuesMinor: [previous, latest],
        observedAt:
            DateTime.tryParse('${rawQuote['updated_at'] ?? ''}') ??
            DateTime.now().toUtc(),
        status: AssetMarketSeriesStatus.current,
      );
      _cache[identity.providerAssetId] = series;
      _refreshedAt[identity.providerAssetId] = DateTime.now().toUtc();
      return series;
    } catch (_) {
      return _cached(identity.providerAssetId);
    }
  }

  AssetMarketSeries? _cached(String providerAssetId) {
    final cached = _cache[providerAssetId];
    if (cached == null) return null;
    return AssetMarketSeries(
      identity: cached.identity,
      closeValuesMinor: cached.closeValuesMinor,
      observedAt: cached.observedAt,
      status: AssetMarketSeriesStatus.cached,
    );
  }
}
