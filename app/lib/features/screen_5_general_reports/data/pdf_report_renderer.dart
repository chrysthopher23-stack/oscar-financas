import '../../../core/localization/app_locale.dart';
import '../../../core/localization/language_brain.dart';

import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/money/money.dart';
import '../../../shared/formatting/money_formatter.dart';
import '../application/report_gateways.dart';
import '../domain/general_report_document.dart';

final class PdfReportRenderer {
  Future<Uint8List> render(GeneralReportDocument document) async {
    final pdf = pw.Document();
    final copy = _ReportCopy.forLocale(document.localeTag);
    await initializeDateFormatting(document.localeTag);
    final regularData = await rootBundle.load('assets/fonts/Nirmala.ttf');
    final boldData = await rootBundle.load('assets/fonts/NirmalaB.ttf');
    final regular = pw.Font.ttf(regularData);
    final bold = pw.Font.ttf(boldData);
    final format = document.usesLetterPaper
        ? PdfPageFormat.letter
        : PdfPageFormat.a4;
    final formatter = MoneyFormatter(
      locale: document.localeTag,
      currency: document.currency,
    );
    final dateFormat = DateFormat.yMd(document.localeTag);
    final monthFormat = DateFormat.yMMMM(document.localeTag);

    var pdfPage = 0;
    for (final page in document.pages) {
      final monthDate = DateTime(page.month.year, page.month.month);
      final hasContinuation =
          page.assets.isNotEmpty ||
          page.cryptoassets.isNotEmpty ||
          page.objectives.isNotEmpty;
      pdfPage++;
      pdf.addPage(
        _page(
          format: format,
          regular: regular,
          bold: bold,
          children: _firstPage(
            page,
            copy,
            formatter,
            monthFormat.format(monthDate),
            dateFormat.format(document.generatedAt),
            document.currency,
            pdfPage,
            document.pdfPageCount,
          ),
        ),
      );
      if (hasContinuation) {
        pdfPage++;
        pdf.addPage(
          _page(
            format: format,
            regular: regular,
            bold: bold,
            children: _continuationPage(
              page,
              copy,
              formatter,
              monthFormat.format(monthDate),
              dateFormat.format(document.generatedAt),
              document.currency,
              pdfPage,
              document.pdfPageCount,
            ),
          ),
        );
      }
    }
    return pdf.save();
  }

