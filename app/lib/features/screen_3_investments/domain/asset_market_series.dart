import 'instrument_identity.dart';

enum AssetMarketSeriesStatus { current, cached, simulated, unavailable }

final class AssetMarketSeries {
  const AssetMarketSeries({
    required this.identity,
    required this.closeValuesMinor,
    required this.observedAt,
    required this.status,
    this.unitPriceUsd,
    this.dayChangeBasisPoints,
  });

  final InstrumentIdentity identity;
  final List<int> closeValuesMinor;
  final DateTime observedAt;
  final AssetMarketSeriesStatus status;
  final String? unitPriceUsd;
  final int? dayChangeBasisPoints;

  int? get latestMinor =>
      closeValuesMinor.isEmpty ? null : closeValuesMinor.last;

  int get changeBasisPoints {
    if (dayChangeBasisPoints != null) return dayChangeBasisPoints!;
    if (closeValuesMinor.length < 2 || closeValuesMinor.first == 0) return 0;
    final first = closeValuesMinor.first;
    return ((closeValuesMinor.last - first) * 10000 / first).round();
  }
}

abstract interface class AssetMarketRepository {
  Future<Map<String, AssetMarketSeries>> latestFor(
    List<InstrumentIdentity> identities, {
    bool includeHistory = true,
    bool forceRefresh = false,
  });
}
