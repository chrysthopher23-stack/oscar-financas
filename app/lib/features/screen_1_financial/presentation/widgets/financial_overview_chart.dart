import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import 'package:oscar_financas/shared/widgets/localized_text.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/formatting/money_formatter.dart';
import '../../domain/monthly_summary.dart';

final class FinancialOverviewChart extends StatelessWidget {
  const FinancialOverviewChart({
    super.key,
    required this.summaries,
    required this.formatter,
    required this.valuesHidden,
  });

  final List<MonthlySummary> summaries;
  final MoneyFormatter formatter;
  final bool valuesHidden;

  @override
  Widget build(BuildContext context) {
    final hasAnyData = summaries.any(
      (summary) => summary.grossIncomeMinor > 0 || summary.expenseMinor > 0,
    );
    if (!hasAnyData) {
      return SizedBox(
        height: 96,
        child: Center(
          child: Text(
            uiText(context, 'Sem movimentações para exibir'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }
    final description = summaries
        .map((summary) {
          final result = summary.deficitMinor > 0
              ? '${uiText(context, 'Déficit')} ${formatter.formatMinor(summary.deficitMinor)}'
              : '${uiText(context, 'Sobra')} ${formatter.formatMinor(summary.netMinor)}';
          return '${summary.month.databaseKey}, $result';
        })
        .join('; ');
    return Semantics(
      label: valuesHidden
          ? uiText(context, 'Painel financeiro, valores ocultos')
          : '${uiText(context, 'Painel Financeiro')}: $description',
      child: RepaintBoundary(
        child: SizedBox(
          height: 230,
          width: double.infinity,
          child: CustomPaint(
            painter: _FinancialChartPainter(
              summaries,
              showPercentages: !valuesHidden,
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (final summary in summaries)
                    SizedBox(
                      width: 92,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            valuesHidden
                                ? '••••'
                                : formatter.formatMinor(
                                    summary.deficitMinor > 0
                                        ? summary.deficitMinor
                                        : summary.netMinor,
                                  ),
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          Text(
                            summary.month.databaseKey,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _FinancialChartPainter extends CustomPainter {
  const _FinancialChartPainter(this.summaries, {required this.showPercentages});

  final List<MonthlySummary> summaries;
  final bool showPercentages;

  @override
  void paint(Canvas canvas, Size size) {
    if (summaries.isEmpty) return;
    final plotHeight = size.height - 54;
    final maxValue = summaries.fold<int>(1, (current, item) {
      return math.max(
        current,
        math.max(item.grossIncomeMinor, item.expenseMinor),
      );
    });
    final slot = size.width / summaries.length;
    final points = <Offset>[];
    for (var index = 0; index < summaries.length; index++) {
      final summary = summaries[index];
      final focused = index == summaries.length - 1;
      final width = math.min(slot * (focused ? 0.48 : 0.38), 60.0);
      final x = slot * index + slot / 2;
      final grossHeight = plotHeight * summary.grossIncomeMinor / maxValue;
      final expenseHeight =
          plotHeight *
          math.min(summary.expenseMinor, summary.grossIncomeMinor) /
          maxValue;
      final bottom = plotHeight;
      final opacity = focused ? 1.0 : 0.58;
      if (summary.grossIncomeMinor == 0 && summary.expenseMinor == 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x - width / 2, bottom - 3, width, 3),
            const Radius.circular(3),
          ),
          Paint()..color = AppColors.graphite,
        );
        continue;
      }

      final expenseRect = Rect.fromLTWH(
        x - width / 2,
        bottom - expenseHeight,
        width,
        expenseHeight,
      );
      if (expenseHeight > 0) {
        canvas.drawRect(
          expenseRect,
          Paint()..color = AppColors.chartRed.withValues(alpha: opacity),
        );
        if (showPercentages && summary.grossIncomeMinor > 0) {
          _drawPercentage(
            canvas,
            expenseRect,
            (summary.expenseMinor * 100 / summary.grossIncomeMinor).round(),
          );
        }
      }

      if (summary.netMinor > 0) {
        final netHeight = grossHeight - expenseHeight;
        final netRect = Rect.fromLTWH(
          x - width / 2,
          bottom - grossHeight,
          width,
          netHeight,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(netRect, const Radius.circular(5)),
          Paint()..color = AppColors.emerald.withValues(alpha: opacity),
        );
        if (showPercentages) {
          _drawPercentage(
            canvas,
            netRect,
            (summary.netMinor * 100 / summary.grossIncomeMinor).round(),
          );
        }
      }

      if (summary.deficitMinor > 0) {
        final deficitHeight = plotHeight * summary.deficitMinor / maxValue;
        final deficitRect = Rect.fromLTWH(
          x - width / 2,
          bottom - grossHeight - deficitHeight,
          width,
          deficitHeight,
        );
        canvas.drawRect(
          deficitRect,
          Paint()..color = AppColors.chartRed.withValues(alpha: opacity),
        );
        if (showPercentages && summary.grossIncomeMinor > 0) {
          _drawPercentage(
            canvas,
            deficitRect,
            -(summary.deficitMinor * 100 / summary.grossIncomeMinor).round(),
          );
        }
      }
      points.add(Offset(x, bottom - math.max(grossHeight, 3)));
    }
    if (points.length > 1) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.chartYellow
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
      for (final point in points) {
        canvas.drawCircle(point, 3, Paint()..color = AppColors.chartYellow);
      }
    }
  }

  void _drawPercentage(Canvas canvas, Rect area, int percentage) {
    if (area.height < 10 || area.width < 28) return;
    final painter = TextPainter(
      text: TextSpan(
        text: '$percentage%',
        style: const TextStyle(
          color: AppColors.snow,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          shadows: [Shadow(color: Colors.black87, blurRadius: 2)],
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: area.width - 2);
    if (painter.didExceedMaxLines) return;
    painter.paint(
      canvas,
      Offset(
        area.center.dx - painter.width / 2,
        area.center.dy - painter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(_FinancialChartPainter oldDelegate) =>
      oldDelegate.summaries != summaries ||
      oldDelegate.showPercentages != showPercentages;
}
