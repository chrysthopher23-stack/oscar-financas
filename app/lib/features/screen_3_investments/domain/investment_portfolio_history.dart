import '../../../core/time/year_month.dart';
import 'investment_position.dart';

final class PortfolioHistoryPoint {
  const PortfolioHistoryPoint({
    required this.month,
    required this.principalMinor,
    required this.returnMinor,
  });

  final YearMonth month;
  final int principalMinor;
  final int returnMinor;
  int get valueMinor => principalMinor + returnMinor;
}

/// Builds a rolling cumulative history from the saved monthly contributions.
/// It intentionally excludes market revaluation because historical quotes are
/// not stored for these positions.
List<PortfolioHistoryPoint> buildPortfolioHistory(
  Iterable<InvestmentPosition> positions, {
  required YearMonth throughMonth,
  int? monthCount = 6,
}) {
  if (monthCount != null && monthCount < 1) return const [];
  final active = positions.where((position) => position.active).toList();
  if (active.isEmpty && monthCount == null) return const [];
  final earliest = active.fold<YearMonth>(
    throughMonth,
    (first, position) =>
        position.month.compareTo(first) < 0 ? position.month : first,
  );
  final firstMonth = monthCount == null
      ? earliest
      : throughMonth.addMonths(1 - monthCount);
  final count =
      monthCount ??
      (throughMonth.year - firstMonth.year) * 12 +
          throughMonth.month -
          firstMonth.month +
          1;
  final points = <PortfolioHistoryPoint>[];
  for (var index = 0; index < count; index++) {
    final month = firstMonth.addMonths(index);
    final included = active.where(
      (position) => position.month.compareTo(month) <= 0,
    );
    points.add(
      PortfolioHistoryPoint(
        month: month,
        principalMinor: included.fold(
          0,
          (sum, position) => sum + position.principalMinor,
        ),
        returnMinor: included.fold(
          0,
          (sum, position) => sum + position.monthlyReturnMinor,
        ),
      ),
    );
  }
  return List.unmodifiable(points);
}
