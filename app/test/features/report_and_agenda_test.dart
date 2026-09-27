import 'package:flutter_test/flutter_test.dart';
import 'package:oscar_financas/core/money/money.dart';
import 'package:oscar_financas/core/time/year_month.dart';
import 'package:oscar_financas/features/screen_1_financial/screen_1_financial.dart';
import 'package:oscar_financas/features/screen_2_extra_income/screen_2_extra_income.dart';
import 'package:oscar_financas/features/screen_2_extra_income/domain/extra_income_entry.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/fx_quote_set.dart';
import 'package:oscar_financas/features/screen_5_general_reports/application/general_report_service.dart';
import 'package:oscar_financas/features/screen_5_general_reports/domain/general_report_document.dart';
import 'package:oscar_financas/features/screen_5_general_reports/domain/report_period.dart';
import 'package:oscar_financas/features/screen_6_agenda/domain/agenda_event.dart';

void main() {
  group('Relatório Geral', () {
    test('direitos mantêm as quatro opções e protegem a ação', () {
      expect(
        canGenerateReport(ReportAccessTier.basic, ReportPeriod.currentMonth),
        isTrue,
      );
      expect(
        canGenerateReport(ReportAccessTier.basic, ReportPeriod.last3Months),
        isFalse,
      );
      expect(
        canGenerateReport(ReportAccessTier.plus, ReportPeriod.last3Months),
        isTrue,
      );
      expect(
        canGenerateReport(ReportAccessTier.plus, ReportPeriod.last6Months),
        isFalse,
      );
      expect(
        canGenerateReport(ReportAccessTier.pro, ReportPeriod.annual),
        isTrue,
      );
    });

    test('últimos 3 meses atravessam dezembro/janeiro em ordem', () async {
      final service = GeneralReportService(
        financial: _FinancialPort(),
        extraIncome: _ExtraPort(),
      );
      final document = await service.generate(
        period: ReportPeriod.last3Months,
        currentMonth: const YearMonth(2026, 1),
        localeTag: 'pt-BR',
        currency: CurrencyCode.brl,
      );
      expect(document.pageCount, 3);
      expect(document.pages.map((page) => page.month.databaseKey), [
        '2025-11',
        '2025-12',
        '2026-01',
      ]);
    });

    test('anual produz 12 folhas móveis até o mês atual', () async {
      final fx = _CountingFx();
      final financial = _FinancialPort();
      final service = GeneralReportService(
        financial: financial,
        extraIncome: _ExtraPort(),
        fxRepository: fx,
      );
      final document = await service.generate(
        period: ReportPeriod.annual,
        currentMonth: const YearMonth(2026, 8),
        localeTag: 'en-US',
        currency: CurrencyCode.usd,
      );
      expect(document.pageCount, 12);
      expect(document.pages.first.month, const YearMonth(2025, 9));
      expect(document.pages.last.month, const YearMonth(2026, 8));
      expect(document.usesLetterPaper, isTrue);
      expect(fx.calls, 1);
      expect(financial.receivedFx, 12);
    });

    test(
      'preserva os ganhos extras discriminados e soma os mesmos itens',
      () async {
        const month = YearMonth(2026, 1);
        final service = GeneralReportService(
          financial: _FinancialPort(),
          extraIncome: _ExtraPort([
            ExtraIncomeEntry(
              id: 'service-1',
              kind: ExtraIncomeKind.service,
              name: 'Consultoria',
              description: 'Projeto fechado',
              amountMinor: 12500,
              currency: CurrencyCode.brl,
              month: month,
              includeInFinancialIncome: true,
            ),
          ]),
        );

        final page = (await service.generate(
          period: ReportPeriod.currentMonth,
          currentMonth: month,
          localeTag: 'pt-BR',
          currency: CurrencyCode.brl,
        )).pages.single;

        expect(page.extraIncomeMinor, 12500);
        expect(page.extraIncomeItems, hasLength(1));
        expect(page.extraIncomeItems.single.title, 'Consultoria');
        expect(page.extraIncomeItems.single.description, 'Projeto fechado');
        expect(page.extraIncomeItems.single.amountMinor, 12500);
      },
    );
  });

  group('Agenda', () {
    final origin = DateTime(2026, 1, 31, 9);
    AgendaEvent event(EventRecurrence recurrence) => AgendaEvent(
      id: 'event',
      title: 'Compromisso',
      notes: '',
      category: AgendaCategory.personal,
      start: origin,
      timezoneId: 'America/Sao_Paulo',
      recurrence: recurrence,
      reminderPreset: ReminderPreset.atTime,
      createdAt: origin,
      updatedAt: origin,
    );

    test('evento único ocorre somente na data original', () {
      expect(
        event(EventRecurrence.none).occursOn(DateTime(2026, 1, 31)),
        isTrue,
      );
      expect(
        event(EventRecurrence.none).occursOn(DateTime(2026, 2, 1)),
        isFalse,
      );
    });

    test('recorrência semanal não cria duplicidade fora do ciclo', () {
      expect(
        event(EventRecurrence.weekly).occursOn(DateTime(2026, 2, 7)),
        isTrue,
      );
      expect(
        event(EventRecurrence.weekly).occursOn(DateTime(2026, 2, 8)),
        isFalse,
      );
    });

    test('recorrência mensal não inventa dia 31 em fevereiro', () {
      expect(
        event(EventRecurrence.monthly).occursOn(DateTime(2026, 2, 28)),
        isFalse,
      );
      expect(
        event(EventRecurrence.monthly).occursOn(DateTime(2026, 3, 31)),
        isTrue,
      );
    });
  });
}

final class _FinancialPort implements MonthlyFinancialReportPort {
  int receivedFx = 0;

  @override
  Future<MonthlyFinancialSnapshot> snapshotFor(
    YearMonth month, {
    FxQuoteSet? fx,
  }) async {
    if (fx != null) receivedFx++;
    return MonthlyFinancialSnapshot(
      month: month,
      currency: CurrencyCode.brl,
      mainIncomeMinor: 0,
      expenseMinor: 0,
      installmentMinor: 0,
      netMinor: 0,
      score: null,
      scoreLabel: 'Não calculado',
      reserveBalanceMinor: 0,
      reserveCoverageMilliMonths: 0,
      expenses: const [],
    );
  }
}

final class _CountingFx implements FxRepository {
  int calls = 0;

  @override
  Future<FxQuoteSet> latest(
    CurrencyCode base, {
    bool forceRefresh = false,
  }) async {
    calls++;
    return const OfflineDemonstrationFxRepository().latest(base);
  }
}

final class _ExtraPort implements ExtraIncomeContributionPort {
  _ExtraPort([this.entries = const []]);

  final List<ExtraIncomeEntry> entries;

  @override
  Future<List<ExtraIncomeEntry>> includedEntriesFor(YearMonth month) async =>
      entries.where((entry) => entry.month == month).toList();
  @override
  Future<int> includedMinorUnitsFor(YearMonth month) async => 0;
}
