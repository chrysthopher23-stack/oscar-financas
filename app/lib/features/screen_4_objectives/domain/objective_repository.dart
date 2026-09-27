import 'financial_objective.dart';

abstract interface class ObjectiveRepository {
  Future<List<FinancialObjective>> loadAll();
  Future<void> save(FinancialObjective objective);
  Future<void> delete(String id);
  Future<bool> legacyHistoryImported();
  Future<void> markLegacyHistoryImported();
}
