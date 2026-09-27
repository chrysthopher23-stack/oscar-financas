import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:oscar_financas/shared/formatting/currency_amount_input_formatter.dart';

void main() {
  const grouped = <String, String>{
    'pt_BR': '3.480',
    'en_US': '3,480',
    'de_DE': '3.480',
    'fr_FR': '3\u202f480',
    'hi_IN': '3,480',
  };

  for (final entry in grouped.entries) {
    test('${entry.key}: formats and parses whole currency units', () {
      final formatter = CurrencyAmountInputFormatter(entry.key);
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '3480'),
      );
      expect(result.text, entry.value);
      expect(parseCurrencyMinor(result.text, entry.key), 348000);
      expect(
        parseCurrencyMinor(
          formatCurrencyInputMinor(348000, entry.key),
          entry.key,
        ),
        348000,
      );
    });

    test('${entry.key}: keeps two decimal digits when entered', () {
      final decimal = NumberFormat.decimalPattern(entry.key)
          .symbols
          .DECIMAL_SEP;
      final formatter = CurrencyAmountInputFormatter(entry.key);
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(text: '3480${decimal}50'),
      );
      expect(parseCurrencyMinor(result.text, entry.key), 348050);
    });
  }
}
