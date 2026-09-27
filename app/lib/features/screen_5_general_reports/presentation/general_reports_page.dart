import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' hide Text;
import 'package:oscar_financas/shared/widgets/localized_text.dart';

import '../../../app/navigation/app_destination.dart';
import '../../../core/money/money.dart';
import '../../../core/time/year_month.dart';
import '../../../shared/formatting/money_formatter.dart';
import '../../../shared/widgets/oscar_feature_scaffold.dart';
import '../application/general_report_service.dart';
import '../application/report_gateways.dart';
import '../data/pdf_report_renderer.dart';
import '../domain/general_report_document.dart';
import '../domain/report_period.dart';

final class GeneralReportsPage extends StatefulWidget {
  const GeneralReportsPage({
    super.key,
    required this.onDestinationSelected,
    required this.service,
    required this.currency,
    required this.accessTier,
    this.renderer = const _DefaultRenderer(),
    this.printGateway = const NativePrintGateway(),
    this.shareGateway = const NativeShareGateway(),
  });

  final ValueChanged<AppDestination> onDestinationSelected;
  final GeneralReportService service;
  final CurrencyCode currency;
  final ReportAccessTier accessTier;
  final ReportRenderer renderer;
  final PrintGateway printGateway;
  final ShareGateway shareGateway;

  @override
  State<GeneralReportsPage> createState() => _GeneralReportsPageState();
}

abstract interface class ReportRenderer {
  Future<Uint8List> render(GeneralReportDocument document);
}

final class _DefaultRenderer implements ReportRenderer {
  const _DefaultRenderer();
  @override
  Future<Uint8List> render(GeneralReportDocument document) =>
      PdfReportRenderer().render(document);
}

final class _GeneralReportsPageState extends State<GeneralReportsPage> {
  var _generating = false;

  @override
  Widget build(BuildContext context) => OscarFeatureScaffold(
    destination: AppDestination.reports,
    onDestinationSelected: widget.onDestinationSelected,
    headerKind: FeatureHeaderKind.menuOnly,
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 34,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final line in [
                        'Sua vida financeira',
                        'em relatórios claros',
                      ])
                        SizedBox(
                          width: double.infinity,
                          child: FittedBox(
                            alignment: Alignment.centerLeft,
                            fit: BoxFit.scaleDown,
                            child: Text(
                              line,
                              softWrap: false,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) => GridView.count(
            crossAxisCount: constraints.maxWidth >= 600 ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.08,
            children: [
              _ReportAction(
                title: 'Relatório do mês atual',
                icon: Icons.today_outlined,
                onTap: () => _generate(ReportPeriod.currentMonth),
              ),
              _ReportAction(
                title: 'Relatório dos últimos 3 meses',
                icon: Icons.view_week_outlined,
                onTap: () => _generate(ReportPeriod.last3Months),
              ),
              _ReportAction(
                title: 'Relatório dos últimos 6 meses',
                icon: Icons.calendar_view_month_outlined,
                onTap: () => _generate(ReportPeriod.last6Months),
              ),
              _ReportAction(
                title: 'Relatório anual',
                icon: Icons.workspace_premium_outlined,
                onTap: () => _generate(ReportPeriod.annual),
              ),
            ],
          ),
        ),
        if (_generating)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    ),
  );

  Future<void> _generate(ReportPeriod period) async {
    if (!canGenerateReport(widget.accessTier, period)) {
      final required = period == ReportPeriod.last3Months ? 'Plus' : 'Pro';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            uiText(
              context,
              'Este período está disponível no Plano {plan}.',
            ).replaceAll('{plan}', required),
            translate: false,
          ),
        ),
      );
      return;
    }
    setState(() => _generating = true);
    try {
      final document = await widget.service.generate(
        period: period,
        currentMonth: YearMonth.now(),
        localeTag: Localizations.localeOf(context).toLanguageTag(),
        currency: widget.currency,
      );
      final bytes = await widget.renderer.render(document);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => ReportViewer(
            document: document,
            bytes: bytes,
            printGateway: widget.printGateway,
            shareGateway: widget.shareGateway,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível gerar o relatório. Tente novamente.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }
}

final class _ReportAction extends StatelessWidget {
  const _ReportAction({
    required this.title,
    required this.icon,
    required this.onTap,
  });
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
      ),
    ),
  );
}

final class ReportViewer extends StatelessWidget {
  const ReportViewer({
    super.key,
    required this.document,
    required this.bytes,
    required this.printGateway,
    required this.shareGateway,
  });
  final GeneralReportDocument document;
  final Uint8List bytes;
  final PrintGateway printGateway;
  final ShareGateway shareGateway;

