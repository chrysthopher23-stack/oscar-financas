import '../../../core/money/money.dart';
import '../../../core/time/year_month.dart';

enum ExtraIncomeKind { service, sale }

final class ExtraIncomeEntry {
  const ExtraIncomeEntry({
    required this.id,
    required this.kind,
    required this.name,
    required this.description,
    required this.amountMinor,
    required this.currency,
    required this.month,
    this.recurring = false,
    this.includeInFinancialIncome = false,
    this.recurrenceTemplateId,
    this.deletedAt,
  });

  final String id;
  final ExtraIncomeKind kind;
  final String name;
  final String description;
  final int amountMinor;
  final CurrencyCode currency;
  final YearMonth month;
  final bool recurring;
  final bool includeInFinancialIncome;
  final String? recurrenceTemplateId;
  final DateTime? deletedAt;

  bool get active => deletedAt == null;

  ExtraIncomeEntry copyWith({DateTime? deletedAt, bool restore = false}) =>
      ExtraIncomeEntry(
        id: id,
        kind: kind,
        name: name,
        description: description,
        amountMinor: amountMinor,
        currency: currency,
        month: month,
        recurring: recurring,
        includeInFinancialIncome: includeInFinancialIncome,
        recurrenceTemplateId: recurrenceTemplateId,
        deletedAt: restore ? null : deletedAt ?? this.deletedAt,
      );
}

final class ExtraIncomeSummary {
  const ExtraIncomeSummary({
    required this.servicesMinor,
    required this.salesMinor,
    required this.includedInFinancialMinor,
  });

  final int servicesMinor;
  final int salesMinor;
  final int includedInFinancialMinor;

  int get totalMinor => servicesMinor + salesMinor;
  int get serviceBasisPoints =>
      totalMinor == 0 ? 0 : (servicesMinor * 10000) ~/ totalMinor;
  int get saleBasisPoints =>
      totalMinor == 0 ? 0 : (salesMinor * 10000) ~/ totalMinor;
}

abstract final class ExtraIncomeCalculator {
  static ExtraIncomeSummary summarize(Iterable<ExtraIncomeEntry> entries) {
    var services = 0;
    var sales = 0;
    var included = 0;
    for (final entry in entries.where((item) => item.active)) {
      if (entry.kind == ExtraIncomeKind.service) {
        services += entry.amountMinor;
      } else {
        sales += entry.amountMinor;
      }
      if (entry.includeInFinancialIncome) included += entry.amountMinor;
    }
    return ExtraIncomeSummary(
      servicesMinor: services,
      salesMinor: sales,
      includedInFinancialMinor: included,
    );
  }
}

final class ExtraIncomeRecurrenceTemplate {
  const ExtraIncomeRecurrenceTemplate({
    required this.id,
    required this.kind,
    required this.name,
    required this.description,
    required this.amountMinor,
    required this.currency,
    required this.startMonth,
    required this.includeInFinancialIncome,
    this.active = true,
  });

  final String id;
  final ExtraIncomeKind kind;
  final String name;
  final String description;
  final int amountMinor;
  final CurrencyCode currency;
  final YearMonth startMonth;
  final bool includeInFinancialIncome;
  final bool active;

  ExtraIncomeEntry occurrenceFor(YearMonth month) {
    if (!active || month.compareTo(startMonth) < 0) {
      throw StateError('Template is not active for this month.');
    }
    return ExtraIncomeEntry(
      id: '$id:${month.databaseKey}',
      kind: kind,
      name: name,
      description: description,
      amountMinor: amountMinor,
      currency: currency,
      month: month,
      recurring: true,
      includeInFinancialIncome: includeInFinancialIncome,
      recurrenceTemplateId: id,
    );
  }
}
