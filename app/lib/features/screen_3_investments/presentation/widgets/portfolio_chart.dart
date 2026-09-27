import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import 'package:intl/intl.dart' as intl;
import 'package:oscar_financas/shared/widgets/localized_text.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/time/year_month.dart';
import '../../../../shared/formatting/money_formatter.dart';
import '../../domain/investment_portfolio_history.dart';

enum _ChartPeriod { month, three, six, year, all }

final class PortfolioChart extends StatefulWidget {
  const PortfolioChart({
    super.key,
    required this.history,
    required this.formatter,
    required this.valuesHidden,
  });

  final List<PortfolioHistoryPoint> history;
  final MoneyFormatter formatter;
  final bool valuesHidden;

  @override
  State<PortfolioChart> createState() => _PortfolioChartState();
}

final class _PortfolioChartState extends State<PortfolioChart> {
  _ChartPeriod _period = _ChartPeriod.three;
  YearMonth? _selected;
  bool _detailsOpen = false;

  List<PortfolioHistoryPoint> get _visible {
    final count = switch (_period) {
      _ChartPeriod.month => 2,
      _ChartPeriod.three => 3,
      _ChartPeriod.six => 6,
      _ChartPeriod.year => 12,
      _ChartPeriod.all => widget.history.length,
    };
    return widget.history.length <= count
        ? widget.history
        : widget.history.sublist(widget.history.length - count);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final all = widget.history;
    final last = all.isEmpty ? null : all.last;
    // Keep intl's locale identifier format (de_DE), not BCP-47 (de-DE), so
    // month names and numeric formatting resolve to the active language.
    final locale = Localizations.localeOf(context).toString();
    final theme = Theme.of(context);
    final positive = theme.brightness == Brightness.dark
        ? AppColors.emerald
        : const Color(0xFF087346);
    final line = theme.brightness == Brightness.dark
        ? const Color(0xFF40CC93)
        : const Color(0xFF176147);
    final startMonth = visible.isEmpty
        ? null
        : _period == _ChartPeriod.month
        ? visible.last.month
        : visible.first.month;
    final before = startMonth == null
        ? null
        : all
              .where((point) => point.month.compareTo(startMonth) < 0)
              .lastOrNull;
    final returnMinor = (last?.returnMinor ?? 0) - (before?.returnMinor ?? 0);
    final percent = last == null || last.principalMinor == 0
        ? '—'
        : _percent(locale, returnMinor / last.principalMinor);
    final range = startMonth == null || last == null
        ? ''
        : '${_monthYear(locale, startMonth)} – ${_monthYear(locale, last.month)}';
    final selectedPoint = _selected == null
        ? null
        : visible.where((point) => point.month == _selected).firstOrNull;

    Widget option(_ChartPeriod period) {
      final label = switch (period) {
        _ChartPeriod.month => '1 mês',
        _ChartPeriod.three => '3 meses',
        _ChartPeriod.six => '6 meses',
        _ChartPeriod.year => '1 ano',
        _ChartPeriod.all => 'Todo período',
      };
      final chosen = period == _period;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: ChoiceChip(
            label: SizedBox(
              width: double.infinity,
              child: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
            ),
            labelPadding: EdgeInsets.zero,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            selected: chosen,
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            selectedColor: theme.brightness == Brightness.dark
                ? AppColors.graphite
                : const Color(0xFF143E31),
            labelStyle: TextStyle(
              color: chosen ? Colors.white : theme.colorScheme.onSurface,
              fontWeight: chosen ? FontWeight.w600 : FontWeight.w400,
            ),
            onSelected: (_) => setState(() {
              _period = period;
              _selected = null;
            }),
          ),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.show_chart, size: 25, color: AppColors.gold),
                const SizedBox(width: 8),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Evolução patrimonial',
                      maxLines: 1,
                      softWrap: false,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                option(_ChartPeriod.month),
                option(_ChartPeriod.three),
                option(_ChartPeriod.six),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [option(_ChartPeriod.year), option(_ChartPeriod.all)],
            ),
            const SizedBox(height: 16),
            const Text('Patrimônio registrado'),
            const SizedBox(height: 2),
            _FittingAmount(
              value: widget.valuesHidden
                  ? '••••'
                  : widget.formatter.formatMinor(last?.valueMinor ?? 0),
              style: theme.textTheme.headlineMedium?.copyWith(fontSize: 32),
            ),
            const SizedBox(height: 14),
            const Text('Valorização acumulada'),
            const SizedBox(height: 2),
            _FittingAmount(
              value: widget.valuesHidden
                  ? '••••'
                  : '${returnMinor > 0 ? '+' : ''}${widget.formatter.formatMinor(returnMinor)} · $percent',
              style: theme.textTheme.titleLarge?.copyWith(
                color: returnMinor >= 0 ? positive : AppColors.ruby,
                fontSize: 23,
              ),
            ),
            if (range.isNotEmpty)
              Text(range, translate: false, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Text(
              'Somente rendimentos registrados; não inclui variação de mercado.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (visible.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Text('Nenhum investimento registrado neste período.'),
              )
            else if (widget.valuesHidden)
              const SizedBox(
                height: 174,
                width: double.infinity,
                child: Center(child: Text('••••', translate: false)),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (tap) {
                    final width = math.max(1.0, constraints.maxWidth - 64);
                    final ratio = ((tap.localPosition.dx - 48) / width).clamp(
                      0.0,
                      1.0,
                    );
                    final index = (ratio * (visible.length - 1)).round();
                    setState(() => _selected = visible[index].month);
                  },
                  child: SizedBox(
                    height: 174,
                    width: double.infinity,
                    child: CustomPaint(
                      key: const Key('portfolio-trend-plot'),
                      painter: _PortfolioLinePainter(
                        points: visible,
                        formatter: widget.formatter,
                        locale: locale,
                        lineColor: line,
                        gridColor: theme.colorScheme.outline.withValues(
                          alpha: .24,
                        ),
                        labelColor: theme.colorScheme.onSurfaceVariant,
                        cardColor: theme.cardColor,
                        selectedMonth: _selected,
                        direction: Directionality.of(context),
                      ),
                    ),
                  ),
                ),
              ),
            if (!widget.valuesHidden && selectedPoint != null) ...[
              const SizedBox(height: 4),
              Text(
                '${_monthYear(locale, selectedPoint.month)} · ${widget.formatter.formatMinor(selectedPoint.valueMinor)}',
                translate: false,
                style: theme.textTheme.titleSmall,
              ),
            ],
            const SizedBox(height: 10),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ver valores mês a mês'),
              trailing: Icon(
                _detailsOpen
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
              ),
              onTap: widget.valuesHidden
                  ? null
                  : () => setState(() => _detailsOpen = !_detailsOpen),
            ),
            if (_detailsOpen && !widget.valuesHidden)
              SizedBox(
                height: math.min(240.0, visible.length * 48.0),
                child: ListView.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final point = visible[index];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        _monthYear(locale, point.month),
                        translate: false,
                      ),
                      trailing: Text(
                        widget.formatter.formatMinor(point.valueMinor),
                        translate: false,
                      ),
                      onTap: () => setState(() => _selected = point.month),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _monthYear(String locale, YearMonth month) => intl.DateFormat(
    'MMM/y',
    locale,
  ).format(DateTime(month.year, month.month));

  static String _percent(String locale, double ratio) {
    final result = intl.NumberFormat.decimalPercentPattern(
      locale: locale,
      decimalDigits: 1,
    ).format(ratio);
    return ratio > 0 ? '+$result' : result;
  }
}

