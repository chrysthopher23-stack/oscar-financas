enum RatePeriodicity { monthly, annual }

final class ProjectionPoint {
  const ProjectionPoint({
    required this.monthIndex,
    required this.principalMinor,
    required this.earningsMinor,
  });

  final int monthIndex;
  final int principalMinor;
  final int earningsMinor;
  int get totalMinor => principalMinor + earningsMinor;
}

final class CompoundProjection {
  static const rateScale = 1000000000;

  static List<ProjectionPoint> calculate({
    required int initialMinor,
    required int monthlyContributionMinor,
    required int rateScaled,
    required RatePeriodicity periodicity,
    required int months,
  }) {
    if (initialMinor < 0 || monthlyContributionMinor < 0 || months < 0) {
      throw ArgumentError('Valores e prazo não podem ser negativos.');
    }
    final monthlyRate = periodicity == RatePeriodicity.monthly
        ? rateScaled
        : annualToMonthlyEquivalent(rateScaled);
    if (monthlyRate <= -rateScale) {
      throw ArgumentError('A taxa mensal deve ser maior que -100%.');
    }
    var balance = initialMinor;
    var principal = initialMinor;
    final points = <ProjectionPoint>[
      ProjectionPoint(
        monthIndex: 0,
        principalMinor: principal,
        earningsMinor: 0,
      ),
    ];
    for (var month = 1; month <= months; month++) {
      balance = _roundHalfAway(
        BigInt.from(balance) * BigInt.from(rateScale + monthlyRate),
        BigInt.from(rateScale),
      );
      balance += monthlyContributionMinor;
      principal += monthlyContributionMinor;
      points.add(
        ProjectionPoint(
          monthIndex: month,
          principalMinor: principal,
          earningsMinor: balance - principal,
        ),
      );
    }
    return List.unmodifiable(points);
  }

  static int annualToMonthlyEquivalent(int annualRateScaled) {
    if (annualRateScaled == 0) return 0;
    if (annualRateScaled <= -rateScale) {
      throw ArgumentError('A taxa anual deve ser maior que -100%.');
    }
    final scale = BigInt.from(rateScale);
    final targetNumerator = BigInt.from(rateScale + annualRateScaled);
    var low = annualRateScaled < 0 ? -rateScale + 1 : 0;
    var high = annualRateScaled < 0 ? 0 : annualRateScaled;
    while (low <= high) {
      final middle = (low + high) ~/ 2;
      final factor = BigInt.from(rateScale + middle);
      final left = factor.pow(12);
      final right = targetNumerator * scale.pow(11);
      final comparison = left.compareTo(right);
      if (comparison == 0) return middle;
      if (comparison < 0) {
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }
    final lowError = _absolute(
      BigInt.from(rateScale + low).pow(12) - targetNumerator * scale.pow(11),
    );
    final highError = _absolute(
      BigInt.from(rateScale + high).pow(12) - targetNumerator * scale.pow(11),
    );
    return lowError < highError ? low : high;
  }

  static int _roundHalfAway(BigInt numerator, BigInt denominator) {
    final negative = numerator.isNegative;
    final absolute = numerator.abs();
    final rounded = (absolute + denominator ~/ BigInt.two) ~/ denominator;
    return (negative ? -rounded : rounded).toInt();
  }

  static BigInt _absolute(BigInt value) => value.isNegative ? -value : value;
}
