final class YearMonth implements Comparable<YearMonth> {
  const YearMonth(this.year, this.month)
    : assert(month >= 1 && month <= 12, 'Month must be between 1 and 12.');

  factory YearMonth.now([DateTime? clock]) {
    final value = clock ?? DateTime.now();
    return YearMonth(value.year, value.month);
  }

  final int year;
  final int month;

  String get databaseKey => '$year-${month.toString().padLeft(2, '0')}';

  YearMonth addMonths(int offset) {
    final zeroBased = year * 12 + month - 1 + offset;
    return YearMonth(zeroBased ~/ 12, zeroBased % 12 + 1);
  }

  @override
  int compareTo(YearMonth other) => year == other.year
      ? month.compareTo(other.month)
      : year.compareTo(other.year);

  @override
  bool operator ==(Object other) =>
      other is YearMonth && year == other.year && month == other.month;

  @override
  int get hashCode => Object.hash(year, month);
}
