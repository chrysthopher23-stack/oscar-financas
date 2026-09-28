import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' hide Text;
import 'package:intl/intl.dart';
import 'package:oscar_financas/shared/widgets/localized_text.dart';

import '../../../app/navigation/app_destination.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/money/money.dart';
import '../../../core/time/year_month.dart';
import '../../../shared/formatting/money_formatter.dart';
import '../../../shared/widgets/demo_display_names.dart';
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
          '${uiText(context, 'report.report')} · ${AppStrings.of(context).text(document.pages.length == 1 ? 'report.documentSummary.one' : 'report.documentSummary.many', {'months': '${document.pages.length}', 'pages': '${document.pdfPageCount}'})}',
          translate: false,
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
        itemCount: document.pages.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _ReportPageCard(
          page: document.pages[index],
          index: index,
          total: document.pages.length,
          formatter: formatter,
          localeTag: document.localeTag,
          pdfPageStart: document.pdfPageStartForMonth(index),
          pdfPageCount: document.pdfPageCountForMonth(index),
          totalPdfPages: document.pdfPageCount,
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
    required this.localeTag,
    required this.pdfPageStart,
    required this.pdfPageCount,
    required this.totalPdfPages,
  });
  final MonthlyReportPage page;
  final int index;
  final int total;
  final MoneyFormatter formatter;
  final String localeTag;
  final int pdfPageStart;
  final int pdfPageCount;
  final int totalPdfPages;

  @override
  Widget build(BuildContext context) {
    final reserve = page.emergencyReserve;
    final percent = NumberFormat.percentPattern(localeTag);
    final reserveSummary = reserve == null
        ? uiText(context, 'report.notEvaluated')
        : '${formatter.formatMinor(reserve.balanceMinor)} · ${percent.format(reserve.progressBasisPoints / 10000)} ${uiText(context, 'report.ofTarget')}';
    final score = page.financial.score == null
        ? uiText(context, 'report.notCalculated')
        : '${page.financial.score}/100 · ${uiText(context, page.financial.scoreLabel)}';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.assessment_outlined, color: AppColors.gold),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Oscar Finanças',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '${uiText(context, 'report.monthLabel')} ${page.month.databaseKey} · ${uiText(context, 'report.pdfPagesLabel')} $pdfPageStart${pdfPageCount == 2 ? '–${pdfPageStart + 1}' : ''} ${uiText(context, 'report.of')} $totalPdfPages',
                        translate: false,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _summaryPanel(context, score, reserveSummary),
            const SizedBox(height: 18),
            _section(
              context,
              title: uiText(context, 'report.incomeSection'),
              color: AppColors.emerald,
              icon: Icons.south_west,
              rows: [
                _ReportRowData(
                  uiText(context, 'report.mainIncome'),
                  formatter.formatMinor(page.financial.mainIncomeMinor),
                ),
                for (final income in page.extraIncomeItems)
                  _ReportRowData(
                    income.title,
                    formatter.formatMinor(income.amountMinor),
                  ),
                if (page.extraIncomeItems.isEmpty)
                  _ReportRowData(
                    uiText(context, 'report.noExtraIncome'),
                    formatter.formatMinor(0),
                  ),
                _ReportRowData(
                  uiText(context, 'report.total'),
                  formatter.formatMinor(page.totalIncomeMinor),
                  emphasis: true,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _section(
              context,
              title: uiText(context, 'report.mainExpenses'),
              color: AppColors.ruby,
              icon: Icons.north_east,
              trailing: formatter.formatMinor(page.financial.expenseMinor),
              rows: [
                if (page.financial.expenses.isEmpty)
                  _ReportRowData(uiText(context, 'report.noExpenses'), ''),
                for (final expense in page.financial.expenses)
                  _ReportRowData(
                    expense.title,
                    formatter.formatMinor(expense.amountMinor),
                  ),
              ],
            ),
            if (page.assets.isNotEmpty) ...[
              const SizedBox(height: 14),
              _investmentSection(
                context,
                title: uiText(context, 'report.assets'),
                items: page.assets,
              ),
            ],
            if (page.cryptoassets.isNotEmpty) ...[
              const SizedBox(height: 14),
              _investmentSection(
                context,
                title: uiText(context, 'report.cryptoassets'),
                items: page.cryptoassets,
              ),
            ],
            if (page.objectives.isNotEmpty) ...[
              const SizedBox(height: 14),
              _objectivesSection(context, percent),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryPanel(BuildContext context, String score, String reserve) {
    final netColor = page.netMinor >= 0 ? AppColors.emerald : AppColors.ruby;
    final showReserve =
        page.emergencyReserve != null ||
        page.financial.reserveCoverageMilliMonths > 0 ||
        page.financial.reserveBalanceMinor > 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            uiText(context, 'report.summary'),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.gold,
              fontWeight: FontWeight.w700,
              letterSpacing: .5,
            ),
          ),
          const SizedBox(height: 8),
          _summaryRow(
            context,
            uiText(context, 'report.total'),
            formatter.formatMinor(page.totalIncomeMinor),
            AppColors.emerald,
          ),
          _summaryRow(
            context,
            uiText(context, 'report.expenses'),
            formatter.formatMinor(page.financial.expenseMinor),
            AppColors.ruby,
          ),
          _summaryRow(
            context,
            uiText(
              context,
              page.netMinor >= 0 ? 'report.balance' : 'report.deficit',
            ),
            formatter.formatMinor(page.netMinor.abs()),
            netColor,
            emphasis: true,
          ),
          const SizedBox(height: 8),
          Text(
            '${uiText(context, 'report.health')}: $score',
            translate: false,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (showReserve)
            Text(
              '${uiText(context, 'report.fund')}: $reserve${page.financial.reserveCoverageMilliMonths > 0 ? ' · ${(page.financial.reserveCoverageMilliMonths / 1000).toStringAsFixed(1)} ${uiText(context, 'report.months')}' : ''}',
              translate: false,
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    BuildContext context,
    String label,
    String value,
    Color color, {
    bool emphasis = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: emphasis ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  Widget _section(
    BuildContext context, {
    required String title,
    required Color color,
    required IconData icon,
    required List<_ReportRowData> rows,
    String? trailing,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w700),
            ),
          ),
          if (trailing != null)
            Text(
              trailing,
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: color, fontWeight: FontWeight.w700),
            ),
        ],
      ),
      const SizedBox(height: 5),
      for (final row in rows)
        _ReportDetailRow(
          title: row.title,
          amount: row.amount,
          color: color,
          emphasis: row.emphasis,
        ),
    ],
  );

  Widget _investmentSection(
    BuildContext context, {
    required String title,
    required List<ReportInvestmentItem> items,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        title,
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(color: AppColors.gold, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 5),
      for (final item in items)
        _ReportDetailRow(
          title: '${item.identity.symbol} · ${item.identity.officialName}',
          subtitle: [
            if (item.quantity != null)
              '${uiText(context, 'report.quantity')}: ${item.quantity} ${item.identity.symbol}',
            '${uiText(context, 'report.monthlyReturn')}: ${MoneyFormatter(locale: localeTag, currency: item.identity.currency).formatMinor(item.monthlyReturnMinor)}',
          ].join(' · '),
          amount: MoneyFormatter(
            locale: localeTag,
            currency: item.identity.currency,
          ).formatMinor(item.recordedValueMinor),
          color: item.monthlyReturnMinor < 0
              ? AppColors.ruby
              : AppColors.emerald,
        ),
    ],
  );

  Widget _objectivesSection(BuildContext context, NumberFormat percent) {
    final theme = Theme.of(context);
    final cardColor = theme.colorScheme.surfaceContainerHighest;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${uiText(context, 'report.objectives')} · ${page.objectives.length}',
          translate: false,
          style: theme.textTheme.titleSmall?.copyWith(
            color: AppColors.gold,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        for (final objective in page.objectives)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        demoGoalName(context, objective.name),
                        translate: false,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    Text(
                      percent.format(objective.progressBasisPoints / 10000),
                      translate: false,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _ReportObjectiveProgressBar(
                  key: ValueKey('report-objective-progress-${objective.id}'),
                  progress: objective.progressBasisPoints / 10000,
                  backgroundColor: cardColor,
                ),
                const SizedBox(height: 4),
                Text(
                  '${uiText(context, 'report.balance')}: ${formatter.formatMinor(objective.balanceMinor)}  /  ${uiText(context, 'report.target')}: ${formatter.formatMinor(objective.targetMinor)}',
                  translate: false,
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  '${uiText(context, 'report.monthlyYield')}: ${formatter.formatMinor(objective.monthlyYieldMinor)}${objective.yieldIsEstimate ? ' · ${uiText(context, 'report.estimated')}' : ''}',
                  translate: false,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: objective.monthlyYieldMinor < 0
                        ? AppColors.ruby
                        : AppColors.emerald,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ReportObjectiveProgressBar extends StatelessWidget {
  const _ReportObjectiveProgressBar({
    super.key,
    required this.progress,
    required this.backgroundColor,
  });

  final double progress;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final value = progress.isFinite ? progress.clamp(0.0, 1.0) : 0.0;
    return SizedBox(
      height: 6,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: backgroundColor),
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: constraints.maxWidth * value,
                  child: const ColoredBox(color: AppColors.gold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _ReportRowData {
  const _ReportRowData(this.title, this.amount, {this.emphasis = false});
  final String title;
  final String amount;
  final bool emphasis;
}

final class _ReportDetailRow extends StatelessWidget {
  const _ReportDetailRow({
    required this.title,
    required this.amount,
    this.subtitle = '',
    this.color,
    this.emphasis = false,
  });

  final String title;
  final String amount;
  final String subtitle;
  final Color? color;
  final bool emphasis;

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
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: color == null
            ? null
            : TextStyle(
                color: color,
                fontWeight: emphasis ? FontWeight.w700 : FontWeight.w500,
              ),
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
        width: 120,
        child: Text(
          amount,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.end,
          style: color == null
              ? null
              : TextStyle(
                  color: color,
                  fontWeight: emphasis ? FontWeight.w700 : FontWeight.w500,
                ),
        ),
      ),
    ),
  );
}
