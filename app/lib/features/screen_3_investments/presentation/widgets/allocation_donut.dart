import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import 'package:oscar_financas/shared/widgets/localized_text.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/formatting/money_formatter.dart';
import '../../domain/investment_holding.dart';

final class AllocationDonut extends StatelessWidget {
  const AllocationDonut({
    super.key,
    required this.positions,
    required this.formatter,
    required this.valuesHidden,
  });

  final List<InvestmentHolding> positions;
  final MoneyFormatter formatter;
  final bool valuesHidden;

  @override
  Widget build(BuildContext context) {
    final active = positions
        .where((item) => item.currentValueMinor > 0)
        .toList();
    final total = active.fold<int>(
      0,
      (sum, item) => sum + item.currentValueMinor,
    );
    if (total == 0) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'A alocação aparecerá quando você cadastrar uma posição.',
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final donut = SizedBox.square(
              dimension: 164,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size.square(164),
                    painter: _AllocationPainter(active, total),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        uiText(context, 'Carteira'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        valuesHidden ? '••••' : formatter.formatMinor(total),
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ],
              ),
            );
            final legend = Column(
              children: active.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final basisPoints = (item.currentValueMinor * 10000) ~/ total;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 10,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _AllocationPainter
                          .colors[index % _AllocationPainter.colors.length],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  title: Text(
                    '${item.identity.symbol} · ${uiText(context, item.identity.family.label)}',
                    translate: false,
                  ),
                  subtitle: Text('${(basisPoints / 100).toStringAsFixed(1)}%'),
                  trailing: Text(
                    valuesHidden
                        ? '••••'
                        : formatter.formatMinor(item.currentValueMinor),
                  ),
                );
              }).toList(),
            );
            if (constraints.maxWidth < 520) {
              return Column(
                children: [donut, const SizedBox(height: 12), legend],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                donut,
                const SizedBox(width: 20),
                Expanded(child: legend),
              ],
            );
          },
        ),
      ),
    );
  }
}

final class _AllocationPainter extends CustomPainter {
  const _AllocationPainter(this.positions, this.total);
  final List<InvestmentHolding> positions;
  final int total;

  static const colors = [
    AppColors.chartBlue,
    AppColors.emerald,
    AppColors.chartViolet,
    AppColors.chartOrange,
    AppColors.chartYellow,
    AppColors.matteGray,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    var start = -math.pi / 2;
    for (var index = 0; index < positions.length; index++) {
      final position = positions[index];
      final sweep = math.pi * 2 * position.currentValueMinor / total;
      final paint = Paint()
        ..color = colors[index % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 24
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect.deflate(20), start, sweep - .025, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_AllocationPainter oldDelegate) =>
      oldDelegate.positions != positions || oldDelegate.total != total;
}
