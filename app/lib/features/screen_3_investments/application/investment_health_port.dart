import '../../../core/time/year_month.dart';

abstract interface class InvestmentHealthPort {
  Future<Object?> healthSnapshotFor(YearMonth month);
}
