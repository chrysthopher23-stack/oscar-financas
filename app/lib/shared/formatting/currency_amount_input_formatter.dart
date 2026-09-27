import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Formats whole currency units while the user types.
/// Typing `3480` becomes `3.480` in pt-BR and `3,480` in en-US.
final class CurrencyAmountInputFormatter extends TextInputFormatter {
  CurrencyAmountInputFormatter(this.locale, {this.allowNegative = false})
    : _format = NumberFormat.decimalPattern(locale)..maximumFractionDigits = 0;

  final String locale;
  final bool allowNegative;
  final NumberFormat _format;

  String get _decimal => _format.symbols.DECIMAL_SEP;
  String get _group => _format.symbols.GROUP_SEP;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    final negative = allowNegative && newValue.text.trimLeft().startsWith('-');
    var raw = newValue.text.replaceAll(_group, '');
    raw = raw.replaceAll(RegExp('[^0-9${RegExp.escape(_decimal)}]'), '');
    final firstSeparator = raw.indexOf(_decimal);
    if (firstSeparator >= 0) {
      raw =
          '${raw.substring(0, firstSeparator)}$_decimal${raw.substring(firstSeparator + 1).replaceAll(_decimal, '')}';
    }
    final parts = raw.split(_decimal);
    final wholeDigits = parts.first.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final whole = int.tryParse(wholeDigits.isEmpty ? '0' : wholeDigits) ?? 0;
    var formatted = _format.format(whole);
    if (parts.length > 1) {
      formatted +=
          '$_decimal${parts[1].substring(0, parts[1].length.clamp(0, 2))}';
    }
    if (negative && formatted != '0') formatted = '-$formatted';
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

int parseCurrencyMinor(String input, String locale) {
  final symbols = NumberFormat.decimalPattern(locale).symbols;
  final normalized = input
      .trim()
      .replaceAll(symbols.GROUP_SEP, '')
      .replaceAll(symbols.DECIMAL_SEP, '.');
  final value = num.tryParse(normalized) ?? 0;
  return (value * 100).round();
}

String formatCurrencyInputMinor(int minorUnits, String locale) {
  final format = NumberFormat.decimalPattern(locale)
    ..minimumFractionDigits = 2
    ..maximumFractionDigits = 2;
  return format.format(minorUnits / 100);
}
