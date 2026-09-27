import 'package:flutter_test/flutter_test.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/crypto_amount.dart';

void main() {
  test('fractional crypto quantities and sub-cent prices retain precision', () {
    expect(CryptoAmount.valueMinor('0.00000001', '60000'), 0);
    expect(CryptoAmount.valueMinor('0.5', '60000'), 3000000);
    expect(CryptoAmount.valueMinor('1000000', '0.00000015'), 15);
    expect(CryptoAmount.valueMinor('1000000', '1.5e-7'), 15);
    expect(CryptoAmount.validQuantity('0'), isFalse);
    expect(CryptoAmount.validQuantity('-1'), isFalse);
    expect(CryptoAmount.validQuantity('0.000000000000000001'), isTrue);
  });
}
