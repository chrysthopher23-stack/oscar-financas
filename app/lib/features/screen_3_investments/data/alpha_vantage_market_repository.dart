import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../domain/asset_market_series.dart';
import '../domain/instrument_identity.dart';

final class AlphaVantageMarketRepository implements AssetMarketRepository {
  AlphaVantageMarketRepository({
    required this.apiKey,
    http.Client? client,
    this.requestSpacing = const Duration(milliseconds: 1100),
    this.cacheLifetime = _defaultCacheLifetime,
  }) : _client = client ?? http.Client();

  final String apiKey;
  final http.Client _client;
  final Duration requestSpacing;
  final Duration cacheLifetime;
  final Map<String, AssetMarketSeries> _cache = {};
  final Map<String, DateTime> _refreshedAt = {};
  static const _defaultCacheLifetime = Duration(hours: 6);

  @override
  Future<Map<String, AssetMarketSeries>> latestFor(
    List<InstrumentIdentity> identities, {
    bool includeHistory = true,
    bool forceRefresh = false,
  }) async {
    final uniqueIdentities = <String, InstrumentIdentity>{
      for (final identity in identities)
        if (identity.providerAssetId.isNotEmpty)
          identity.providerAssetId: identity,
    }.values.toList(growable: false);
    final results = <AssetMarketSeries?>[];
    for (var index = 0; index < uniqueIdentities.length; index++) {
      results.add(
        await _latestForIdentity(
          uniqueIdentities[index],
          forceRefresh: forceRefresh,
        ),
      );
      if (index < uniqueIdentities.length - 1 &&
          requestSpacing > Duration.zero) {
        await Future<void>.delayed(requestSpacing);
      }
    }
    return {
      for (var index = 0; index < uniqueIdentities.length; index++)
        if (results[index] != null)
          uniqueIdentities[index].providerAssetId: results[index]!,
    };
  }

  Future<AssetMarketSeries?> _latestForIdentity(
    InstrumentIdentity identity, {
    required bool forceRefresh,
  }) async {
    final cached = _cache[identity.providerAssetId];
    final refreshedAt = _refreshedAt[identity.providerAssetId];
    if (!forceRefresh &&
        cached != null &&
        refreshedAt != null &&
        DateTime.now().toUtc().difference(refreshedAt) < cacheLifetime) {
      return cached;
    }
    final providerSymbol = _providerSymbol(identity);
    if (providerSymbol == null) return _cache[identity.providerAssetId];
    try {
      if (apiKey.trim().isEmpty && !kIsWeb) {
        return _cache[identity.providerAssetId];
      }
      final uri = apiKey.trim().isEmpty
          ? Uri.base.resolve(
              '/api/assets/history?symbol=${Uri.encodeQueryComponent(providerSymbol)}${forceRefresh ? '&refresh=1' : ''}',
            )
          : Uri.https('www.alphavantage.co', '/query', {
              'function': 'TIME_SERIES_DAILY',
              'symbol': providerSymbol,
              'outputsize': 'compact',
              'apikey': apiKey,
            });
      final response = await _client.get(uri);
      if (response.statusCode != 200) throw const FormatException();
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final rawSeries = payload['Time Series (Daily)'];
      if (rawSeries is! Map<String, dynamic>) throw const FormatException();
      final dates = rawSeries.keys.toList()..sort();
      final recentDates = dates.length <= 20
          ? dates
          : dates.sublist(dates.length - 20);
      final closes = recentDates
          .map((date) {
            final day = rawSeries[date];
            if (day is! Map<String, dynamic>) return null;
            final close = double.tryParse('${day['4. close'] ?? ''}');
            return close == null ? null : (close * 100).round();
          })
          .whereType<int>()
          .toList(growable: false);
      if (closes.length < 2) throw const FormatException();
      final latest = AssetMarketSeries(
        identity: identity,
        closeValuesMinor: closes,
        observedAt:
            DateTime.tryParse(recentDates.last) ?? DateTime.now().toUtc(),
        status: AssetMarketSeriesStatus.current,
      );
      _cache[identity.providerAssetId] = latest;
      _refreshedAt[identity.providerAssetId] = DateTime.now().toUtc();
      return latest;
    } catch (_) {
      final cached = _cache[identity.providerAssetId];
      if (cached == null) return null;
      return AssetMarketSeries(
        identity: cached.identity,
        closeValuesMinor: cached.closeValuesMinor,
        observedAt: cached.observedAt,
        status: AssetMarketSeriesStatus.cached,
      );
    }
  }

  String? _providerSymbol(InstrumentIdentity identity) {
    if (identity.exchangeMic == 'MANUAL' ||
        identity.exchangeMic == 'OTC' ||
        identity.exchangeMic == 'TESOURO' ||
        identity.symbol == 'SELIC' ||
        identity.symbol == 'CDB') {
      return null;
    }
    final suffix = switch (identity.exchangeMic) {
      'XETR' => '.DEX',
      'XPAR' => '.PAR',
      'BVMF' => '.SAO',
      'XBOM' => '.BSE',
      // Alpha Vantage's India coverage uses the BSE-qualified symbol for
      // Indian equities (for example INFY.BSE), even when our catalog record
      // identifies the instrument's primary exchange as NSE.
      'XNSE' => '.BSE',
      _ => '',
    };
    return '${identity.symbol}$suffix';
  }
}