  pw.Page _page({
    required PdfPageFormat format,
    required pw.Font regular,
    required pw.Font bold,
    required List<pw.Widget> children,
  }) => pw.Page(
    pageFormat: format,
    margin: const pw.EdgeInsets.all(34),
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
    build: (_) => pw.SizedBox.expand(
      child: pw.FittedBox(
        fit: pw.BoxFit.scaleDown,
        alignment: pw.Alignment.topLeft,
        child: pw.SizedBox(
          width: format.width - 68,
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    ),
  );

  List<pw.Widget> _pageHeader(
    _ReportCopy copy,
    String month,
    String generated,
    CurrencyCode currency,
    int pageNumber,
    int totalPages,
  ) => [
    pw.Container(height: 5, color: PdfColor.fromHex('#D4AF37')),
    pw.SizedBox(height: 10),
    pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Oscar Finanças',
              style: pw.TextStyle(
                fontSize: 19,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#8A6B11'),
              ),
            ),
            pw.Text(
              '${copy.financialReport} · $month',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              '${copy.personalDocument} · ${copy.baseCurrency} ${currency.isoCode} · ${copy.generatedOn} $generated',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
        ),
        pw.Text(
          '${copy.page} $pageNumber ${copy.values['of']} $totalPages',
          style: const pw.TextStyle(fontSize: 8),
        ),
      ],
    ),
    pw.SizedBox(height: 9),
    pw.Divider(color: PdfColor.fromHex('#D4AF37')),
    pw.SizedBox(height: 5),
  ];

  List<pw.Widget> _firstPage(
    MonthlyReportPage page,
    _ReportCopy copy,
    MoneyFormatter formatter,
    String month,
    String generated,
    CurrencyCode currency,
    int pageNumber,
    int totalPages,
  ) {
    final reserve = page.emergencyReserve;
    final percent = NumberFormat.percentPattern(copy.localeTag);
    return [
      ..._pageHeader(copy, month, generated, currency, pageNumber, totalPages),
      _heading(copy.summary),
      pw.SizedBox(height: 4),
      pw.Row(
        children: [
          pw.Expanded(
            child: _summaryTile(
              copy.totalIncome,
              formatter.formatMinor(page.totalIncomeMinor),
              '#00A86B',
            ),
          ),
          pw.SizedBox(width: 6),
          pw.Expanded(
            child: _summaryTile(
              copy.expenses,
              formatter.formatMinor(page.financial.expenseMinor),
              '#C91D2E',
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 6),
      pw.Row(
        children: [
          pw.Expanded(
            child: _summaryTile(
              page.netMinor >= 0 ? copy.availableBalance : copy.deficit,
              formatter.formatMinor(page.netMinor.abs()),
              page.netMinor >= 0 ? '#00A86B' : '#C91D2E',
            ),
          ),
          pw.SizedBox(width: 6),
          pw.Expanded(
            child: _summaryTile(
              'Oscar Score',
              page.financial.score == null
                  ? copy.notCalculated
                  : '${page.financial.score}/100 · ${copy.scoreLabel(page.financial.scoreLabel)}',
              '#8A6B11',
            ),
          ),
        ],
      ),
      if (reserve != null) ...[
        pw.SizedBox(height: 6),
        _line(
          copy.emergencyFund,
          '${formatter.formatMinor(reserve.balanceMinor)} / ${formatter.formatMinor(reserve.targetMinor)} · ${percent.format(reserve.progressBasisPoints / 10000)} ${copy.ofTarget}',
          size: 8,
        ),
      ] else if (page.financial.reserveBalanceMinor > 0 ||
          page.financial.reserveCoverageMilliMonths > 0) ...[
        pw.SizedBox(height: 6),
        _line(
          copy.emergencyFund,
          '${formatter.formatMinor(page.financial.reserveBalanceMinor)} · ${page.financial.reserveCoverageMilliMonths == 0 ? copy.notEvaluated : '${(page.financial.reserveCoverageMilliMonths / 1000).toStringAsFixed(1)} ${copy.months}'}',
          size: 8,
        ),
      ],
      pw.SizedBox(height: 10),
      _heading(copy.incomeSection),
      pw.SizedBox(height: 3),
      _line(
        copy.mainIncome,
        formatter.formatMinor(page.financial.mainIncomeMinor),
        color: '#00A86B',
      ),
      if (page.extraIncomeItems.isEmpty)
        _line(copy.noExtraIncome, formatter.formatMinor(0), color: '#00A86B'),
      ...page.extraIncomeItems.map(
        (item) => _line(
          item.title,
          formatter.formatMinor(item.amountMinor),
          color: '#00A86B',
        ),
      ),
      _line(
        copy.confirmedExtraIncome,
        formatter.formatMinor(page.extraIncomeMinor),
        bold: true,
        color: '#00A86B',
      ),
      _line(
        copy.totalIncome,
        formatter.formatMinor(page.totalIncomeMinor),
        bold: true,
        color: '#00A86B',
      ),
      pw.SizedBox(height: 10),
      _heading('${copy.mainExpenses} · ${page.financial.expenses.length}'),
      pw.SizedBox(height: 3),
      if (page.financial.expenses.isEmpty) pw.Text(copy.noExpenses),
      ...page.financial.expenses.map(
        (item) => _line(
          item.title,
          formatter.formatMinor(item.amountMinor),
          color: '#C91D2E',
        ),
      ),
      _line(
        copy.expenses,
        formatter.formatMinor(page.financial.expenseMinor),
        bold: true,
        color: '#C91D2E',
      ),
      pw.SizedBox(height: 6),
      pw.Divider(),
      _footer(copy, currency),
    ];
  }

  List<pw.Widget> _continuationPage(
    MonthlyReportPage page,
    _ReportCopy copy,
    MoneyFormatter formatter,
    String month,
    String generated,
    CurrencyCode currency,
    int pageNumber,
    int totalPages,
  ) {
    final percent = NumberFormat.percentPattern(copy.localeTag);
    final children = <pw.Widget>[
      ..._pageHeader(copy, month, generated, currency, pageNumber, totalPages),
    ];
    if (page.assets.isNotEmpty) {
      children
        ..add(_heading('${copy.assets} · ${page.assets.length}'))
        ..add(pw.SizedBox(height: 3));
      for (final item in page.assets) {
        final native = MoneyFormatter(
          locale: copy.localeTag,
          currency: item.identity.currency,
        );
        children
          ..add(
            _line(
              '${item.identity.symbol} · ${item.identity.officialName}',
              native.formatMinor(item.recordedValueMinor),
              bold: true,
            ),
          )
          ..add(
            _subline(
              '${copy.monthlyReturn}: ${native.formatMinor(item.monthlyReturnMinor)}${item.quantity == null ? '' : ' · ${copy.quantity}: ${item.quantity} ${item.identity.symbol}'}',
            ),
          );
      }
      children.add(pw.SizedBox(height: 8));
    }
    if (page.cryptoassets.isNotEmpty) {
      children
        ..add(_heading('${copy.cryptoassets} · ${page.cryptoassets.length}'))
        ..add(pw.SizedBox(height: 3));
      for (final item in page.cryptoassets) {
        final native = MoneyFormatter(
          locale: copy.localeTag,
          currency: item.identity.currency,
        );
        children.add(
          _line(
            '${item.identity.symbol} · ${item.identity.officialName}${item.quantity == null ? '' : ' · ${copy.quantity}: ${item.quantity} ${item.identity.symbol}'}',
            native.formatMinor(item.recordedValueMinor),
          ),
        );
      }
      children.add(pw.SizedBox(height: 8));
    }
    if (page.objectives.isNotEmpty) {
      children
        ..add(_heading('${copy.objectives} · ${page.objectives.length}'))
        ..add(pw.SizedBox(height: 3));
      for (final item in page.objectives) {
        children
          ..add(
            _line(
              copy.objectiveName(item.id, item.name),
              '${percent.format(item.progressBasisPoints / 10000)} ${copy.ofTarget}',
              bold: true,
            ),
          )
          ..add(
            _subline(
              '${copy.balance}: ${formatter.formatMinor(item.balanceMinor)} · ${copy.target}: ${formatter.formatMinor(item.targetMinor)}',
            ),
          )
          ..add(
            _subline(
              '${copy.monthlyYield}: ${formatter.formatMinor(item.monthlyYieldMinor)} · ${item.yieldIsEstimate ? copy.estimated : copy.confirmed}',
            ),
          );
      }
    }
    children
      ..add(pw.SizedBox(height: 8))
      ..add(pw.Divider())
      ..add(_footer(copy, currency));
    return children;
  }

  pw.Widget _summaryTile(String label, String value, String color) =>
      pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex('#F4F3EF'),
          border: pw.Border.all(color: PdfColor.fromHex('#DDD9D0')),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 7)),
            pw.SizedBox(height: 3),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex(color),
              ),
            ),
          ],
        ),
      );

  pw.Widget _line(
    String label,
    String value, {
    bool bold = false,
    String? color,
    double size = 8,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1.6),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: size,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: size,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color == null ? null : PdfColor.fromHex(color),
          ),
        ),
      ],
    ),
  );

  pw.Widget _subline(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(left: 9, bottom: 2),
    child: pw.Text(
      text,
      style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
    ),
  );

  pw.Widget _footer(_ReportCopy copy, CurrencyCode currency) => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(
        '${copy.baseCurrency} ${currency.isoCode} · ${copy.personalDocument}',
        style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
      ),
      pw.Text(
        copy.footerNote,
        style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
      ),
    ],
  );

  pw.Widget _heading(String label) => pw.Text(
    label,
    style: pw.TextStyle(
      fontSize: 11,
      fontWeight: pw.FontWeight.bold,
      color: PdfColor.fromHex('#8A6B11'),
    ),
  );
}

