enum BillingCycle { monthly, annual }

final class PlanPrice {
  const PlanPrice({
    required this.monthlyMinor,
    required this.annualBaseMinor,
    required this.annualFinalMinor,
    required this.annualEquivalentMonthlyMinor,
    required this.annualDiscountBasisPoints,
    required this.referralMonthlyMinor,
    required this.referralAnnualMinor,
  });
  final int monthlyMinor;
  final int annualBaseMinor;
  final int annualFinalMinor;
  final int annualEquivalentMonthlyMinor;
  final int annualDiscountBasisPoints;
  final int referralMonthlyMinor;
  final int referralAnnualMinor;
}

abstract final class UsdPlanCatalog {
  // These are pricing assumptions, not a promise of net settlement.
  // Replace with confirmed merchant rates before enabling store purchases.
  static const storeFeeBasisPoints = int.fromEnvironment(
    'PLAY_SERVICE_FEE_BPS',
    defaultValue: 1500,
  );
  static const settlementFeeBasisPoints = int.fromEnvironment(
    'SETTLEMENT_FEE_BPS',
  );
  static const withholdingBasisPoints = int.fromEnvironment(
    'WITHHOLDING_TAX_BPS',
  );
  static final plus = forDisplayedMonthly(
    1190,
    annualDiscountBasisPoints: 1500,
  );
  static final pro = forDisplayedMonthly(2390, annualDiscountBasisPoints: 2000);

  static PlanPrice forDisplayedMonthly(
    int monthlyMinor, {
    required int annualDiscountBasisPoints,
  }) {
    final annualBase = monthlyMinor * 12;
    final annual =
        (annualBase * (10000 - annualDiscountBasisPoints) + 5000) ~/ 10000;
    return PlanPrice(
      monthlyMinor: monthlyMinor,
      annualBaseMinor: annualBase,
      annualFinalMinor: annual,
      annualEquivalentMonthlyMinor: (annual + 6) ~/ 12,
      annualDiscountBasisPoints: annualDiscountBasisPoints,
      referralMonthlyMinor: monthlyMinor,
      referralAnnualMinor: (annualBase * 7000 + 5000) ~/ 10000,
    );
  }

  static PlanPrice forNetTarget(
    int netMinor, {
    required int annualDiscountBasisPoints,
  }) {
    var denominator = BigInt.one;
    var numerator = BigInt.from(netMinor);
    for (final fee in [
      storeFeeBasisPoints,
      settlementFeeBasisPoints,
      withholdingBasisPoints,
    ]) {
      if (fee < 0 || fee >= 10000) throw ArgumentError('Invalid fee');
      numerator *= BigInt.from(10000);
      denominator *= BigInt.from(10000 - fee);
    }
    final monthly = ((numerator + denominator - BigInt.one) ~/ denominator)
        .toInt();
    final annualBase = monthly * 12;
    final annual =
        (annualBase * (10000 - annualDiscountBasisPoints) + 5000) ~/ 10000;
    return PlanPrice(
      monthlyMinor: monthly,
      annualBaseMinor: annualBase,
      annualFinalMinor: annual,
      annualEquivalentMonthlyMinor: (annual + 6) ~/ 12,
      annualDiscountBasisPoints: annualDiscountBasisPoints,
      referralMonthlyMinor: monthly,
      referralAnnualMinor: (annualBase * 7000 + 5000) ~/ 10000,
    );
  }

  static int appliedDiscountBasisPoints({
    required int annualDiscountBasisPoints,
    required bool validReferral,
    BillingCycle cycle = BillingCycle.annual,
  }) => cycle == BillingCycle.monthly
      ? 0
      : validReferral && 3000 > annualDiscountBasisPoints
      ? 3000
      : annualDiscountBasisPoints;
}
