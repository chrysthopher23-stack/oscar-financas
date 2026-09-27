import 'package:flutter_test/flutter_test.dart';
import 'package:oscar_financas/core/time/year_month.dart';

void main() {
  test('moves across year boundaries deterministically', () {
    expect(const YearMonth(2026, 12).addMonths(1), const YearMonth(2027, 1));
    expect(const YearMonth(2027, 1).addMonths(-2), const YearMonth(2026, 11));
  });
}
