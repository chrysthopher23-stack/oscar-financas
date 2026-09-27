import '../domain/asset_market_series.dart';
import '../domain/instrument_identity.dart';
import '../domain/asset_family.dart';

/// Uses HG for Brazilian assets and Alpha Vantage for global assets/fallback.
final class RoutedAssetMarketRepository implements AssetMarketRepository {
  const RoutedAssetMarketRepository({
    required this.brazilianRepository,
    required this.globalRepository,
    this.cryptoRepository,
  });

  final AssetMarketRepository brazilianRepository;
  final AssetMarketRepository globalRepository;
  final AssetMarketRepository? cryptoRepository;

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
    }.values.toList(growable: false);
    final brazilian = unique
        .where(
          (identity) =>
              identity.countryCode.toUpperCase() == 'BR' &&
              identity.exchangeMic == 'BVMF',
        )
        .toList(growable: false);
    final international = unique
        .where(
          (identity) =>
              !brazilian.contains(identity) &&
              identity.family != AssetFamily.crypto,
        )
        .toList(growable: false);

    final internationalFuture = international.isEmpty
        ? Future.value(<String, AssetMarketSeries>{})
        : globalRepository.latestFor(international, forceRefresh: forceRefresh);
    final fromBrazil = await brazilianRepository.latestFor(
      brazilian,
      forceRefresh: forceRefresh,
    );
    final missingBrazil = brazilian
        .where((identity) => !fromBrazil.containsKey(identity.providerAssetId))
        .toList(growable: false);
    final results = <String, AssetMarketSeries>{
      ...await internationalFuture,
      ...fromBrazil,
      if (cryptoRepository != null)
        ...await cryptoRepository!.latestFor(
          unique.where((item) => item.family == AssetFamily.crypto).toList(),
          includeHistory: includeHistory,
          forceRefresh: forceRefresh,
        ),
    };
    if (missingBrazil.isNotEmpty) {
      results.addAll(
        await globalRepository.latestFor(
          missingBrazil,
          forceRefresh: forceRefresh,
        ),
      );
    }
    return results;
  }
}
