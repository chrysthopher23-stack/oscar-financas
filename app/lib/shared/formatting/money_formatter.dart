import 'package:intl/intl.dart';

import '../../core/money/money.dart';

final class MoneyFormatter {
  MoneyFormatter({required String locale, required CurrencyCode currency})
    : _locale = currency == CurrencyCode.inr ? 'hi_IN' : locale,
      _currency = currency,
      _format = NumberFormat.simpleCurrency(
        locale: currency == CurrencyCode.inr ? 'hi_IN' : locale,
        name: currency.isoCode,
        decimalDigits: currency.decimalDigits,
      );

  final String _locale;
  final CurrencyCode _currency;
  final NumberFormat _format;

  String formatMinor(int minorUnits) {
    final divisor = _currency.decimalDigits == 0 ? 1 : 100;
    return _format.format(minorUnits / divisor);
  }

  String formatCompactMinor(num minorUnits) {
    final divisor = _currency.decimalDigits == 0 ? 1 : 100;
    return NumberFormat.compactCurrency(
      locale: _locale,
      name: _currency.isoCode,
      symbol: _currency.symbol,
      decimalDigits: 0,
    ).format(minorUnits / divisor);
  }
}
