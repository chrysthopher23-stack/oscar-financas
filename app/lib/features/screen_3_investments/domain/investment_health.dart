import '../../../core/time/year_month.dart';

final class InvestmentHealthSnapshot {
  const InvestmentHealthSnapshot({
    required this.month,
    required this.nominalReturnMinor,
    required this.inflationEffectMinor,
    required this.realGrowthMinor,
    required this.inflationReferenceMonth,
    required this.sourceStatus,
  });

  final YearMonth month;
  final int nominalReturnMinor;
  final int inflationEffectMinor;
  final int realGrowthMinor;
  final YearMonth? inflationReferenceMonth;
  final String sourceStatus;
}

InvestmentHealthSnapshot calculateInvestmentHealth({
  required YearMonth month,
  required int openingPrincipalMinor,
  required int nominalReturnMinor,
  required int monthlyInflationScaled,
  YearMonth? referenceMonth,
  String sourceStatus = 'local',
}) {
  const scale = 1000000000;
  final numerator =
      BigInt.from(openingPrincipalMinor) * BigInt.from(monthlyInflationScaled);
  final denominator = BigInt.from(scale);
  final effect =
      ((numerator.abs() + denominator ~/ BigInt.two) ~/ denominator).toInt() *
      (numerator.isNegative ? -1 : 1);
  return InvestmentHealthSnapshot(
    month: month,
    nominalReturnMinor: nominalReturnMinor,
    inflationEffectMinor: effect,
    realGrowthMinor: nominalReturnMinor - effect,
    inflationReferenceMonth: referenceMonth,
    sourceStatus: sourceStatus,
  );
}
