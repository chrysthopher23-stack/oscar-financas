// ignore_for_file: prefer_initializing_formals

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/cache/cache_store.dart';
import '../../../core/money/money.dart';
import '../domain/fx_quote_set.dart';

final class AwesomeApiFxRepository implements FxRepository, FxRefreshSchedule {
  AwesomeApiFxRepository({
    required this.apiKey,
    FxRepository fallback = const OfflineDemonstrationFxRepository(),
    http.Client? client,
    CacheStore cacheStore = const SharedPreferencesCacheStore(),
    DateTime Function()? clock,
    this.cacheLifetime = const Duration(hours: 6),
    this.failureCooldown = const Duration(minutes: 30),
  }) : _fallback = fallback,
       _client = client ?? http.Client(),
       _cacheStore = cacheStore,
       _clock = clock ?? _utcNow;

  static const _cacheKey = 'market.fx.brl.v1';
  final String apiKey;
  final FxRepository _fallback;
  final http.Client _client;
  final CacheStore _cacheStore;
  final DateTime Function() _clock;
  final Duration cacheLifetime;
  final Duration failureCooldown;
  static const manualRefreshInterval = Duration(hours: 6);
  Map<CurrencyCode, int>? _brlPerUnitScaled;
  DateTime? _observedAt;
  DateTime? _fetchedAt;
  DateTime? _retryAfter;
  Future<void>? _loading;
  Future<bool>? _inFlight;

  static DateTime _utcNow() => DateTime.now().toUtc();

  @override
  Future<DateTime?> nextRefreshAt() async {
    await (_loading ??= _loadCache());
    final fromSuccess = _fetchedAt?.add(manualRefreshInterval);
    final retry = _retryAfter;
    if (retry != null && (fromSuccess == null || retry.isAfter(fromSuccess))) {
      return retry;
    }
    return fromSuccess;
  }

  @override
  Future<FxQuoteSet?> latest(
    CurrencyCode base, {
    bool forceRefresh = false,
  }) async {
    await (_loading ??= _loadCache());
    final now = _clock();
    if (forceRefresh &&
        _fetchedAt != null &&
        now.difference(_fetchedAt!) < manualRefreshInterval) {
      return _cachedOrFallback(base);
    }
    if (!forceRefresh &&
        _brlPerUnitScaled != null &&
        _fetchedAt != null &&
        now.difference(_fetchedAt!) < cacheLifetime) {
      return _fromBrlValues(
        base,
        _brlPerUnitScaled!,
        QuoteStatus.cached,
        _observedAt!,
      );
    }
    if (_retryAfter != null &&
        now.isBefore(_retryAfter!)) {
      return _cachedOrFallback(base);
    }
    final pending = _inFlight ??= _fetchAndCache();
    final refreshed = await pending;
    if (identical(_inFlight, pending)) _inFlight = null;
    if (refreshed) {
      return _fromBrlValues(
        base,
        _brlPerUnitScaled!,
        QuoteStatus.current,
        _observedAt!,
      );
    }
    return _cachedOrFallback(base);
  }

  Future<void> _loadCache() async {
    try {
      final raw = await _cacheStore.read(_cacheKey);
      if (raw == null) return;
      final saved = jsonDecode(raw) as Map<String, dynamic>;
      final rawValues = saved['values'];
      if (rawValues is Map<String, dynamic>) {
        final values = <CurrencyCode, int>{};
        for (final currency in CurrencyCode.values) {
          final value = rawValues[currency.isoCode];
          if (value is! int || value <= 0) return;
          values[currency] = value;
        }
        _brlPerUnitScaled = values;
        _observedAt = DateTime.parse(saved['observedAt'] as String);
        _fetchedAt = DateTime.parse(saved['fetchedAt'] as String);
      }
      final retry = saved['retryAfter'];
      if (retry is String) _retryAfter = DateTime.tryParse(retry);
    } catch (_) {
      // Corrupt or unavailable local cache must not prevent live quotes.
    }
  }

  Future<bool> _fetchAndCache() async {
    if (apiKey.trim().isEmpty && !kIsWeb) return false;
    try {
      final uri = apiKey.trim().isEmpty
          ? Uri.base.resolve('/api/fx')
          : Uri.parse(
              'https://economia.awesomeapi.com.br/json/last/USD-BRL,EUR-BRL,INR-BRL',
            );
      final headers = apiKey.trim().isEmpty
          ? const <String, String>{}
          : {'x-api-key': apiKey};
      final response = await _client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) throw const FormatException();
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final values = <CurrencyCode, int>{CurrencyCode.brl: FxQuoteSet.scale};
      for (final entry in const {
        CurrencyCode.usd: 'USDBRL',
        CurrencyCode.eur: 'EURBRL',
        CurrencyCode.inr: 'INRBRL',
      }.entries) {
        final quote = payload[entry.value] as Map<String, dynamic>?;
        final bid = double.tryParse('${quote?['bid'] ?? ''}');
        if (bid == null || bid <= 0) throw const FormatException();
        values[entry.key] = (bid * FxQuoteSet.scale).round();
      }
      _brlPerUnitScaled = values;
      _observedAt = _clock();
      _fetchedAt = _observedAt;
      _retryAfter = null;
      await _persist();
      return true;
    } catch (_) {
      _retryAfter = _clock().add(failureCooldown);
      await _persist();
      return false;
    }
  }

  Future<void> _persist() async {
    try {
      await _cacheStore.write(
        _cacheKey,
        jsonEncode({
          if (_brlPerUnitScaled != null)
            'values': {
              for (final entry in _brlPerUnitScaled!.entries)
                entry.key.isoCode: entry.value,
            },
          if (_observedAt != null) 'observedAt': _observedAt!.toIso8601String(),
          if (_fetchedAt != null) 'fetchedAt': _fetchedAt!.toIso8601String(),
          if (_retryAfter != null) 'retryAfter': _retryAfter!.toIso8601String(),
        }),
      );
    } catch (_) {
      // Quote use is more important than persistence if storage is unavailable.
    }
  }

  Future<FxQuoteSet?> _cachedOrFallback(CurrencyCode base) async {
    final cached = _brlPerUnitScaled;
    if (cached == null) return _fallback.latest(base);
    return _fromBrlValues(
      base,
      cached,
      QuoteStatus.cached,
      _observedAt ?? _clock(),
    );
  }

  FxQuoteSet _fromBrlValues(
    CurrencyCode base,
    Map<CurrencyCode, int> brlPerUnit,
    QuoteStatus status,
    DateTime observedAt,
  ) {
    final baseInBrl = brlPerUnit[base]!;
    final rates = <CurrencyCode, int>{};
    for (final target in CurrencyCode.values) {
      rates[target] =
          ((BigInt.from(baseInBrl) * BigInt.from(FxQuoteSet.scale)) /
                  BigInt.from(brlPerUnit[target]!))
              .round()
              .toInt();
    }
    rates[base] = FxQuoteSet.scale;
    return FxQuoteSet(
      base: base,
      unitsPerBaseScaled: rates,
      observedAt: observedAt,
      status: status,
    );
  }
}