final class NativePrintGateway implements PrintGateway {
  const NativePrintGateway();

  @override
  Future<void> printDocument(List<int> bytes) =>
      Printing.layoutPdf(onLayout: (_) async => Uint8List.fromList(bytes));
}

final class NativeShareGateway implements ShareGateway {
  const NativeShareGateway();

  @override
  Future<void> shareDocument(List<int> bytes, String fileName) =>
      Printing.sharePdf(bytes: Uint8List.fromList(bytes), filename: fileName);
}

final class _ReportCopy {
  const _ReportCopy(this.values, this.localeTag);

  factory _ReportCopy.forLocale(String tag) {
    final brain = LanguageBrain(SupportedAppLocale.requireTag(tag));
    return _ReportCopy({
      for (final entry in brain.messages.entries)
        if (entry.key.startsWith('report.'))
          entry.key.substring(7): entry.value,
      'demoEmergency': brain.messages['Reserva de emergência']!,
      'demoFirst100k': _first100kName(brain.locale),
    }, tag);
  }

  final Map<String, String> values;
  final String localeTag;
  String get financialReport => values['report']!;
  String get personalDocument => values['personal']!;
  String get baseCurrency => values['currency']!;
  String get generatedOn => values['generated']!;
  String get noMovement => values['noMovement']!;
  String get mainIncome => values['mainIncome']!;
  String get confirmedExtraIncome => values['extra']!;
  String get totalIncome => values['total']!;
  String get expenses => values['expenses']!;
  String get installments => values['installments']!;
  String get availableBalance => values['balance']!;
  String get deficit => values['deficit']!;
  String get notCalculated => values['notCalculated']!;
  String get emergencyFund => values['fund']!;
  String get notEvaluated => values['notEvaluated']!;
  String get months => values['months']!;
  String get mainExpenses => values['mainExpenses']!;
  String get noExpenses => values['noExpenses']!;
  String get extraDetails => values['extraDetails']!;
  String get noExtraIncome => values['noExtraIncome']!;
  String get page => values['page']!;
  String get summary => values['summary']!;
  String get incomeSection => values['incomeSection']!;
  String get assets => values['assets']!;
  String get cryptoassets => values['cryptoassets']!;
  String get objectives => values['objectives']!;
  String get ofTarget => values['ofTarget']!;
  String get balance => values['balance']!;
  String get target => values['target']!;
  String get monthlyYield => values['monthlyYield']!;
  String get estimated => values['estimated']!;
  String get confirmed => values['confirmed']!;
  String get quantity => values['quantity']!;
  String get monthlyReturn => values['monthlyReturn']!;
  String get footerNote => values['footerNote']!;

  String objectiveName(String id, String source) => switch (id) {
    'objective:demo-emergency-reserve' => values['demoEmergency']!,
    'objective:demo-first-100k' => values['demoFirst100k']!,
    _ => source,
  };

  String scoreLabel(String source) => switch (source.toLowerCase()) {
    'alerta crítico' => values['critical']!,
    'atenção / apertado' => values['attention']!,
    'equilibrado' => values['balanced']!,
    'saudável' => values['healthy']!,
    'próspero' => values['prosperous']!,
    _ => throw StateError('Unknown score label: $source'),
  };

  static String _first100kName(SupportedAppLocale locale) => switch (locale) {
    SupportedAppLocale.ptBr => 'Meus primeiros 100K',
    SupportedAppLocale.enUs => 'My First 100K',
    SupportedAppLocale.deDe => 'Meine ersten 100.000',
    SupportedAppLocale.frFr => 'Mes premiers 100 000',
    SupportedAppLocale.hiIn => 'मेरे पहले 100 हज़ार',
  };
}
