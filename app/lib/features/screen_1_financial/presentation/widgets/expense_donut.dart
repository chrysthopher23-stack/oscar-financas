import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import 'package:oscar_financas/shared/widgets/localized_text.dart';
import 'package:oscar_financas/shared/widgets/demo_display_names.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/formatting/money_formatter.dart';
import '../../domain/expense_share.dart';

final class ExpenseDonut extends StatelessWidget {
  const ExpenseDonut({
    super.key,
    required this.shares,
    required this.totalBasisPoints,
    required this.formatter,
    required this.valuesHidden,
  });

  final List<ExpenseShare> shares;
  final int totalBasisPoints;
  final MoneyFormatter formatter;
  final bool valuesHidden;

  @override
  Widget build(BuildContext context) {
    if (shares.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Cadastre despesas para visualizar a participação na renda.',
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final donut = SizedBox.square(
              dimension: 154,
              child: CustomPaint(
                painter: _ExpenseDonutPainter(shares, totalBasisPoints),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(totalBasisPoints / 100).toStringAsFixed(0)}%',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        uiText(context, 'comprometido'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            );
            final legend = Column(
              children: [
                for (var index = 0; index < shares.length; index++)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 10,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _expenseColorFor(shares[index], index),
                        border: index == 0
                            ? Border.all(color: AppColors.gold)
                            : null,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    title: Text(
                      demoFinancialTitle(
                        context,
                        shares[index].transaction.id,
                        shares[index].transaction.title,
                      ),
                      maxLines: 2,
                      translate: false,
                    ),
                    subtitle: Text(
                      '${(shares[index].basisPoints / 100).toStringAsFixed(1)}%',
                    ),
                    trailing: Text(
                      valuesHidden
                          ? '••••'
                          : formatter.formatMinor(
                              shares[index].transaction.netAmountMinor,
                            ),
                    ),
                  ),
              ],
            );
            if (constraints.maxWidth >= 520) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  donut,
                  const SizedBox(width: 24),
                  Expanded(child: legend),
                ],
              );
            }
            return Column(
              children: [donut, const SizedBox(height: 12), legend],
            );
          },
        ),
      ),
    );
  }
}

Color _expenseColorFor(ExpenseShare share, int index) {
  final title = share.transaction.title.toLowerCase();
  if (title.contains('emergency') || title.contains('reserva')) {
    return AppColors.chartYellow;
  }
  const colors = [
    AppColors.chartOrange,
    AppColors.chartBlue,
    AppColors.chartViolet,
    AppColors.emerald,
    AppColors.chartYellow,
    AppColors.matteGray,
  ];
  return colors[index % colors.length];
}

final class _ExpenseDonutPainter extends CustomPainter {
  const _ExpenseDonutPainter(this.shares, this.totalBasisPoints);
  final List<ExpenseShare> shares;
  final int totalBasisPoints;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 8;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..color = AppColors.graphite;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);
    var start = -math.pi / 2;
    final denominator = totalBasisPoints > 10000 ? totalBasisPoints : 10000;
    for (var index = 0; index < shares.length; index++) {
      final sweep = math.pi * 2 * shares[index].basisPoints / denominator;
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 22
          ..strokeCap = StrokeCap.butt
          ..color = _expenseColorFor(shares[index], index),
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_ExpenseDonutPainter oldDelegate) =>
      oldDelegate.shares != shares ||
      oldDelegate.totalBasisPoints != totalBasisPoints;
}
