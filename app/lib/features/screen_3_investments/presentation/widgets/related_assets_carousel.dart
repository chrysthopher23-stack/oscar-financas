import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Text;

import '../../../../app/theme/app_colors.dart';

import 'package:flutter/material.dart' as material show Text;

import '../../../../shared/formatting/money_formatter.dart';
import '../../../../shared/widgets/localized_text.dart';
import '../../domain/asset_market_series.dart';
import '../../domain/investment_holding.dart';

final class RelatedAssetsCarousel extends StatefulWidget {
  const RelatedAssetsCarousel({
    super.key,
    required this.title,
    required this.positions,
    required this.marketSeries,
    this.historicalMonth = false,
    this.recordedHistories = const {},
    required this.formatter,
    required this.valuesHidden,
  });

  final String title;

  final List<InvestmentHolding> positions;
  final Map<String, AssetMarketSeries> marketSeries;
  final bool historicalMonth;
  final Map<String, List<int>> recordedHistories;
  final MoneyFormatter formatter;
  final bool valuesHidden;

  @override
  State<RelatedAssetsCarousel> createState() => _RelatedAssetsCarouselState();
}

final class _RelatedAssetsCarouselState extends State<RelatedAssetsCarousel> {
  static const _loopOrigin = 10000;
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(
      viewportFraction: .62,
      initialPage: _alignedOrigin(widget.positions.length),
    );
  }

  @override
  void didUpdateWidget(covariant RelatedAssetsCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.positions.length != widget.positions.length &&
        _controller.hasClients) {
      _controller.jumpToPage(_alignedOrigin(widget.positions.length));
    }
  }

  int _alignedOrigin(int count) =>
      count < 2 ? 0 : _loopOrigin - (_loopOrigin % count);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.positions.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (widget.positions.length > 1)
              Text(
                'Deslize para ver mais',
                style: Theme.of(context).textTheme.labelSmall,
              ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 218,
          child: widget.positions.length == 1
              ? FractionallySizedBox(
                  widthFactor: .62,
                  alignment: Alignment.centerLeft,
                  child: _assetCard(widget.positions.single),
                )
              : ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: const {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.stylus,
                      PointerDeviceKind.trackpad,
                    },
                  ),
                  child: PageView.builder(
                    controller: _controller,
                    padEnds: false,
                    itemBuilder: (context, index) => _assetCard(
                      widget.positions[index % widget.positions.length],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _assetCard(InvestmentHolding position) {
    final series = widget.historicalMonth
        ? null
        : widget.marketSeries[position.identity.providerAssetId];
    final points = widget.historicalMonth
        ? widget.recordedHistories[position.identity.providerAssetId] ??
              const <int>[]
        : series?.closeValuesMinor ?? const <int>[];
    final hasMarketChange =
        series != null &&
        (series.dayChangeBasisPoints != null ||
            series.closeValuesMinor.length >= 2);
    final changeBps = hasMarketChange ? series.changeBasisPoints : null;
    final positive = widget.historicalMonth && points.length >= 2
        ? points.last >= points.first
        : (changeBps ?? 0) >= 0;
    final color = positive ? AppColors.emerald : AppColors.ruby;
    final status = widget.historicalMonth
        ? 'Patrimônio registrado'
        : series == null
        ? 'Aguardando cotação'
        : series.status == AssetMarketSeriesStatus.current
        ? 'Cotação atualizada'
        : 'Última cotação salva';
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Semantics(
          label:
              '${position.identity.symbol}, ${position.identity.officialName}',
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                material.Text(
                  position.identity.symbol,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                material.Text(
                  position.identity.officialName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  widget.valuesHidden
                      ? '••••'
                      : widget.formatter.formatMinor(
                          position.currentValueMinor,
                        ),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                if (hasMarketChange)
                  Row(
                    children: [
                      Text(
                        widget.valuesHidden
                            ? '••••'
                            : '${positive ? '+' : '−'}${(changeBps!.abs() / 100).toStringAsFixed(2).replaceAll('.', ',')}%',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(width: 6),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(
                            positive
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 4),
                Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: points.length < 2
                      ? const Center(
                          child: Text(
                            'Histórico indisponível',
                            style: TextStyle(fontSize: 11),
                          ),
                        )
                      : CustomPaint(
                          key: ValueKey(
                            'asset-chart-${position.instrumentKey}',
                          ),
                          painter: _SparklinePainter(
                            points: points,
                            color: color,
                          ),
                          size: Size.infinite,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({required this.points, required this.color});

  final List<int> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final minimum = points.reduce(math.min).toDouble();
    final maximum = points.reduce(math.max).toDouble();
    final range = math.max(1.0, maximum - minimum);
    final path = Path();
    for (var index = 0; index < points.length; index++) {
      final x = size.width * index / (points.length - 1);
      final y =
          size.height -
          ((points[index] - minimum) / range * (size.height - 6)) -
          3;
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    final lastX = size.width;
    final lastY =
        size.height - ((points.last - minimum) / range * (size.height - 6)) - 3;
    canvas.drawCircle(Offset(lastX, lastY), 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color;
}
