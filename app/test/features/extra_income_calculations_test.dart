import 'package:flutter_test/flutter_test.dart';
import 'package:oscar_financas/core/money/money.dart';
import 'package:oscar_financas/core/time/year_month.dart';
import 'package:oscar_financas/features/screen_2_extra_income/domain/extra_income_entry.dart';

void main() {
  const month = YearMonth(2027, 4);

  test('services 350 and sales 650 produce 35 and 65 percent', () {
    const entries = [
      ExtraIncomeEntry(
        id: 'service',
        kind: ExtraIncomeKind.service,
        name: 'Service',
        description: '',
        amountMinor: 35000,
        currency: CurrencyCode.brl,
        month: month,
        includeInFinancialIncome: true,
      ),
      ExtraIncomeEntry(
        id: 'sale',
        kind: ExtraIncomeKind.sale,
        name: 'Sale',
        description: '',
        amountMinor: 65000,
        currency: CurrencyCode.brl,
        month: month,
      ),
    ];
    final summary = ExtraIncomeCalculator.summarize(entries);

    expect(summary.totalMinor, 100000);
    expect(summary.serviceBasisPoints, 3500);
    expect(summary.saleBasisPoints, 6500);
    expect(summary.includedInFinancialMinor, 35000);
  });

  test('recurrence creates one stable occurrence id per month', () {
    const template = ExtraIncomeRecurrenceTemplate(
      id: 'template-1',
      kind: ExtraIncomeKind.service,
      name: 'Monthly service',
      description: '',
      amountMinor: 50000,
      currency: CurrencyCode.brl,
      startMonth: month,
      includeInFinancialIncome: true,
    );
    expect(template.occurrenceFor(month).id, template.occurrenceFor(month).id);
    expect(
      template.occurrenceFor(const YearMonth(2027, 5)).id,
      'template-1:2027-05',
    );
  });
}
