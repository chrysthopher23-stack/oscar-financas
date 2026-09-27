import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oscar_financas/app/settings/app_preferences_controller.dart';
import 'package:oscar_financas/shared/controllers/financial_visibility_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'new privacy defaults open values and ignore legacy closed state',
    () async {
      SharedPreferences.setMockInitialValues({
        'privacy.financial_values_hidden': true,
        'privacy.hide_on_open': true,
        'privacy.hide_on_background': true,
      });
      final storage = await SharedPreferences.getInstance();

      final visibility = FinancialVisibilityController(storage);
      final preferences = AppPreferencesController(
        storage,
        const Locale('pt', 'BR'),
      );

      expect(visibility.valuesHidden, isFalse);
      expect(preferences.hideValuesOnOpen, isFalse);
      expect(preferences.hideValuesOnBackground, isFalse);
    },
  );

  test('one shared eye state persists for every financial screen', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await SharedPreferences.getInstance();
    final firstScreen = FinancialVisibilityController(storage);

    await firstScreen.toggle();

    expect(firstScreen.valuesHidden, isTrue);
    final anotherScreenUsingTheSamePreference = FinancialVisibilityController(
      storage,
    );
    expect(anotherScreenUsingTheSamePreference.valuesHidden, isTrue);

    await anotherScreenUsingTheSamePreference.toggle();
    expect(anotherScreenUsingTheSamePreference.valuesHidden, isFalse);
  });
}
