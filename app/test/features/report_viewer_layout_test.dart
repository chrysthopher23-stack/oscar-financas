import 'dart:typed_data';

import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:oscar_financas/core/money/money.dart';
import 'package:oscar_financas/core/time/year_month.dart';
import 'package:oscar_financas/features/screen_1_financial/application/financial_snapshot_port.dart';
import 'package:oscar_financas/features/screen_5_general_reports/application/report_gateways.dart';
import 'package:oscar_financas/features/screen_5_general_reports/domain/general_report_document.dart';
import 'package:oscar_financas/features/screen_5_general_reports/domain/report_period.dart';
import 'package:oscar_financas/features/screen_5_general_reports/presentation/general_reports_page.dart';
import 'package:oscar_financas/shared/widgets/localized_text.dart' as localized;

void main() {
  testWidgets('report actions are equal-width and labels stay on one line', (
    tester,
  ) async {
    tester.view.physicalSize = const material.Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final financial = MonthlyFinancialSnapshot(
      month: YearMonth(2026, 9),
      currency: CurrencyCode.brl,
      mainIncomeMinor: 100000,
      expenseMinor: 25000,
      installmentMinor: 0,
      netMinor: 75000,
      score: 75,
      scoreLabel: 'Saudável',
      reserveBalanceMinor: 100000,
      reserveCoverageMilliMonths: 4000,
      expenses: [
        ReportExpenseItem(
          title: List.filled(5000, 'descrição extensa').join(' '),
          amountMinor: 50000,
        ),
      ],
    );
    final document = GeneralReportDocument(
      period: ReportPeriod.currentMonth,
      pages: [MonthlyReportPage(financial: financial, extraIncomeMinor: 0)],
      localeTag: 'pt-BR',
      currency: CurrencyCode.brl,
      generatedAt: DateTime(2026, 9, 23),
    );

    await tester.pumpWidget(
      material.MaterialApp(
        locale: const material.Locale('pt', 'BR'),
        home: ReportViewer(
          document: document,
          bytes: Uint8List(0),
          printGateway: _PrintGateway(),
          shareGateway: _ShareGateway(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final printLabel = find.byWidgetPredicate(
      (widget) => widget is localized.Text && widget.data == 'Imprimir',
    );
    final shareLabel = find.byWidgetPredicate(
      (widget) => widget is localized.Text && widget.data == 'Compartilhar',
    );
    expect(tester.widget<localized.Text>(printLabel).maxLines, 1);
    expect(tester.widget<localized.Text>(printLabel).softWrap, isFalse);
    expect(tester.widget<localized.Text>(shareLabel).maxLines, 1);
    expect(tester.widget<localized.Text>(shareLabel).softWrap, isFalse);

    final printButton = find.ancestor(
      of: printLabel,
      matching: find.byType(material.OutlinedButton),
    );
    final shareButton = find.ancestor(
      of: shareLabel,
      matching: find.byType(material.FilledButton),
    );
    expect(
      tester.getSize(printButton).width,
      tester.getSize(shareButton).width,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('print action handles gateway errors without crashing', (
    tester,
  ) async {
    tester.view.physicalSize = const material.Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const financial = MonthlyFinancialSnapshot(
      month: YearMonth(2026, 9),
      currency: CurrencyCode.brl,
      mainIncomeMinor: 100000,
      expenseMinor: 25000,
      installmentMinor: 0,
      netMinor: 75000,
      score: 75,
      scoreLabel: 'Saudável',
      reserveBalanceMinor: 100000,
      reserveCoverageMilliMonths: 4000,
      expenses: [],
    );
    final document = GeneralReportDocument(
      period: ReportPeriod.currentMonth,
      pages: [MonthlyReportPage(financial: financial, extraIncomeMinor: 0)],
      localeTag: 'pt-BR',
      currency: CurrencyCode.brl,
      generatedAt: DateTime(2026, 9, 23),
    );
    final printGateway = _FailingPrintGateway();
    await tester.pumpWidget(
      material.MaterialApp(
        locale: const material.Locale('pt', 'BR'),
        home: ReportViewer(
          document: document,
          bytes: Uint8List(0),
          printGateway: printGateway,
          shareGateway: _ShareGateway(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final printLabel = find.byWidgetPredicate(
      (widget) => widget is localized.Text && widget.data == 'Imprimir',
    );
    final printButton = find.ancestor(
      of: printLabel,
      matching: find.byType(material.OutlinedButton),
    );
    await tester.tap(printButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(printGateway.called, isTrue);
    expect(find.byType(material.SnackBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final class _PrintGateway implements PrintGateway {
  @override
  Future<void> printDocument(List<int> bytes) async {}
}

final class _FailingPrintGateway implements PrintGateway {
  var called = false;

  @override
  Future<void> printDocument(List<int> bytes) async {
    called = true;
    throw StateError('Print unavailable in the test');
  }
}

final class _ShareGateway implements ShareGateway {
  @override
  Future<void> shareDocument(List<int> bytes, String fileName) async {}
}
