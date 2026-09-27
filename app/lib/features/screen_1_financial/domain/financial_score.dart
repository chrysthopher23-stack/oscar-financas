import 'monthly_summary.dart';

enum FinancialScoreLevel { critical, tight, balanced, healthy, prosperous }

final class FinancialScoreResult {
  const FinancialScoreResult({
    required this.calculated,
    required this.basisPoints,
    required this.level,
    required this.deficitMinor,
  });

  final bool calculated;
  final int basisPoints;
  final FinancialScoreLevel? level;
  final int deficitMinor;

  int get roundedScore => (basisPoints + 50) ~/ 100;
}

abstract final class FinancialScoreCalculator {
  static FinancialScoreResult calculate(MonthlySummary summary) {
    if (summary.grossIncomeMinor == 0) {
      return FinancialScoreResult(
        calculated: false,
        basisPoints: 0,
        level: null,
        deficitMinor: summary.deficitMinor,
      );
    }
    final points = summary.savingsRateBasisPoints.clamp(0, 10000);
    final level = switch (points) {
      < 1000 => FinancialScoreLevel.critical,
      < 3000 => FinancialScoreLevel.tight,
      < 5000 => FinancialScoreLevel.balanced,
      <= 7000 => FinancialScoreLevel.healthy,
      _ => FinancialScoreLevel.prosperous,
    };
    return FinancialScoreResult(
      calculated: true,
      basisPoints: points,
      level: level,
      deficitMinor: summary.deficitMinor,
    );
  }
}
