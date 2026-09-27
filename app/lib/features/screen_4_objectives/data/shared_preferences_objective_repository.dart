import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/financial_objective.dart';
import '../domain/objective_repository.dart';

final class SharedPreferencesObjectiveRepository
    implements ObjectiveRepository {
  const SharedPreferencesObjectiveRepository();

  static const _storageKey = 'financial_objectives.v1';
  static const _legacyImportedKey = 'financial_objectives.legacy_import.v1';

  Future<void> clearAll() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_storageKey);
    await preferences.remove(_legacyImportedKey);
  }

  @override
  Future<List<FinancialObjective>> loadAll() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_storageKey);
    if (encoded == null || encoded.isEmpty) return const [];
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return const [];
      final result = <FinancialObjective>[];
      for (final item in decoded) {
        if (item is Map) {
          result.add(
            FinancialObjective.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
      return List.unmodifiable(result);
    } on FormatException {
      return const [];
    } on TypeError {
      return const [];
    } on ArgumentError {
      return const [];
    }
  }

  @override
  Future<void> save(FinancialObjective objective) async {
    final preferences = await SharedPreferences.getInstance();
    final goals = (await loadAll()).toList();
    final index = goals.indexWhere((item) => item.id == objective.id);
    if (index == -1) {
      goals.add(objective);
    } else {
      goals[index] = objective;
    }
    await preferences.setString(
      _storageKey,
      jsonEncode(goals.map((item) => item.toJson()).toList()),
    );
  }

  @override
  Future<void> delete(String id) async {
    final preferences = await SharedPreferences.getInstance();
    final goals = (await loadAll()).where((item) => item.id != id).toList();
    await preferences.setString(
      _storageKey,
      jsonEncode(goals.map((item) => item.toJson()).toList()),
    );
  }

  @override
  Future<bool> legacyHistoryImported() async =>
      (await SharedPreferences.getInstance()).getBool(_legacyImportedKey) ??
      false;

  @override
  Future<void> markLegacyHistoryImported() async {
    await (await SharedPreferences.getInstance()).setBool(
      _legacyImportedKey,
      true,
    );
  }
}
