enum CurrencyCode {
  brl(symbol: r'R$', decimalDigits: 2),
  usd(symbol: r'$', decimalDigits: 2),
  eur(symbol: '€', decimalDigits: 2),
  inr(symbol: '₹', decimalDigits: 2);

  const CurrencyCode({required this.symbol, required this.decimalDigits});

  final String symbol;
  final int decimalDigits;

  String get isoCode => name.toUpperCase();
}

final class Money implements Comparable<Money> {
  const Money({required this.minorUnits, required this.currency});

  const Money.zero(CurrencyCode currency)
    : this(minorUnits: 0, currency: currency);

  final int minorUnits;
  final CurrencyCode currency;

  Money operator +(Money other) {
    _requireSameCurrency(other);
    return Money(minorUnits: minorUnits + other.minorUnits, currency: currency);
  }

  Money operator -(Money other) {
    _requireSameCurrency(other);
    return Money(minorUnits: minorUnits - other.minorUnits, currency: currency);
  }

  Money clampAtZero() => minorUnits < 0 ? Money.zero(currency) : this;

  @override
  int compareTo(Money other) {
    _requireSameCurrency(other);
    return minorUnits.compareTo(other.minorUnits);
  }

  void _requireSameCurrency(Money other) {
    if (currency != other.currency) {
      throw ArgumentError(
        'Money with different currencies cannot be combined.',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Money &&
      minorUnits == other.minorUnits &&
      currency == other.currency;

  @override
  int get hashCode => Object.hash(minorUnits, currency);
}
