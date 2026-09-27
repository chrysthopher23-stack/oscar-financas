import 'package:flutter/foundation.dart';

import '../../../core/time/year_month.dart';
import '../../screen_1_financial/domain/financial_repository.dart';
import '../../screen_1_financial/domain/financial_transaction.dart';
import '../domain/financial_objective.dart';
import '../domain/objective_repository.dart';

final class ObjectivesViewModel extends ChangeNotifier {
  ObjectivesViewModel(this._repository, this._financialRepository);

  final ObjectiveRepository _repository;
  final FinancialRepository _financialRepository;
  List<FinancialObjective> _objectives = const [];
  bool _loading = true;
  String? _error;

  List<FinancialObjective> get objectives => _objectives;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final objectives = await _repository.loadAll();
      _objectives = List.unmodifiable(objectives);
    } catch (_) {
      _error = 'objectives.loadFailed';
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> create(FinancialObjective objective) async {
    await _repository.save(objective);
    if (!objective.importedFromExpenseHistory &&
        objective.monthlyContributionMinor > 0) {
      await _financialRepository.saveTransaction(
        FinancialTransaction(
          id: _contributionId(objective, objective.startMonth),
          title: _expenseTitle(objective.name),
          kind: TransactionKind.expense,
          originalAmountMinor: objective.monthlyContributionMinor,
          currency: objective.currency,
          month: objective.startMonth,
          recurring:
              objective.frequency == ObjectiveContributionFrequency.monthly,
        ),
      );
    }
    await load();
  }

  Future<void> delete(String id) async {
    await _stopRecurringContribution(id);
    await _repository.delete(id);
    _objectives = List.unmodifiable(_objectives.where((item) => item.id != id));
    notifyListeners();
  }

  Future<void> contribute(String objectiveId, int amountMinor) async {
    if (amountMinor <= 0) return;
    final objective = (await _repository.loadAll())
        .where((item) => item.id == objectiveId)
        .firstOrNull;
    if (objective == null) return;
    final month = YearMonth.now();
    final current = ObjectiveEvolution.calculate(
      objective,
      throughMonth: month,
    ).where((item) => item.month == month).firstOrNull;
    final overrides = Map<String, ObjectiveMonthOverride>.of(
      objective.monthlyOverrides,
    );
    overrides[month.databaseKey] = ObjectiveMonthOverride(
      contributionMinor: (current?.contributionMinor ?? 0) + amountMinor,
    );
    await _repository.save(
      objective.copyWith(monthlyOverrides: Map.unmodifiable(overrides)),
    );
    await _financialRepository.saveTransaction(
      FinancialTransaction(
        id: 'objective:${objective.id}:${month.databaseKey}:manual:${DateTime.now().microsecondsSinceEpoch}',
        title: _expenseTitle(objective.name),
        kind: TransactionKind.expense,
        originalAmountMinor: amountMinor,
        currency: objective.currency,
        month: month,
      ),
    );
    await load();
  }

  Future<void> updateAnnualRate(String objectiveId, int basisPoints) async {
    final objective = (await _repository.loadAll())
        .where((item) => item.id == objectiveId)
        .firstOrNull;
    if (objective == null) return;
    await _repository.save(
      objective.copyWith(annualRateBasisPoints: basisPoints.clamp(0, 10000)),
    );
    await load();
  }

  List<ObjectiveMonthSnapshot> evolution(
    FinancialObjective objective, {
    YearMonth? throughMonth,
  }) => ObjectiveEvolution.calculate(
    objective,
    throughMonth: throughMonth ?? YearMonth.now(),
  );

  Future<void> _stopRecurringContribution(String id) async {
    final objective = _objectives.where((item) => item.id == id).firstOrNull;
    if (objective == null ||
        objective.frequency != ObjectiveContributionFrequency.monthly ||
        objective.monthlyContributionMinor <= 0) {
      return;
    }
    FinancialTransaction? latest;
    var month = YearMonth.now();
    while (month.compareTo(objective.startMonth) >= 0) {
      final items = await _financialRepository.transactionsFor(month);
      for (final item in items) {
        if (item.active &&
            item.title == _expenseTitle(objective.name) &&
            item.id.contains(objective.id)) {
          latest = item;
        }
      }
      if (latest != null) break;
      month = month.addMonths(-1);
    }
    if (latest != null && latest.recurring) {
      await _financialRepository.saveTransaction(
        latest.copyWith(recurring: false),
      );
    }
  }

  String _contributionId(FinancialObjective objective, YearMonth month) =>
      'objective:${objective.id}:${month.databaseKey}';

  String _expenseTitle(String name) => 'Contribution · $name';
}
