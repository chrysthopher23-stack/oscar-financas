import 'package:flutter_test/flutter_test.dart';
import 'package:oscar_financas/core/money/money.dart';
import 'package:oscar_financas/shared/formatting/money_formatter.dart';

void main() {
  test(
    'INR uses Indian digit grouping even when app language is Portuguese',
    () {
      final formatter = MoneyFormatter(
        locale: 'pt_BR',
        currency: CurrencyCode.inr,
      );

      expect(formatter.formatMinor(131392044), contains('13,13,920'));
      expect(formatter.formatMinor(131392044), contains('₹'));
      expect(formatter.formatCompactMinor(131392044), contains('₹'));
    },
  );
}
