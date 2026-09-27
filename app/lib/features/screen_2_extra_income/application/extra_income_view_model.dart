import 'package:flutter/foundation.dart';

import '../../../core/money/money.dart';
import '../../../shared/controllers/month_controller.dart';
import '../../screen_3_investments/domain/fx_quote_set.dart';
import '../domain/extra_income_entry.dart';
import '../domain/extra_income_repository.dart';

enum ExtraIncomeLoadStatus { loading, ready, empty, failure }

final class ExtraIncomeScreenState {
  const ExtraIncomeScreenState({
    required this.status,
    required this.entries,
    required this.summary,
    this.errorCode,
  });

  final ExtraIncomeLoadStatus status;
  final List<ExtraIncomeEntry> entries;
  final ExtraIncomeSummary summary;
  final String? errorCode;
}

final class ExtraIncomeViewModel extends ChangeNotifier {
  ExtraIncomeViewModel({
    required this._repository,
    required this.monthController,
    required this.currency,
    required this._fxRepository,
  }) {
    monthController.addListener(_onMonthChanged);
  }

  final ExtraIncomeRepository _repository;
  final MonthController monthController;
  final CurrencyCode currency;
  final FxRepository _fxRepository;
  ExtraIncomeScreenState? _state;
  int _revision = 0;

  ExtraIncomeScreenState? get state => _state;

  Future<void> load() async {
    final revision = ++_revision;
    try {
      final fx =
          await _fxRepository.latest(currency) ??
          (await const OfflineDemonstrationFxRepository().latest(currency));
      final entries = await _repository.entriesFor(
        monthController.focusedMonth,
      );
      if (revision != _revision) return;
      final active = entries
          .where((entry) => entry.active)
          .map((entry) => _convertedEntry(entry, currency, fx))
          .toList(growable: false);
      _state = ExtraIncomeScreenState(
        status: active.isEmpty
            ? ExtraIncomeLoadStatus.empty
            : ExtraIncomeLoadStatus.ready,
        entries: List.unmodifiable(active),
        summary: ExtraIncomeCalculator.summarize(active),
      );
    } catch (_) {
      if (revision != _revision) return;
      _state = const ExtraIncomeScreenState(
        status: ExtraIncomeLoadStatus.failure,
        entries: [],
        summary: ExtraIncomeSummary(
          servicesMinor: 0,
          salesMinor: 0,
          includedInFinancialMinor: 0,
        ),
        errorCode: 'extraIncome.loadFailed',
      );
    }
    notifyListeners();
  }

  Future<void> add({
    required ExtraIncomeKind kind,
    required String name,
    required String description,
    required int amountMinor,
    required bool recurring,
    required bool includeInFinancialIncome,
  }) async {
    if (name.trim().isEmpty || amountMinor <= 0) return;
    await _repository.saveEntry(
      ExtraIncomeEntry(
        id: 'extra:${DateTime.now().microsecondsSinceEpoch}',
        kind: kind,
        name: name.trim(),
        description: description.trim(),
        amountMinor: amountMinor,
        currency: currency,
        month: monthController.focusedMonth,
        recurring: recurring,
        includeInFinancialIncome: includeInFinancialIncome,
      ),
    );
    await load();
  }

  Future<void> update({
    required ExtraIncomeEntry existing,
    required String name,
    required String description,
    required int amountMinor,
    required bool recurring,
    required bool includeInFinancialIncome,
  }) async {
    if (name.trim().isEmpty || amountMinor <= 0) return;
    await _repository.saveEntry(
      ExtraIncomeEntry(
        id: existing.id,
        kind: existing.kind,
        name: name.trim(),
        description: description.trim(),
        amountMinor: amountMinor,
        currency: existing.currency,
        month: existing.month,
        recurring: recurring,
        includeInFinancialIncome: includeInFinancialIncome,
        recurrenceTemplateId: existing.recurrenceTemplateId,
        deletedAt: existing.deletedAt,
      ),
    );
    await load();
  }

  Future<void> remove(String id) async {
    await _repository.softDelete(id, DateTime.now());
    await load();
  }

  Future<void> undoRemove(String id) async {
    await _repository.restore(id);
    await load();
  }

  void _onMonthChanged() => load();

  @override
  void dispose() {
    monthController.removeListener(_onMonthChanged);
    super.dispose();
  }
}

ExtraIncomeEntry _convertedEntry(
  ExtraIncomeEntry entry,
  CurrencyCode target,
  FxQuoteSet fx,
) {
  if (entry.currency == target) return entry;
  final amount = fx.convertToBaseMinor(entry.amountMinor, entry.currency);
  if (amount == null) return entry;
  return ExtraIncomeEntry(
    id: entry.id,
    kind: entry.kind,
    name: entry.name,
    description: entry.description,
    amountMinor: amount,
    currency: target,
    month: entry.month,
    recurring: entry.recurring,
    includeInFinancialIncome: entry.includeInFinancialIncome,
    recurrenceTemplateId: entry.recurrenceTemplateId,
    deletedAt: entry.deletedAt,
  );
}
