import 'instrument_identity.dart';

abstract interface class AssetCatalogRepository {
  Future<List<InstrumentIdentity>> search(String query, {int limit = 20});
}

final class LocalAssetCatalogRepository implements AssetCatalogRepository {
  const LocalAssetCatalogRepository(this.entries);

  final List<InstrumentIdentity> entries;

  @override
  Future<List<InstrumentIdentity>> search(
    String query, {
    int limit = 20,
  }) async {
    final normalized = _normalize(query);
    final ranked = <({InstrumentIdentity item, int rank})>[];
    for (final item in entries) {
      final terms = item.searchableTerms
          .map(_normalize)
          .where((v) => v.isNotEmpty);
      var rank = 99;
      for (final term in terms) {
        if (term == normalized) {
          rank = 0;
        } else if (term.startsWith(normalized) && rank > 1) {
          rank = 1;
        } else if (term.contains(normalized) && rank > 2) {
          rank = 2;
        }
      }
      if (normalized.isEmpty) rank = 3;
      if (rank < 99) ranked.add((item: item, rank: rank));
    }
    ranked.sort((a, b) {
      final byRank = a.rank.compareTo(b.rank);
      return byRank != 0 ? byRank : a.item.symbol.compareTo(b.item.symbol);
    });
    return ranked
        .take(limit)
        .map((result) => result.item)
        .toList(growable: false);
  }

  static String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\u00c0-\u024f]'), '');
}