final class _FittingAmount extends StatelessWidget {
  const _FittingAmount({required this.value, required this.style});
  final String value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Text(value, translate: false, maxLines: 1, style: style),
    ),
  );
}

final class _PortfolioLinePainter extends CustomPainter {
  const _PortfolioLinePainter({
    required this.points,
    required this.formatter,
    required this.locale,
    required this.lineColor,
    required this.gridColor,
    required this.labelColor,
    required this.cardColor,
    required this.selectedMonth,
    required this.direction,
  });

  final List<PortfolioHistoryPoint> points;
  final MoneyFormatter formatter;
  final String locale;
  final Color lineColor;
  final Color gridColor;
  final Color labelColor;
  final Color cardColor;
  final YearMonth? selectedMonth;
  final TextDirection direction;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    const left = 48.0;
    final right = size.width - 16;
    const top = 12.0;
    final bottom = size.height - 30;
    final minimum = points.map((p) => p.valueMinor).reduce(math.min).toDouble();
    final maximum = points.map((p) => p.valueMinor).reduce(math.max).toDouble();
    final spread = math.max(1.0, maximum - minimum);
    final axisMin = math.max(0.0, minimum - spread * .2);
    final axisMax = maximum + spread * .2;
    final axisRange = math.max(1.0, axisMax - axisMin);
    final positions = <Offset>[];

    for (var step = 0; step < 3; step++) {
      final fraction = step / 2;
      final y = bottom - (bottom - top) * fraction;
      canvas.drawLine(
        Offset(left, y),
        Offset(right, y),
        Paint()
          ..color = gridColor
          ..strokeWidth = 1,
      );
      _label(
        canvas,
        formatter.formatCompactMinor(axisMin + axisRange * fraction),
        Offset(0, y - 7),
        45,
      );
    }
    for (var index = 0; index < points.length; index++) {
      final x = points.length == 1
          ? (left + right) / 2
          : left + (right - left) * index / (points.length - 1);
      final y =
          bottom -
          (bottom - top) * (points[index].valueMinor - axisMin) / axisRange;
      positions.add(Offset(x, y));
    }
    final path = Path()..moveTo(positions.first.dx, positions.first.dy);
    for (final point in positions.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
    final labelStep = math.max(1, (points.length / 4).ceil());
    for (var index = 0; index < positions.length; index++) {
      final point = positions[index];
      final selected =
          index == positions.length - 1 || selectedMonth == points[index].month;
      canvas.drawCircle(point, selected ? 4.5 : 3, Paint()..color = lineColor);
      if (!selected) canvas.drawCircle(point, 1.6, Paint()..color = cardColor);
      if (index == 0 ||
          index == positions.length - 1 ||
          index % labelStep == 0) {
        final label = intl.DateFormat.MMM(
          locale,
        ).format(DateTime(points[index].month.year, points[index].month.month));
        _label(canvas, label, Offset(point.dx - 17, bottom + 8), 34);
      }
    }
  }

  void _label(Canvas canvas, String value, Offset location, double width) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(color: labelColor, fontSize: 10),
      ),
      maxLines: 1,
      textDirection: direction,
    )..layout(maxWidth: width);
    painter.paint(canvas, location);
  }

  @override
  bool shouldRepaint(_PortfolioLinePainter old) =>
      old.points != points ||
      old.formatter != formatter ||
      old.locale != locale ||
      old.lineColor != lineColor ||
      old.gridColor != gridColor ||
      old.labelColor != labelColor ||
      old.cardColor != cardColor ||
      old.selectedMonth != selectedMonth ||
      old.direction != direction;
}
