// ignore_for_file: prefer_initializing_formals

import 'dart:convert';

import '../../../core/cache/cache_store.dart';
import '../domain/asset_market_series.dart';
import '../domain/asset_family.dart';
import '../domain/instrument_identity.dart';

/// Reuses real market observations across screens and app restarts.
final class PersistentAssetMarketRepository implements AssetMarketRepository {
  PersistentAssetMarketRepository({
    required AssetMarketRepository delegate,
    CacheStore store = const SharedPreferencesCacheStore(),
    DateTime Function()? clock,
    this.cacheLifetime = const Duration(hours: 6),
    this.failureCooldown = const Duration(minutes: 30),
  }) : _delegate = delegate,
       _store = store,
       _clock = clock ?? _utcNow;

  static const _cacheKey = 'market.assets.v1';
  static const _failureRetryPolicyVersion = 1;
  final AssetMarketRepository _delegate;
  final CacheStore _store;
  final DateTime Function() _clock;
  final Duration cacheLifetime;
  final Duration failureCooldown;
  static const manualRefreshInterval = Duration(hours: 6);
  final Map<String, _StoredSeries> _entries = {};
  Future<void>? _loading;
  Future<void> _tail = Future<void>.value();

  static DateTime _utcNow() => DateTime.now().toUtc();

  @override
  Future<Map<String, AssetMarketSeries>> latestFor(
    List<InstrumentIdentity> identities, {
    bool includeHistory = true,
    bool forceRefresh = false,
  }) async {
    final unique = <String, InstrumentIdentity>{
      for (final identity in identities)
        if (identity.providerAssetId.isNotEmpty)
          identity.providerAssetId: identity,
    };
    if (unique.isEmpty) return {};
    await (_loading ??= _loadCache());
    final result = _tail.then(
      (_) => _latestFor(
        unique,
        includeHistory: includeHistory,
        forceRefresh: forceRefresh,
      ),
    );
    _tail = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<Map<String, AssetMarketSeries>> _latestFor(
    Map<String, InstrumentIdentity> unique, {
    required bool includeHistory,
    required bool forceRefresh,
  }) async {
    final now = _clock();
    final results = <String, AssetMarketSeries>{};
    final missing = <InstrumentIdentity>[];
    for (final identity in unique.values) {
      final saved = _entries[identity.providerAssetId];
      final needsCryptoHistory =
          includeHistory &&
          identity.family == AssetFamily.crypto &&
          !(saved?.historyLoaded ?? false);
      final hasActiveFailureCooldown =
          saved?.retryAfter != null &&
          saved?.failureRetryPolicyVersion == _failureRetryPolicyVersion &&
          now.isBefore(saved!.retryAfter!);
      final manualCooling =
          forceRefresh &&
          saved?.fetchedAt != null &&
          now.difference(saved!.fetchedAt!) < manualRefreshInterval &&
          !needsCryptoHistory;
      if (saved != null &&
          (manualCooling ||
              (!forceRefresh &&
                  saved.series != null &&
                  saved.fetchedAt != null &&
                  now.difference(saved.fetchedAt!) < cacheLifetime &&
                  !needsCryptoHistory) ||
              (!forceRefresh && hasActiveFailureCooldown))) {
        if (saved.series != null) {
          results[identity.providerAssetId] = saved.series!.withIdentity(
            identity,
          );
        }
      } else {
        missing.add(identity);
      }
    }
    if (missing.isEmpty) return results;

    Map<String, AssetMarketSeries> refreshed;
    try {
      refreshed = await _delegate.latestFor(
        missing,
        includeHistory: includeHistory,
        forceRefresh: forceRefresh,
      );
    } catch (_) {
      refreshed = const {};
    }
    final finishedAt = _clock();
    for (final identity in missing) {
      final id = identity.providerAssetId;
      final value = refreshed[id];
      final previous = _entries[id];
      if (value != null && value.status == AssetMarketSeriesStatus.current) {
        final retainedHistory = previous?.series?.closeValuesMinor;
        final closes =
            value.closeValuesMinor.length >= 2 ||
                retainedHistory == null ||
                retainedHistory.length < 2
            ? value.closeValuesMinor
            : retainedHistory;
        final resolved = AssetMarketSeries(
          identity: identity,
          closeValuesMinor: closes,
          observedAt: value.observedAt,
          status: value.status,
          unitPriceUsd: value.unitPriceUsd,
          dayChangeBasisPoints: value.dayChangeBasisPoints,
        );
        _entries[id] = _StoredSeries(
          series: _StoredMarketSeries.fromSeries(resolved),
          fetchedAt: finishedAt,
          historyLoaded: closes.length >= 2,
        );
        results[id] = resolved;
      } else {
        final old =
            previous?.series ??
            (value == null ? null : _StoredMarketSeries.fromSeries(value));
        _entries[id] = _StoredSeries(
          series: old,
          fetchedAt: previous?.fetchedAt,
          retryAfter: finishedAt.add(failureCooldown),
          historyLoaded: previous?.historyLoaded ?? false,
          failureRetryPolicyVersion: _failureRetryPolicyVersion,
        );
        if (old != null) results[id] = old.withIdentity(identity);
      }
    }
    await _persist();
    return results;
  }

  Future<void> _loadCache() async {
    try {
      final raw = await _store.read(_cacheKey);
      if (raw == null) return;
      final rows = jsonDecode(raw) as Map<String, dynamic>;
      for (final item in rows.entries) {
        if (item.value is! Map<String, dynamic>) continue;
        final row = item.value as Map<String, dynamic>;
        final series = row['series'];
        _entries[item.key] = _StoredSeries(
          series: series is Map<String, dynamic>
              ? _StoredMarketSeries.fromJson(series)
              : null,
          fetchedAt: DateTime.tryParse('${row['fetchedAt'] ?? ''}'),
          retryAfter: DateTime.tryParse('${row['retryAfter'] ?? ''}'),
          historyLoaded: row['historyLoaded'] == true,
          failureRetryPolicyVersion:
              (row['failureRetryPolicyVersion'] as num?)?.toInt() ?? 0,
        );
      }
    } catch (_) {
      // Invalid local cache is ignored; the provider remains available.
    }
  }

  Future<void> _persist() async {
    try {
      await _store.write(
        _cacheKey,
        jsonEncode({
          for (final entry in _entries.entries)
            entry.key: {
              if (entry.value.series != null)
                'series': entry.value.series!.toJson(),
              if (entry.value.fetchedAt != null)
                'fetchedAt': entry.value.fetchedAt!.toIso8601String(),
              if (entry.value.retryAfter != null)
                'retryAfter': entry.value.retryAfter!.toIso8601String(),
              if (entry.value.historyLoaded) 'historyLoaded': true,
              if (entry.value.retryAfter != null)
                'failureRetryPolicyVersion':
                    entry.value.failureRetryPolicyVersion,
            },
        }),
      );
    } catch (_) {
      // Quotes can still be displayed if local cache writes are unavailable.
    }
  }
}

final class _StoredSeries {
  const _StoredSeries({
    this.series,
    this.fetchedAt,
    this.retryAfter,
    this.historyLoaded = false,
    this.failureRetryPolicyVersion = 0,
  });
  final _StoredMarketSeries? series;
  final DateTime? fetchedAt;
  final DateTime? retryAfter;
  final bool historyLoaded;
  final int failureRetryPolicyVersion;
}

final class _StoredMarketSeries {
  const _StoredMarketSeries({
    required this.closeValuesMinor,
    required this.observedAt,
    this.unitPriceUsd,
    this.dayChangeBasisPoints,
  });

