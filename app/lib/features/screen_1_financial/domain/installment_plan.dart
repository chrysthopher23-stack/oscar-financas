import '../../../core/time/year_month.dart';

final class InstallmentOccurrence {
  const InstallmentOccurrence({
    required this.number,
    required this.totalCount,
    required this.month,
    required this.amountMinor,
  });

  final int number;
  final int totalCount;
  final YearMonth month;
  final int amountMinor;
}

abstract final class InstallmentCalculator {
  static List<InstallmentOccurrence> distribute({
    required int totalMinor,
    required int count,
    required YearMonth firstMonth,
  }) {
    if (totalMinor < 0 || count <= 0) {
      throw ArgumentError('Invalid installment plan.');
    }
    final base = totalMinor ~/ count;
    final remainder = totalMinor - base * count;
    return [
      for (var index = 0; index < count; index++)
        InstallmentOccurrence(
          number: index + 1,
          totalCount: count,
          month: firstMonth.addMonths(index),
          amountMinor: base + (index == count - 1 ? remainder : 0),
        ),
    ];
  }
}
