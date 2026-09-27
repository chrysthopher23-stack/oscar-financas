import 'package:flutter_test/flutter_test.dart';
import 'package:oscar_financas/shared/formatting/installment_formatter.dart';

void main() {
  test('stores installment progress without a language', () {
    final stored = encodeInstallmentProgress(5, 36);
    expect(stored, '5/36');
    expect(parseInstallmentProgress(stored), (current: 5, total: 36));
  });

  test('rejects an installment greater than the total', () {
    expect(parseInstallmentProgress('37/36'), isNull);
  });

  test('advances through following months and stops at the total', () {
    expect(advanceInstallmentProgress('12/48', elapsedMonths: 1), (
      current: 13,
      total: 48,
    ));
    expect(advanceInstallmentProgress('12/48', elapsedMonths: 3), (
      current: 15,
      total: 48,
    ));
    expect(advanceInstallmentProgress('48/48', elapsedMonths: 1), isNull);
    expect(advanceInstallmentProgress('47/48', elapsedMonths: 2), isNull);
  });

  test('calculates elapsed months across years', () {
    expect(
      monthsBetween(fromYear: 2026, fromMonth: 11, toYear: 2027, toMonth: 2),
      3,
    );
  });

  const labels = <String, String>{
    'pt_BR': 'Parcela 5 de 36',
    'en_US': 'Installment 5 of 36',
    'de_DE': 'Rate 5 von 36',
    'fr_FR': 'Échéance 5 sur 36',
    'hi_IN': '36 में से किस्त 5',
  };

  for (final entry in labels.entries) {
    test('${entry.key}: presents installment progress locally', () {
      expect(installmentProgressText('5/36', entry.key), entry.value);
    });
  }
}