  factory _StoredMarketSeries.fromSeries(AssetMarketSeries series) =>
      _StoredMarketSeries(
        closeValuesMinor: series.closeValuesMinor,
        observedAt: series.observedAt,
        unitPriceUsd: series.unitPriceUsd,
        dayChangeBasisPoints: series.dayChangeBasisPoints,
      );

  factory _StoredMarketSeries.fromJson(Map<String, dynamic> json) =>
      _StoredMarketSeries(
        closeValuesMinor: (json['closes'] as List)
            .map((value) => (value as num).toInt())
            .toList(growable: false),
        observedAt: DateTime.parse(json['observedAt'] as String),
        unitPriceUsd: json['unitPriceUsd'] as String?,
        dayChangeBasisPoints: json['dayChangeBasisPoints'] as int?,
      );

  final List<int> closeValuesMinor;
  final DateTime observedAt;
  final String? unitPriceUsd;
  final int? dayChangeBasisPoints;

  AssetMarketSeries withIdentity(InstrumentIdentity identity) =>
      AssetMarketSeries(
        identity: identity,
        closeValuesMinor: closeValuesMinor,
        observedAt: observedAt,
        status: AssetMarketSeriesStatus.cached,
        unitPriceUsd: unitPriceUsd,
        dayChangeBasisPoints: dayChangeBasisPoints,
      );

  Map<String, Object?> toJson() => {
    'closes': closeValuesMinor,
    'observedAt': observedAt.toIso8601String(),
    if (unitPriceUsd != null) 'unitPriceUsd': unitPriceUsd,
    if (dayChangeBasisPoints != null)
      'dayChangeBasisPoints': dayChangeBasisPoints,
  };
}
