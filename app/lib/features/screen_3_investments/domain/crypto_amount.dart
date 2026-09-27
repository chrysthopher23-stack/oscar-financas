/// Exact decimal multiplication. Asset quantities are never rounded to cents.
abstract final class CryptoAmount {
  static ({BigInt numerator, BigInt denominator}) _decimal(String value) {
    final match = RegExp(r'^(\d+)(?:\.(\d+))?(?:[eE]([+-]?\d+))?$')
        .firstMatch(value);
    if (match == null) throw const FormatException('Invalid decimal');
    final fraction = match[2] ?? '';
    final exponent = int.parse(match[3] ?? '0');
    if (exponent.abs() > 100 || fraction.length > 100) {
      throw const FormatException('Decimal out of range');
    }
    final power = fraction.length - exponent;
    final integer = BigInt.parse('${match[1]}$fraction');
    return power >= 0
        ? (numerator: integer, denominator: BigInt.from(10).pow(power))
        : (
            numerator: integer * BigInt.from(10).pow(-power),
            denominator: BigInt.one,
          );
  }

  static bool validQuantity(String value) {
    if (!RegExp(r'^\d{1,18}(?:\.\d{1,18})?$').hasMatch(value)) return false;
    return _decimal(value).numerator > BigInt.zero;
  }

  static int valueMinor(String quantity, String unitPrice) {
    final q = _decimal(quantity);
    final p = _decimal(unitPrice);
    final numerator = q.numerator * p.numerator * BigInt.from(100);
    final denominator = q.denominator * p.denominator;
    final rounded = (numerator + denominator ~/ BigInt.two) ~/ denominator;
    if (rounded > BigInt.parse('9007199254740991')) {
      throw const FormatException('Amount out of range');
    }
    return rounded.toInt();
  }
}
