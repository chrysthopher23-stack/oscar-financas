import 'dart:math' as math;

import '../../../core/money/money.dart';
import '../../../core/time/year_month.dart';

enum ObjectiveContributionFrequency { once, monthly }

final class FinancialObjective {
  const FinancialObjective({
    required this.id,
    required this.name,
    required this.instrument,
    required this.targetMonths,
    required this.initialBalanceMinor,
    required this.targetAmountMinor,
    required this.annualRateBasisPoints,
    required this.monthlyContributionMinor,
    required this.frequency,
    required this.startMonth,
    required this.currency,
    this.monthlyOverrides = const {},
    this.importedFromExpenseHistory = false,
  });

  final String id;
  final String name;
  final String instrument;
  final int targetMonths;
  final int initialBalanceMinor;
  final int targetAmountMinor;
  final int annualRateBasisPoints;
  final int monthlyContributionMinor;
  final ObjectiveContributionFrequency frequency;
  final YearMonth startMonth;
  final CurrencyCode currency;
  final Map<String, ObjectiveMonthOverride> monthlyOverrides;
  final bool importedFromExpenseHistory;

  FinancialObjective copyWith({
    String? name,
    String? instrument,
    int? targetMonths,
    int? initialBalanceMinor,
    int? targetAmountMinor,
    int? annualRateBasisPoints,
    int? monthlyContributionMinor,
    ObjectiveContributionFrequency? frequency,
    YearMonth? startMonth,
    CurrencyCode? currency,
    Map<String, ObjectiveMonthOverride>? monthlyOverrides,
  }) => FinancialObjective(
    id: id,
    name: name ?? this.name,
    instrument: instrument ?? this.instrument,
    targetMonths: targetMonths ?? this.targetMonths,
    initialBalanceMinor: initialBalanceMinor ?? this.initialBalanceMinor,
    targetAmountMinor: targetAmountMinor ?? this.targetAmountMinor,
    annualRateBasisPoints: annualRateBasisPoints ?? this.annualRateBasisPoints,
    monthlyContributionMinor:
        monthlyContributionMinor ?? this.monthlyContributionMinor,
    frequency: frequency ?? this.frequency,
    startMonth: startMonth ?? this.startMonth,
    currency: currency ?? this.currency,
    monthlyOverrides: monthlyOverrides ?? this.monthlyOverrides,
    importedFromExpenseHistory: importedFromExpenseHistory,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'instrument': instrument,
    'targetMonths': targetMonths,
    'initialBalanceMinor': initialBalanceMinor,
    'targetAmountMinor': targetAmountMinor,
    'annualRateBasisPoints': annualRateBasisPoints,
    'monthlyContributionMinor': monthlyContributionMinor,
    'frequency': frequency.name,
    'startYear': startMonth.year,
    'startMonth': startMonth.month,
    'currency': currency.name,
    'monthlyOverrides': {
      for (final entry in monthlyOverrides.entries)
        entry.key: entry.value.toJson(),
    },
    'importedFromExpenseHistory': importedFromExpenseHistory,
  };

  factory FinancialObjective.fromJson(Map<String, dynamic> json) {
    final rawOverrides = json['monthlyOverrides'];
    final overrides = <String, ObjectiveMonthOverride>{};
    if (rawOverrides is Map) {
      for (final entry in rawOverrides.entries) {
        if (entry.value is Map) {
          overrides[entry.key.toString()] = ObjectiveMonthOverride.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          );
        }
      }
    }
    return FinancialObjective(
      id: json['id'] as String,
      name: json['name'] as String,
      instrument: json['instrument'] as String? ?? '',
      targetMonths: (json['targetMonths'] as num).toInt(),
      initialBalanceMinor: (json['initialBalanceMinor'] as num).toInt(),
      targetAmountMinor: (json['targetAmountMinor'] as num).toInt(),
      annualRateBasisPoints: (json['annualRateBasisPoints'] as num).toInt(),
      monthlyContributionMinor:
          (json['monthlyContributionMinor'] as num?)?.toInt() ?? 0,
      frequency: ObjectiveContributionFrequency.values.byName(
        json['frequency'] as String? ?? 'once',
      ),
      startMonth: YearMonth(
        (json['startYear'] as num).toInt(),
        (json['startMonth'] as num).toInt(),
      ),
      currency: CurrencyCode.values.byName(
        json['currency'] as String? ?? CurrencyCode.brl.name,
      ),
      monthlyOverrides: Map.unmodifiable(overrides),
      importedFromExpenseHistory:
          json['importedFromExpenseHistory'] as bool? ?? false,
    );
  }
}

final class ObjectiveMonthOverride {
  const ObjectiveMonthOverride({
    required this.contributionMinor,
    this.yieldMinor,
  });

  final int contributionMinor;
  final int? yieldMinor;

  Map<String, Object?> toJson() => {
    'contributionMinor': contributionMinor,
    'yieldMinor': yieldMinor,
  };

  factory ObjectiveMonthOverride.fromJson(Map<String, dynamic> json) =>
      ObjectiveMonthOverride(
        contributionMinor: (json['contributionMinor'] as num).toInt(),
        yieldMinor: (json['yieldMinor'] as num?)?.toInt(),
      );
}

final class ObjectiveMonthSnapshot {
  const ObjectiveMonthSnapshot({
    required this.month,
    required this.contributionMinor,
    required this.yieldMinor,
    required this.closingBalanceMinor,
    required this.yieldIsEstimate,
  });

  final YearMonth month;
  final int contributionMinor;
  final int yieldMinor;
  final int closingBalanceMinor;
  final bool yieldIsEstimate;
}

abstract final class ObjectiveEvolution {
  static List<ObjectiveMonthSnapshot> calculate(
    FinancialObjective objective, {
    required YearMonth throughMonth,
  }) {
    if (objective.startMonth.compareTo(throughMonth) > 0) return const [];
    var balance = objective.initialBalanceMinor;
    final history = <ObjectiveMonthSnapshot>[];
    var month = objective.startMonth;
    while (month.compareTo(throughMonth) <= 0) {
      final key = month.databaseKey;
      final override = objective.monthlyOverrides[key];
      final plannedContribution =
          objective.frequency == ObjectiveContributionFrequency.monthly ||
              month == objective.startMonth
          ? objective.monthlyContributionMinor
          : 0;
      final contribution = override?.contributionMinor ?? plannedContribution;
      final baseForYield = balance + contribution;
      final estimatedYield = objective.annualRateBasisPoints == 0
          ? 0
          : (baseForYield * (_monthlyRate(objective.annualRateBasisPoints)))
                .round();
      final yieldMinor = override?.yieldMinor ?? estimatedYield;
      balance += contribution + yieldMinor;
      history.add(
        ObjectiveMonthSnapshot(
          month: month,
          contributionMinor: contribution,
          yieldMinor: yieldMinor,
          closingBalanceMinor: balance,
          yieldIsEstimate: override?.yieldMinor == null,
        ),
      );
      month = month.addMonths(1);
    }
    return List.unmodifiable(history);
  }

  static double _monthlyRate(int annualBasisPoints) =>
      math.pow(1 + annualBasisPoints / 10000, 1 / 12).toDouble() - 1;
}
