import 'instrument_identity.dart';
import 'investment_position.dart';

/// A display-only aggregation of all saved positions for one instrument.
/// The original positions remain separate and retain their own IDs for undo
/// and deletion actions.
final class InvestmentHolding {
  InvestmentHolding._(this.instrumentKey, List<InvestmentPosition> positions)
    : positions = List.unmodifiable(positions),
      identity = positions.first.identity,
      principalMinor = positions.fold(
        0,
        (total, position) => total + position.principalMinor,
      ),
      monthlyReturnMinor = positions.fold(
        0,
        (total, position) => total + position.monthlyReturnMinor,
      ),
      currentValueMinor = positions.fold(
        0,
        (total, position) => total + position.currentValueMinor,
      ),
      quantity = _sumQuantities(positions.map((position) => position.quantity));

  final String instrumentKey;
  final List<InvestmentPosition> positions;
  final InstrumentIdentity identity;
  final int principalMinor;
  final int monthlyReturnMinor;
  final int currentValueMinor;
  final String? quantity;

  static List<InvestmentHolding> group(Iterable<InvestmentPosition> source) {
    final groups = <String, List<InvestmentPosition>>{};
    for (final position in source.where((position) => position.active)) {
      final key = investmentInstrumentKey(position.identity);
      groups.putIfAbsent(key, () => []).add(position);
    }
    return List.unmodifiable(
      groups.entries.map(
        (entry) => InvestmentHolding._(entry.key, entry.value),
      ),
    );
  }

  static String? _sumQuantities(Iterable<String?> source) {
    final values = source.toList(growable: false);
    if (values.isEmpty || values.any((value) => value == null)) return null;
    final decimals = values.cast<String>().map(_Decimal.parse).toList();
    final scale = decimals.fold<int>(
      0,
      (max, value) => value.scale > max ? value.scale : max,
    );
    final total = decimals.fold<BigInt>(
      BigInt.zero,
      (sum, value) =>
          sum + value.units * BigInt.from(10).pow(scale - value.scale),
    );
    if (scale == 0) return total.toString();
    final digits = total.toString().padLeft(scale + 1, '0');
    final whole = digits.substring(0, digits.length - scale);
    final fraction = digits
        .substring(digits.length - scale)
        .replaceFirst(RegExp(r'0+$'), '');
    return fraction.isEmpty ? whole : '$whole.$fraction';
  }
}

int uniqueInvestmentInstrumentCount(Iterable<InvestmentPosition> positions) =>
    positions
        .map((position) => investmentInstrumentKey(position.identity))
        .toSet()
        .length;

String investmentInstrumentKey(InstrumentIdentity identity) {
  final family = identity.family.storageValue;
  final providerId = identity.providerAssetId.trim().toLowerCase();
  if (providerId.isNotEmpty) return '$family|provider:$providerId';
  final isin = identity.isin?.trim().toUpperCase();
  if (isin != null && isin.isNotEmpty) return '$family|isin:$isin';
  return [
    family,
    identity.symbol.trim().toUpperCase(),
    identity.exchangeMic.trim().toUpperCase(),
    identity.countryCode.trim().toUpperCase(),
    identity.currency.isoCode,
  ].join('|');
}

final class _Decimal {
  const _Decimal(this.units, this.scale);

  final BigInt units;
  final int scale;

  factory _Decimal.parse(String value) {
    final match = RegExp(r'^(\d+)(?:\.(\d+))?$').firstMatch(value);
    if (match == null) throw FormatException('Invalid asset quantity: $value');
    final fraction = match[2] ?? '';
    return _Decimal(BigInt.parse('${match[1]}$fraction'), fraction.length);
  }
}
