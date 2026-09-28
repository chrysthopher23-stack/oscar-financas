import 'dart:typed_data';

import 'package:flutter/material.dart' as material;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oscar_financas/core/money/money.dart';
import 'package:oscar_financas/core/time/year_month.dart';
import 'package:oscar_financas/core/localization/app_locale.dart';
import 'package:oscar_financas/core/localization/app_strings.dart';
import 'package:oscar_financas/features/screen_1_financial/application/financial_snapshot_port.dart';
import 'package:oscar_financas/features/screen_5_general_reports/application/report_gateways.dart';
import 'package:oscar_financas/features/screen_5_general_reports/domain/general_report_document.dart';
import 'package:oscar_financas/features/screen_5_general_reports/domain/report_period.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/asset_family.dart';
import 'package:oscar_financas/features/screen_3_investments/domain/instrument_identity.dart';
import 'package:oscar_financas/features/screen_5_general_reports/presentation/general_reports_page.dart';
import 'package:oscar_financas/shared/widgets/localized_text.dart' as localized;

void main() {
  testWidgets('monthly report renders every section in all five locales', (
    tester,
  ) async {
    tester.view.physicalSize = const material.Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final financial = MonthlyFinancialSnapshot(
      month: YearMonth(2026, 9),
      currency: CurrencyCode.brl,
      mainIncomeMinor: 2200000,
      expenseMinor: 1600000,
      installmentMinor: 0,
      netMinor: 600000,
      score: 75,
      scoreLabel: 'Saudável',
      reserveBalanceMinor: 90000,
      reserveCoverageMilliMonths: 1000,
      expenses: const [ReportExpenseItem(title: 'Aluguel', amountMinor: 80000)],
    );
    final document = GeneralReportDocument(
      period: ReportPeriod.currentMonth,
      pages: [
        MonthlyReportPage(
          financial: financial,
          extraIncomeMinor: 800000,
          extraIncomeItems: const [
            ReportExtraIncomeItem(
              title: 'Serviço',
              description: 'Projeto mensal',
              amountMinor: 800000,
            ),
          ],
          investments: [
            ReportInvestmentItem(
              identity: const InstrumentIdentity(
                providerAssetId: 'asset-1',
                family: AssetFamily.etf,
                symbol: 'BND',
                officialName: 'Bond ETF',
                exchangeMic: 'XNYS',
                countryCode: 'US',
                currency: CurrencyCode.usd,
              ),
              principalMinor: 50000,
              monthlyReturnMinor: 1000,
              quantity: '2',
            ),
            ReportInvestmentItem(
              identity: const InstrumentIdentity(
                providerAssetId: 'crypto-1',
                family: AssetFamily.crypto,
                symbol: 'BTC',
                officialName: 'Bitcoin',
                exchangeMic: '',
                countryCode: 'US',
                currency: CurrencyCode.usd,
              ),
              principalMinor: 50000,
              monthlyReturnMinor: 1000,
              quantity: '0.01',
            ),
          ],
          objectives: [
            for (var index = 0; index < 4; index++)
              ReportObjectiveItem(
                id: 'objective:locale:$index',
                name: 'Objetivo $index',
                currency: CurrencyCode.brl,
                balanceMinor: 90000 + index * 1000,
                targetMinor: 300000 + index * 10000,
                contributionMinor: 10000,
                monthlyYieldMinor: 1000,
                yieldIsEstimate: true,
              ),
          ],
        ),
      ],
      localeTag: 'pt-BR',
      currency: CurrencyCode.brl,
      generatedAt: DateTime(2026, 9, 23),
    );

    for (final supportedLocale in SupportedAppLocale.values) {
      await tester.pumpWidget(
        material.MaterialApp(
          locale: supportedLocale.locale,
          supportedLocales: SupportedAppLocale.values
              .map((item) => item.locale)
              .toList(),
          localizationsDelegates: const [
            AppStrings.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: ReportViewer(
            document: GeneralReportDocument(
              period: document.period,
              pages: document.pages,
              localeTag: supportedLocale.tag,
              currency: document.currency,
              generatedAt: document.generatedAt,
            ),
            bytes: Uint8List(0),
            printGateway: _PrintGateway(),
            shareGateway: _ShareGateway(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: supportedLocale.tag);
      for (var index = 0; index < 4; index++) {
        final bar = find.byKey(
          material.ValueKey(
            'report-objective-progress-objective:locale:$index',
          ),
        );
        expect(bar, findsOneWidget, reason: supportedLocale.tag);
        expect(tester.getSize(bar).height, 6, reason: supportedLocale.tag);
        expect(
          tester.getSize(bar).width,
          greaterThan(0),
          reason: supportedLocale.tag,
        );
      }
      final strings = AppStrings(supportedLocale);
      for (final key in [
        'report.summary',
        'report.incomeSection',
        'report.assets',
        'report.cryptoassets',
        'report.objectives',
        'report.target',
        'report.monthlyYield',
      ]) {
        expect(strings.text(key), isNotEmpty, reason: supportedLocale.tag);
      }
    }
  });

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
      pages: [
        MonthlyReportPage(
          financial: financial,
          extraIncomeMinor: 0,
          objectives: [
            for (var index = 0; index < 4; index++)
              ReportObjectiveItem(
                id: 'objective:$index',
                name: 'Meta $index',
                currency: CurrencyCode.brl,
                balanceMinor: 10000 + index * 1000,
                targetMinor: 100000,
                contributionMinor: 5000,
                monthlyYieldMinor: 3000,
                yieldIsEstimate: true,
              ),
          ],
        ),
      ],
      localeTag: 'pt-BR',
      currency: CurrencyCode.brl,
      generatedAt: DateTime(2026, 9, 23),
    );

    await tester.pumpWidget(
      material.MaterialApp(
        locale: const material.Locale('pt', 'BR'),
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: ReportViewer(
          document: document,
          bytes: Uint8List(0),
          printGateway: _PrintGateway(),
          shareGateway: _ShareGateway(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollableFinder = find.descendant(
      of: find.byType(material.ListView),
      matching: find.byType(material.Scrollable),
    );
    expect(scrollableFinder, findsOneWidget);
    final position = tester
        .state<material.ScrollableState>(scrollableFinder)
        .position;
    expect(position.maxScrollExtent, greaterThan(position.minScrollExtent));
    expect(
      find.byType(material.Scrollable),
      findsOneWidget, // the report has a single vertical scroll view
    );
    for (var index = 0; index < 4; index++) {
      final progressBar = find.byKey(
        material.ValueKey('report-objective-progress-objective:$index'),
      );
      expect(progressBar, findsOneWidget);
      expect(tester.getSize(progressBar).height, 6);
      expect(tester.getSize(progressBar).width, greaterThan(0));
    }

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
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: ReportViewer(
          document: document,
          bytes: Uint8List(0),
          printGateway: printGateway,
          shareGateway: _ShareGateway(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byType(material.ListView),
      const material.Offset(0, -4000),
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