  @override
  Widget build(BuildContext context) {
    final formatter = MoneyFormatter(
      locale: document.localeTag,
      currency: document.currency,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${uiText(context, 'report.report')} · ${document.pageCount} ${uiText(context, document.pageCount == 1 ? 'mês' : 'meses')}',
          translate: false,
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        itemCount: document.pages.length,
        itemBuilder: (context, index) => _ReportPageCard(
          page: document.pages[index],
          index: index,
          total: document.pages.length,
          formatter: formatter,
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                  onPressed: () => _print(context),
                  icon: const Icon(Icons.print_outlined, size: 18),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Imprimir', maxLines: 1, softWrap: false),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                  onPressed: () => _share(context),
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Compartilhar', maxLines: 1, softWrap: false),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _share(BuildContext context) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Antes de compartilhar'),
        content: const Text(
          'Este documento contém informações financeiras pessoais. Compartilhe somente com pessoas de confiança.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      await shareGateway.shareDocument(bytes, 'oscar_financas_relatorio.pdf');
    }
  }

  Future<void> _print(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await printGateway
          .printDocument(bytes)
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      if (!context.mounted) return;
      await _handlePrintFailure(context, messenger);
    } catch (_) {
      if (!context.mounted) return;
      await _handlePrintFailure(context, messenger);
    }
  }

  Future<void> _handlePrintFailure(
    BuildContext context,
    ScaffoldMessengerState messenger,
  ) async {
    if (kIsWeb) {
      try {
        await shareGateway.shareDocument(bytes, 'oscar_financas_relatorio.pdf');
        if (!context.mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              uiText(context, 'report.printFallback'),
              translate: false,
            ),
          ),
        );
        return;
      } catch (_) {
        if (!context.mounted) return;
      }
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          uiText(context, 'report.printUnavailable'),
          translate: false,
        ),
      ),
    );
  }
}

final class _ReportPageCard extends StatelessWidget {
  const _ReportPageCard({
    required this.page,
    required this.index,
    required this.total,
    required this.formatter,
  });
  final MonthlyReportPage page;
  final int index;
  final int total;
  final MoneyFormatter formatter;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 18),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Oscar Finanças', style: Theme.of(context).textTheme.titleLarge),
          Text(
            'Competência ${page.month.databaseKey} · Página ${index + 1} de $total',
          ),
          const Divider(height: 28),
          if (!page.financial.hasMovement && page.extraIncomeMinor == 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text('Sem movimentação'),
            ),
          _row(
            'Renda principal',
            formatter.formatMinor(page.financial.mainIncomeMinor),
          ),
          _row(
            'Ganho Extra confirmado',
            formatter.formatMinor(page.extraIncomeMinor),
          ),
          _row('Despesas', formatter.formatMinor(page.financial.expenseMinor)),
          _row(
            page.netMinor >= 0 ? 'Sobra' : 'Déficit',
            formatter.formatMinor(page.netMinor.abs()),
          ),
          const SizedBox(height: 12),
          Text(
            page.financial.score == null
                ? uiText(context, 'Oscar Score: Não calculado')
                : 'Oscar Score: ${page.financial.score}/100 · ${uiText(context, page.financial.scoreLabel)}',
            translate: false,
          ),
          Text(
            page.financial.reserveCoverageMilliMonths == 0
                ? 'Reserva de Emergência: Não avaliada'
                : 'Reserva de Emergência: ${(page.financial.reserveCoverageMilliMonths / 1000).toStringAsFixed(1)} meses',
          ),
          const SizedBox(height: 12),
          const Divider(),
          Text(
            uiText(context, 'report.mainExpenses'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (page.financial.expenses.isEmpty)
            Text(uiText(context, 'report.noExpenses'))
          else
            for (final expense in page.financial.expenses)
              _ReportDetailRow(
                title: expense.title,
                amount: formatter.formatMinor(expense.amountMinor),
              ),
          const SizedBox(height: 12),
          const Divider(),
          Text(
            uiText(context, 'report.extraDetails'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (page.extraIncomeItems.isEmpty)
            Text(uiText(context, 'report.noExtraIncome'))
          else
            for (final income in page.extraIncomeItems)
              _ReportDetailRow(
                title: income.title,
                subtitle: income.description,
                amount: formatter.formatMinor(income.amountMinor),
              ),
        ],
      ),
    ),
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value),
      ],
    ),
  );
}

final class _ReportDetailRow extends StatelessWidget {
  const _ReportDetailRow({
    required this.title,
    required this.amount,
    this.subtitle = '',
  });

  final String title;
  final String amount;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: ListTile(
      dense: true,
      visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        translate: false,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: subtitle.isEmpty
          ? null
          : Text(
              subtitle,
              translate: false,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: SizedBox(
        width: 112,
        child: Text(
          amount,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.end,
        ),
      ),
    ),
  );
}
