import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class FinancialVisibilityController extends ChangeNotifier {
  FinancialVisibilityController(this._preferences)
    : _valuesHidden = _preferences.getBool(_storageKey) ?? false;

  static const _storageKey = 'privacy.financial_values_hidden.v2';
  final SharedPreferences _preferences;
  bool _valuesHidden;

  bool get valuesHidden => _valuesHidden;

  Future<void> toggle() async {
    _valuesHidden = !_valuesHidden;
    notifyListeners();
    await _preferences.setBool(_storageKey, _valuesHidden);
  }

  Future<void> hide() async {
    if (_valuesHidden) return;
    _valuesHidden = true;
    notifyListeners();
    await _preferences.setBool(_storageKey, true);
  }
}
