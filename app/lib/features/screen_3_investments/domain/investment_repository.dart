import '../../../core/time/year_month.dart';
import 'investment_position.dart';

abstract interface class InvestmentRepository {
  Future<List<InvestmentPosition>> listForMonth(YearMonth month);
  Future<void> save(InvestmentPosition position);
  Future<void> softDelete(String id, DateTime deletedAt);
  Future<void> restore(String id);
}
