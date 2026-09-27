final class EmergencyFundResult {
  const EmergencyFundResult({
    required this.balanceMinor,
    required this.averageExpenseMinor,
    required this.sampleMonths,
    required this.targetMonths,
    required this.coverageMilliMonths,
    required this.progressBasisPoints,
  });

  final int balanceMinor;
  final int averageExpenseMinor;
  final int sampleMonths;
  final int targetMonths;
  final int coverageMilliMonths;
  final int progressBasisPoints;
}

abstract final class EmergencyFundCalculator {
  static EmergencyFundResult calculate({
    required int balanceMinor,
    required int targetMonths,
    required Iterable<int> completedMonthlyExpensesMinor,
  }) {
    final samples = completedMonthlyExpensesMinor
        .where((value) => value >= 0)
        .take(3)
        .toList();
    final average = samples.isEmpty
        ? 0
        : samples.reduce((a, b) => a + b) ~/ samples.length;
    final coverage = average == 0 ? 0 : (balanceMinor * 1000) ~/ average;
    final targetMinor = average * targetMonths;
    final progress = targetMinor == 0
        ? 0
        : ((balanceMinor * 10000) ~/ targetMinor).clamp(0, 10000);
    return EmergencyFundResult(
      balanceMinor: balanceMinor,
      averageExpenseMinor: average,
      sampleMonths: samples.length,
      targetMonths: targetMonths,
      coverageMilliMonths: coverage,
      progressBasisPoints: progress,
    );
  }
}
