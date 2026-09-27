import '../../../core/localization/app_locale.dart';
import '../../../core/localization/language_brain.dart';

import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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

    for (final page in document.pages) {
      final monthDate = DateTime(page.month.year, page.month.month);
      pdf.addPage(
        pw.MultiPage(
          pageFormat: format,
          margin: const pw.EdgeInsets.all(34),
          theme: pw.ThemeData.withFont(base: regular, bold: bold),
          build: (_) => [
            pw.Text(
              'Oscar Finanças',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#8A6B11'),
              ),
            ),
            pw.Text(copy.tagline, style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 18),
            pw.Text(
              '${copy.financialReport} · ${monthFormat.format(monthDate)}',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              '${copy.personalDocument} · ${copy.baseCurrency} ${document.currency.isoCode} · ${copy.generatedOn} ${dateFormat.format(document.generatedAt)}',
            ),
            pw.Divider(),
            if (!page.financial.hasMovement && page.extraIncomeMinor == 0)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 24),
                child: pw.Text(copy.noMovement),
              ),
            _metric(
              copy.mainIncome,
              formatter.formatMinor(page.financial.mainIncomeMinor),
            ),
            _metric(
              copy.confirmedExtraIncome,
              formatter.formatMinor(page.extraIncomeMinor),
            ),
            _metric(
              copy.totalIncome,
              formatter.formatMinor(page.totalIncomeMinor),
            ),
            _metric(
              copy.expenses,
              formatter.formatMinor(page.financial.expenseMinor),
            ),
            _metric(
              copy.installments,
              formatter.formatMinor(page.financial.installmentMinor),
            ),
            _metric(
              page.netMinor >= 0 ? copy.availableBalance : copy.deficit,
              formatter.formatMinor(page.netMinor.abs()),
            ),
            pw.SizedBox(height: 12),
            _heading(copy.financialHealth),
            pw.Text(
              page.financial.score == null
                  ? 'Oscar Score: ${copy.notCalculated}'
                  : 'Oscar Score: ${page.financial.score}/100 · ${copy.scoreLabel(page.financial.scoreLabel)}',
            ),
            pw.Text(
              page.financial.reserveCoverageMilliMonths == 0
                  ? '${copy.emergencyFund}: ${copy.notEvaluated}'
                  : '${copy.emergencyFund}: ${(page.financial.reserveCoverageMilliMonths / 1000).toStringAsFixed(1)} ${copy.months}',
            ),
            pw.SizedBox(height: 12),
            _heading(copy.mainExpenses),
            if (page.financial.expenses.isEmpty) pw.Text(copy.noExpenses),
            ...page.financial.expenses.map(
              (item) => _metric(
                _compactDetail(item.title),
                formatter.formatMinor(item.amountMinor),
              ),
            ),
            pw.SizedBox(height: 12),
            _heading(copy.extraDetails),
            if (page.extraIncomeItems.isEmpty) pw.Text(copy.noExtraIncome),
            ...page.extraIncomeItems.expand(
              (item) => [
                _metric(
                  _compactDetail(item.title),
                  formatter.formatMinor(item.amountMinor),
                ),
                if (item.description.isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 3),
                    child: pw.Text(
                      _compactDetail(item.description),
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              '${copy.investmentsAndRealGrowth}: ${copy.notEvaluated}',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.Divider(),
          ],
          footer: (context) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('${copy.page} ${context.pageNumber}'),
          ),
        ),
      );
    }
    return pdf.save();
  }

  pw.Widget _heading(String label) => pw.Text(
    label,
    style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
  );

  String _compactDetail(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 160) return normalized;
    return '${normalized.substring(0, 157)}…';
  }

  pw.Widget _metric(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [pw.Text(label), pw.Text(value)],
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
  const _ReportCopy(this.values);

  factory _ReportCopy.forLocale(String tag) {
    final brain = LanguageBrain(SupportedAppLocale.requireTag(tag));
    return _ReportCopy({
      for (final entry in brain.messages.entries)
        if (entry.key.startsWith('report.'))
          entry.key.substring(7): entry.value,
    });
  }

  final Map<String, String> values;
  String get tagline => values['tagline']!;
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
  String get financialHealth => values['health']!;
  String get notCalculated => values['notCalculated']!;
  String get emergencyFund => values['fund']!;
  String get notEvaluated => values['notEvaluated']!;
  String get months => values['months']!;
  String get mainExpenses => values['mainExpenses']!;
  String get noExpenses => values['noExpenses']!;
  String get extraDetails => values['extraDetails']!;
  String get noExtraIncome => values['noExtraIncome']!;
  String get investmentsAndRealGrowth => values['investments']!;
  String get page => values['page']!;

  String scoreLabel(String source) => switch (source.toLowerCase()) {
    'alerta crítico' => values['critical']!,
    'atenção / apertado' => values['attention']!,
    'equilibrado' => values['balanced']!,
    'saudável' => values['healthy']!,
    'próspero' => values['prosperous']!,
    _ => throw StateError('Unknown score label: $source'),
  };
}
