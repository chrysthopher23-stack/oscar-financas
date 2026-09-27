import 'package:flutter_test/flutter_test.dart';
import 'package:oscar_financas/core/money/money.dart';

void main() {
  group('Money', () {
    test('adds values only in the same currency', () {
      const income = Money(minorUnits: 500000, currency: CurrencyCode.brl);
      const extra = Money(minorUnits: 12550, currency: CurrencyCode.brl);

      expect((income + extra).minorUnits, 512550);
    });

    test('rejects combining different currencies', () {
      const brl = Money(minorUnits: 100, currency: CurrencyCode.brl);
      const usd = Money(minorUnits: 100, currency: CurrencyCode.usd);

      expect(() => brl + usd, throwsArgumentError);
    });

    test('never stores money as floating point', () {
      const value = Money(minorUnits: 142000, currency: CurrencyCode.brl);
      expect(value.minorUnits, isA<int>());
    });
  });
}
