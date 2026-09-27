import '../../../core/money/money.dart';

enum QuoteStatus { current, cached, stale, unavailable }

final class FxQuoteSet {
  FxQuoteSet({
    required this.base,
    required Map<CurrencyCode, int> unitsPerBaseScaled,
    required this.observedAt,
    required this.status,
  }) : unitsPerBaseScaled = Map.unmodifiable(unitsPerBaseScaled) {
    for (final currency in CurrencyCode.values) {
      if (!this.unitsPerBaseScaled.containsKey(currency)) {
        throw ArgumentError('FxQuoteSet incompleto: ${currency.isoCode}.');
      }
    }
    if (this.unitsPerBaseScaled[base] != scale) {
      throw ArgumentError('A cotação da moeda base deve ser 1.');
    }
  }

  static const scale = 1000000000;
  final CurrencyCode base;
  final Map<CurrencyCode, int> unitsPerBaseScaled;
  final DateTime observedAt;
  final QuoteStatus status;

  int? convertMinor(int amountMinor, CurrencyCode target) {
    final rate = unitsPerBaseScaled[target];
    if (rate == null || rate <= 0) return null;
    final numerator = BigInt.from(amountMinor) * BigInt.from(rate);
    final denominator = BigInt.from(scale);
    final negative = numerator.isNegative;
    final absolute = numerator.abs();
    final rounded = (absolute + denominator ~/ BigInt.two) ~/ denominator;
    return (negative ? -rounded : rounded).toInt();
  }

  int? convertToBaseMinor(int amountMinor, CurrencyCode source) {
    final sourceUnitsPerBase = unitsPerBaseScaled[source];
    if (sourceUnitsPerBase == null || sourceUnitsPerBase <= 0) return null;
    final numerator = BigInt.from(amountMinor) * BigInt.from(scale);
    final denominator = BigInt.from(sourceUnitsPerBase);
    final negative = numerator.isNegative;
    final absolute = numerator.abs();
    final rounded = (absolute + denominator ~/ BigInt.two) ~/ denominator;
    return (negative ? -rounded : rounded).toInt();
  }
}

abstract interface class FxRepository {
  Future<FxQuoteSet?> latest(CurrencyCode base, {bool forceRefresh = false});
}

/// Availability of a manual refresh, based on the last successful fetch.
abstract interface class FxRefreshSchedule {
  Future<DateTime?> nextRefreshAt();
}

final class OfflineDemonstrationFxRepository implements FxRepository {
  const OfflineDemonstrationFxRepository();

  @override
  Future<FxQuoteSet> latest(
    CurrencyCode base, {
    bool forceRefresh = false,
  }) async {
    const brlPerUnit = {
      CurrencyCode.brl: 1000000000,
      CurrencyCode.usd: 5200000000,
      CurrencyCode.eur: 6100000000,
      CurrencyCode.inr: 62000000,
    };
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
      observedAt: DateTime(2026, 1, 1),
      status: QuoteStatus.stale,
    );
  }
}
