part of '../extra_income_page.dart';

final class _ExtraIncomeChart extends StatelessWidget {
  const _ExtraIncomeChart({
    required this.summary,
    required this.formatter,
    required this.hidden,
  });
  final ExtraIncomeSummary summary;
  final MoneyFormatter formatter;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final maxValue = math.max(
      1,
      math.max(summary.servicesMinor, summary.salesMinor),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _MiniBar(
              label: uiText(context, 'Serviços'),
              color: AppColors.chartOrange,
              value: summary.servicesMinor,
              maxValue: maxValue,
              formatter: formatter,
              hidden: hidden,
            ),
            const SizedBox(width: 20),
            _MiniBar(
              label: uiText(context, 'Vendas'),
              color: AppColors.chartBlue,
              value: summary.salesMinor,
              maxValue: maxValue,
              formatter: formatter,
              hidden: hidden,
            ),
          ],
        ),
      ),
    );
  }
}

final class _MiniBar extends StatelessWidget {
  const _MiniBar({
    required this.label,
    required this.color,
    required this.value,
    required this.maxValue,
    required this.formatter,
    required this.hidden,
  });
  final String label;
  final Color color;
  final int value;
  final int maxValue;
  final MoneyFormatter formatter;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(hidden ? '••••' : formatter.formatMinor(value)),
          const SizedBox(height: 8),
          Container(
            height: 28 + 92 * value / maxValue,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 8),
          Text(label),
        ],
      ),
    );
  }
}

final class _IncomeOriginDonut extends StatelessWidget {
  const _IncomeOriginDonut({
    required this.summary,
    required this.formatter,
    required this.hidden,
  });
  final ExtraIncomeSummary summary;
  final MoneyFormatter formatter;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            SizedBox.square(
              dimension: 148,
              child: CustomPaint(
                painter: _OriginPainter(summary.serviceBasisPoints),
                child: Center(
                  child: Text(summary.totalMinor == 0 ? 'Sem ganhos' : '100%'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.circle, color: AppColors.chartOrange),
              title: Text(
                'Serviços · ${(summary.serviceBasisPoints / 100).toStringAsFixed(1)}%',
              ),
              trailing: Text(
                hidden ? '••••' : formatter.formatMinor(summary.servicesMinor),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.circle, color: AppColors.chartBlue),
              title: Text(
                'Vendas · ${(summary.saleBasisPoints / 100).toStringAsFixed(1)}%',
              ),
              trailing: Text(
                hidden ? '••••' : formatter.formatMinor(summary.salesMinor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _OriginPainter extends CustomPainter {
  const _OriginPainter(this.serviceBasisPoints);
  final int serviceBasisPoints;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.shortestSide / 2 - 12,
    );
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24
      ..color = AppColors.chartBlue;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * serviceBasisPoints / 10000,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 26
        ..color = AppColors.chartOrange,
    );
  }

  @override
  bool shouldRepaint(_OriginPainter oldDelegate) =>
      oldDelegate.serviceBasisPoints != serviceBasisPoints;
}
