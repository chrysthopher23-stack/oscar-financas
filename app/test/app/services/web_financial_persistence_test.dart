import 'package:flutter_test/flutter_test.dart';
import 'package:oscar_financas/app/services/create_app_services_web.dart';
import 'package:oscar_financas/core/money/money.dart';
import 'package:oscar_financas/core/time/year_month.dart';
import 'package:oscar_financas/features/screen_1_financial/application/monthly_financial_report_adapter.dart';
import 'package:oscar_financas/features/screen_1_financial/application/financial_view_model.dart';
import 'package:oscar_financas/features/screen_2_extra_income/domain/extra_income_entry.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/fx_quote_set.dart';
import 'package:oscar_financas/features/screen_5_general_reports/application/general_report_service.dart';
import 'package:oscar_financas/features/screen_5_general_reports/domain/report_period.dart';
import 'package:oscar_financas/shared/controllers/month_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const currentMonth = YearMonth(2026, 9);
  const firstMonth = YearMonth(2025, 10);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('all twelve demo months reconcile salary, services and sales', () async {
    final services = createAppServices();
    await services.ensureInitialDemoData(
      month: currentMonth,
      currency: CurrencyCode.usd,
    );
    const monthlyAmounts = [
      (380000, 48000, 32000),
      (385000, 29000, 51000),
      (385000, 54000, 28000),
      (390000, 35000, 41000),
      (395000, 61000, 23000),
      (395000, 42000, 57000),
      (405000, 67000, 39000),
      (405000, 31000, 69000),
      (415000, 73000, 36000),
      (415000, 39000, 72000),
      (425000, 79000, 45000),
      (435000, 45000, 82000),
    ];
    for (var index = 0; index < monthlyAmounts.length; index++) {
      final month = firstMonth.addMonths(index);
      final financialRows = await services.financialRepository.transactionsFor(
        month,
      );
      expect(
        financialRows
            .singleWhere((item) => item.id.startsWith('demo:financial:salary:'))
            .title,
        'Salary',
      );
      expect(
        financialRows
            .singleWhere((item) => item.id.startsWith('demo:financial:rent:'))
            .title,
        'Rent',
      );
      final extraRows = await services.extraIncomeRepository.entriesFor(month);
      expect(
        extraRows
            .singleWhere((item) => item.id.startsWith('demo:extra:service:'))
            .name,
        'Freelance service',
      );
      expect(
        extraRows
            .singleWhere((item) => item.id.startsWith('demo:extra:sale:'))
            .name,
        'Occasional sale',
      );
      final controller = MonthController(initialMonth: month);
      final viewModel = FinancialViewModel(
        repository: services.financialRepository,
        extraIncomePort: services.extraIncomeContributionPort,
        monthController: controller,
        currency: CurrencyCode.usd,
        fxRepository: const OfflineDemonstrationFxRepository(),
      );
      await viewModel.load();
      final (salary, service, sale) = monthlyAmounts[index];
      final poolCleaning = month.compareTo(const YearMonth(2026, 1)) >= 0
          ? 30000
          : 0;
      final state = viewModel.state!;
      expect(state.summary.incomeMinor, salary, reason: month.databaseKey);
      expect(
        state.extraServicesMinor,
        service + poolCleaning,
        reason: month.databaseKey,
      );
      expect(state.extraSalesMinor, sale, reason: month.databaseKey);
      expect(
        state.summary.grossIncomeMinor,
        salary + service + poolCleaning + sale,
        reason: month.databaseKey,
      );
      viewModel.dispose();
      controller.dispose();
    }
    final goals = await services.objectiveRepository.loadAll();
    expect(
      goals
          .singleWhere((item) => item.id == 'objective:demo-emergency-reserve')
          .name,
      'Emergency fund',
    );
  });

  test('browser recurring extra income persists once per month', () async {
    SharedPreferences.setMockInitialValues({
      'demo.seed.annual-browser.v1': true,
      'demo.seed.pool-cleaning-recurring.v1': true,
    });
    final services = createAppServices();
    await services.ensureInitialDemoData(
      month: currentMonth,
      currency: CurrencyCode.usd,
    );
    await services.extraIncomeRepository.saveEntry(
      const ExtraIncomeEntry(
        id: 'extra:recurring-service',
        kind: ExtraIncomeKind.service,
        name: 'Monthly service',
        description: '',
        amountMinor: 50000,
        currency: CurrencyCode.usd,
        month: YearMonth(2026, 1),
        recurring: true,
        includeInFinancialIncome: true,
      ),
    );
    await services.extraIncomeRepository.saveEntry(
      const ExtraIncomeEntry(
        id: 'extra:one-time-sale',
        kind: ExtraIncomeKind.sale,
        name: 'One-time sale',
        description: '',
        amountMinor: 20000,
        currency: CurrencyCode.usd,
        month: YearMonth(2026, 1),
        includeInFinancialIncome: true,
      ),
    );

    expect(
      await services.extraIncomeContributionPort.includedMinorUnitsFor(
        const YearMonth(2026, 1),
      ),
      70000,
    );
    final february = await services.extraIncomeRepository.entriesFor(
      const YearMonth(2026, 2),
    );
    expect(february.single.amountMinor, 50000);
    expect(
      await services.extraIncomeRepository.entriesFor(const YearMonth(2026, 2)),
      hasLength(1),
    );
    final reopened = createAppServices();
    await reopened.ensureInitialDemoData(
      month: const YearMonth(2026, 2),
      currency: CurrencyCode.usd,
    );
    final march = await reopened.extraIncomeRepository.entriesFor(
      const YearMonth(2026, 3),
    );
    expect(march.single.amountMinor, 50000);
    expect(march.single.includeInFinancialIncome, isTrue);
    final recurring = march.single;
    await reopened.extraIncomeRepository.saveEntry(
      ExtraIncomeEntry(
        id: recurring.id,
        kind: recurring.kind,
        name: recurring.name,
        description: recurring.description,
        amountMinor: 60000,
        currency: recurring.currency,
        month: recurring.month,
        recurring: true,
        includeInFinancialIncome: true,
        recurrenceTemplateId: recurring.recurrenceTemplateId,
      ),
    );
    final april = await reopened.extraIncomeRepository.entriesFor(
      const YearMonth(2026, 4),
    );
    expect(april.single.amountMinor, 60000);
    await reopened.extraIncomeRepository.saveEntry(
      ExtraIncomeEntry(
        id: april.single.id,
        kind: april.single.kind,
        name: april.single.name,
        description: april.single.description,
        amountMinor: april.single.amountMinor,
        currency: april.single.currency,
        month: april.single.month,
        recurring: false,
        includeInFinancialIncome: true,
        recurrenceTemplateId: april.single.recurrenceTemplateId,
      ),
    );
    expect(
      await reopened.extraIncomeRepository.entriesFor(const YearMonth(2026, 5)),
      isEmpty,
    );
  });

  test('pool cleaning repeats from January into future cash flow', () async {
    final services = createAppServices();
    await services.ensureInitialDemoData(
      month: currentMonth,
      currency: CurrencyCode.usd,
    );
    for (final month in const [
      YearMonth(2026, 1),
      YearMonth(2026, 9),
      YearMonth(2026, 10),
      YearMonth(2026, 11),
    ]) {
      final entries = await services.extraIncomeRepository.entriesFor(month);
      final pool = entries
          .where((item) => item.name == 'Pool cleaning')
          .toList();
      expect(pool, hasLength(1), reason: month.databaseKey);
      expect(pool.single.amountMinor, 30000);
      expect(pool.single.recurring, isTrue);
      expect(pool.single.includeInFinancialIncome, isTrue);
      expect(
        await services.extraIncomeContributionPort.includedMinorUnitsFor(month),
        greaterThanOrEqualTo(30000),
      );
    }
    final october = await services.extraIncomeRepository.entriesFor(
      const YearMonth(2026, 10),
    );
    expect(october.where((item) => item.name == 'Pool cleaning'), hasLength(1));
  });

  test(
    'annual browser demo persists and can be manually removed/restored',
    () async {
      final firstSession = createAppServices();
      await firstSession.ensureInitialDemoData(
        month: currentMonth,
        currency: CurrencyCode.usd,
      );

      final october = await firstSession.financialRepository.transactionsFor(
        firstMonth,
      );
      final september = await firstSession.financialRepository.transactionsFor(
        currentMonth,
      );
      expect(october, hasLength(8));
      expect(september.length, greaterThanOrEqualTo(8));
      expect(
        october.map((item) => item.id),
        isNot(equals(september.map((item) => item.id))),
      );
      expect(
        (await firstSession.extraIncomeRepository.entriesFor(firstMonth)),
        hasLength(2),
      );
      expect(
        await firstSession.investmentRepository.listForMonth(currentMonth),
        hasLength(34),
      );
      final annual =
          await GeneralReportService(
            financial: MonthlyFinancialReportAdapter(
              firstSession.financialRepository,
              CurrencyCode.usd,
            ),
            extraIncome: firstSession.extraIncomeContributionPort,
          ).generate(
            period: ReportPeriod.annual,
            currentMonth: currentMonth,
            localeTag: 'en-US',
            currency: CurrencyCode.usd,
          );
      expect(annual.pages, hasLength(12));
      expect(annual.pages.first.month, firstMonth);
      expect(annual.pages.last.month, currentMonth);
      expect(
        annual.pages.every((page) => page.financial.mainIncomeMinor > 0),
        isTrue,
      );
      expect(
        annual.pages.every((page) => page.financial.expenseMinor > 0),
        isTrue,
      );
      expect(annual.pages.every((page) => page.extraIncomeMinor > 0), isTrue);
      expect(
        annual.pages.map((page) => page.financial.expenseMinor).toSet().length,
        greaterThan(1),
      );

      final firstId = october.first.id;
      await firstSession.financialRepository.softDelete(
        firstId,
        DateTime.utc(2026, 9, 24),
      );

      final reopenedSession = createAppServices();
      await reopenedSession.ensureInitialDemoData(
        month: currentMonth,
        currency: CurrencyCode.usd,
      );
      final reopenedOctober = await reopenedSession.financialRepository
          .transactionsFor(firstMonth);
      expect(reopenedOctober, hasLength(8));
      expect(
        reopenedOctober.singleWhere((item) => item.id == firstId).active,
        isFalse,
      );

      await reopenedSession.financialRepository.restore(firstId);
      final restoredSession = createAppServices();
      await restoredSession.ensureInitialDemoData(
        month: currentMonth,
        currency: CurrencyCode.usd,
      );
      final restoredOctober = await restoredSession.financialRepository
          .transactionsFor(firstMonth);
      expect(
        restoredOctober.singleWhere((item) => item.id == firstId).active,
        isTrue,
      );
    },
  );

  test(
    'an existing locally saved record prevents automatic demo mixing',
    () async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        'oscar.web.transactions.v1',
        '[{"id":"mine","title":"Meu registro","kind":"expense","amount":500,"currency":"USD","month":"2026-09","discountType":"none","discountValue":0,"recurring":false,"installment":null,"deletedAt":null}]',
      );

      final services = createAppServices();
      await services.ensureInitialDemoData(
        month: currentMonth,
        currency: CurrencyCode.usd,
      );
      final rows = await services.financialRepository.transactionsFor(
        currentMonth,
      );
      expect(rows.any((item) => item.id == 'mine'), isTrue);
      expect(
        rows.singleWhere((item) => item.id == 'mine').title,
        'Meu registro',
      );
      expect(
        rows.any((item) => item.id.startsWith('demo:financial:')),
        isFalse,
      );
    },
  );
}
