import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oscar_financas/app/services/create_app_services_web.dart'
    as web;
import 'package:oscar_financas/core/money/money.dart';
import 'package:oscar_financas/core/time/year_month.dart';
import 'package:oscar_financas/shared/controllers/month_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'reset removes seeded records and permanently prevents reseeding',
    () async {
    SharedPreferences.setMockInitialValues({
      'account.profile.name': 'Alex',
      'regional.locale': 'en-US',
      'regional.locale_manual': true,
    });
      const current = YearMonth(2026, 9);
      final services = web.createAppServices();
      await services.ensureInitialDemoData(
        month: current,
        currency: CurrencyCode.usd,
      );
      expect(await services.earliestRecordedMonth(), isNotNull);
      expect(
        await services.financialRepository.transactionsFor(current),
        isNotEmpty,
      );
      expect(
        await services.extraIncomeRepository.entriesFor(current),
        isNotEmpty,
      );
      expect(
        await services.investmentRepository.listForMonth(current),
        isNotEmpty,
      );
      expect(await services.objectiveRepository.loadAll(), isNotEmpty);

      await services.resetPersonalHistory();
      expect(await services.earliestRecordedMonth(), isNull);
      expect(
        await services.financialRepository.transactionsFor(current),
        isEmpty,
      );
      expect(await services.extraIncomeRepository.entriesFor(current), isEmpty);
      expect(
        await services.investmentRepository.listForMonth(current),
        isEmpty,
      );
      expect(await services.objectiveRepository.loadAll(), isEmpty);
      expect(
        await services.extraIncomeRepository.entriesFor(current.addMonths(1)),
        isEmpty,
      );

      final reopened = web.createAppServices();
      await reopened.ensureInitialDemoData(
        month: current.addMonths(1),
        currency: CurrencyCode.usd,
      );
      expect(await reopened.earliestRecordedMonth(), isNull);
      expect(
        await reopened.financialRepository.transactionsFor(current),
        isEmpty,
      );
      expect(
        await reopened.extraIncomeRepository.entriesFor(current.addMonths(1)),
        isEmpty,
      );
      expect(
        await reopened.investmentRepository.listForMonth(current),
        isEmpty,
      );
      expect(await reopened.objectiveRepository.loadAll(), isEmpty);
    expect(
      (await SharedPreferences.getInstance()).getBool(
        'history.personal-start.v1',
      ),
      isTrue,
    );
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('account.profile.name'), 'Alex');
    expect(preferences.getString('regional.locale'), 'en-US');
    expect(preferences.getBool('regional.locale_manual'), isTrue);
    },
  );

  test('month navigation stops at the first permitted month', () {
    const first = YearMonth(2026, 9);
    final controller = MonthController(
      initialMonth: first,
      minimumMonth: first,
    );
    expect(controller.canGoPrevious, isFalse);
    controller.changeMonth(-1);
    expect(controller.focusedMonth, first);
    controller.changeMonth(1);
    expect(controller.canGoPrevious, isTrue);
    controller.changeMonth(-1);
    expect(controller.focusedMonth, first);
    controller.dispose();
  });
}
