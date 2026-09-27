import 'financial_transaction.dart';

final class ExpenseShare {
  const ExpenseShare({required this.transaction, required this.basisPoints});
  final FinancialTransaction transaction;
  final int basisPoints;
}

abstract final class ExpenseShareCalculator {
  static List<ExpenseShare> calculate({
    required Iterable<FinancialTransaction> expenses,
    required int grossIncomeMinor,
  }) {
    final active =
        expenses
            .where(
              (item) =>
                  item.active &&
                  item.kind == TransactionKind.expense &&
                  item.netAmountMinor > 0,
            )
            .toList()
          ..sort((a, b) {
            final valueOrder = b.netAmountMinor.compareTo(a.netAmountMinor);
            return valueOrder == 0 ? a.id.compareTo(b.id) : valueOrder;
          });
    return [
      for (final item in active)
        ExpenseShare(
          transaction: item,
          basisPoints: grossIncomeMinor == 0
              ? 0
              : (item.netAmountMinor * 10000) ~/ grossIncomeMinor,
        ),
    ];
  }
}
