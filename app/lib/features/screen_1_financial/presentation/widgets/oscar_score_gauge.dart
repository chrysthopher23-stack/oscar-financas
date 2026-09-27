import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import 'package:oscar_financas/shared/widgets/localized_text.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/financial_score.dart';

final class OscarScoreGauge extends StatelessWidget {
  const OscarScoreGauge({super.key, required this.result});

  final FinancialScoreResult result;

  @override
  Widget build(BuildContext context) {
    final label = result.calculated ? _label(result.level!) : 'Não calculado';
    final needleColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : AppColors.charcoal;
    return Semantics(
      label: result.calculated
          ? uiText(
              context,
              'Oscar Score, ${result.roundedScore} de 100, ${uiText(context, label)}',
            )
          : uiText(context, 'Oscar Score não calculado. Cadastre uma entrada.'),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
          child: Column(
            children: [
              Text(
                'Oscar Score',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              RepaintBoundary(
                child: SizedBox(
                  height: 150,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _GaugePainter(result.basisPoints, needleColor),
                  ),
                ),
              ),
              Text(
                result.calculated
                    ? '${result.roundedScore}/100 · ${uiText(context, label)}'
                    : uiText(context, label),
                translate: false,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: AppColors.charcoal),
              ),
              const SizedBox(height: 6),
              Text(
                result.calculated
                    ? _message(result.level!)
                    : 'Cadastre uma entrada para calcular seu Oscar Score.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _label(FinancialScoreLevel level) => switch (level) {
  FinancialScoreLevel.critical => 'Alerta crítico',
  FinancialScoreLevel.tight => 'Atenção',
  FinancialScoreLevel.balanced => 'Equilibrado',
  FinancialScoreLevel.healthy => 'Saudável',
  FinancialScoreLevel.prosperous => 'Próspero',
};

String _message(FinancialScoreLevel level) => switch (level) {
  FinancialScoreLevel.critical =>
    'O mês pede proteção. Reveja os maiores compromissos.',
  FinancialScoreLevel.tight =>
    'Há pouco espaço de manobra. Pequenos ajustes podem abrir fôlego.',
  FinancialScoreLevel.balanced =>
    'Sua estrutura está equilibrada. Preserve a constância.',
  FinancialScoreLevel.healthy =>
    'Boa margem financeira. Continue fortalecendo sua reserva.',
  FinancialScoreLevel.prosperous =>
    'Excelente capacidade de sobra. Direcione esse resultado com propósito.',
};

final class _GaugePainter extends CustomPainter {
  const _GaugePainter(this.basisPoints, this.needleColor);
  final int basisPoints;
  final Color needleColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 10);
    final radius = math.min(size.width / 2 - 18, size.height - 20);
    final rect = Rect.fromCircle(center: center, radius: radius);
    const colors = [
      AppColors.chartRed,
      AppColors.chartOrange,
      AppColors.chartAmber,
      AppColors.chartYellow,
      AppColors.emerald,
    ];
    const proportions = [0.10, 0.20, 0.20, 0.20, 0.30];
    var start = math.pi;
    for (var index = 0; index < colors.length; index++) {
      final sweep = math.pi * proportions[index];
      canvas.drawArc(
        rect,
        start,
        sweep - 0.012,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 26
          ..strokeCap = StrokeCap.butt
          ..color = colors[index],
      );
      _drawFace(
        canvas,
        center +
            Offset(math.cos(start + sweep / 2), math.sin(start + sweep / 2)) *
                (radius - 1),
        index,
      );
      start += sweep;
    }
    final angle = math.pi + math.pi * basisPoints.clamp(0, 10000) / 10000;
    final tip =
        center + Offset(math.cos(angle), math.sin(angle)) * (radius - 8);
    canvas.drawLine(
      center,
      tip,
      Paint()
        ..color = needleColor
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(center, 8, Paint()..color = needleColor);
  }

  void _drawFace(Canvas canvas, Offset center, int mood) {
    const faceRadius = 6.0;
    final face = Paint()..color = Colors.white.withValues(alpha: .92);
    final details = Paint()
      ..color = AppColors.charcoal
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, faceRadius, face);
    canvas.drawCircle(
      center + const Offset(-2, -1.2),
      .7,
      Paint()..color = AppColors.charcoal,
    );
    canvas.drawCircle(
      center + const Offset(2, -1.2),
      .7,
      Paint()..color = AppColors.charcoal,
    );
    final mouth = Path()..moveTo(center.dx - 2.2, center.dy + 2);
    switch (mood) {
      case 0:
        mouth.quadraticBezierTo(
          center.dx,
          center.dy - .5,
          center.dx + 2.2,
          center.dy + 2,
        );
      case 1:
        mouth.quadraticBezierTo(
          center.dx,
          center.dy + .8,
          center.dx + 2.2,
          center.dy + 1.5,
        );
      case 2:
        mouth.lineTo(center.dx + 2.2, center.dy + 2);
      default:
        mouth.quadraticBezierTo(
          center.dx,
          center.dy + 4.5,
          center.dx + 2.2,
          center.dy + 1.2,
        );
    }
    canvas.drawPath(mouth, details);
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) =>
      oldDelegate.basisPoints != basisPoints ||
      oldDelegate.needleColor != needleColor;
}
