import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const eggConsumptionColor = Color(0xFF14B8A6);
const eggSaleColor = Color(0xFFF59E0B);

class HuevoPieChart extends StatelessWidget {
  const HuevoPieChart({
    super.key,
    required this.consumption,
    required this.sale,
    required this.broken,
    this.dimension = 184,
  });

  final double consumption;
  final double sale;
  final double broken;
  final double dimension;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final values = [consumption, sale, broken];
    final normalized = values.map(_normalizeValue).toList(growable: false);
    final total = normalized.fold<double>(0, (sum, value) => sum + value);
    final semanticsLabel = total == 0
        ? 'Destino de los huevos: sin datos'
        : 'Destino de los huevos: consumo ${normalized[0].toStringAsFixed(0)}, '
              'venta ${normalized[1].toStringAsFixed(0)}, '
              'rotos ${normalized[2].toStringAsFixed(0)}';
    final labelStyle = theme.textTheme.labelSmall!.copyWith(
      color: colors.onSurface,
      fontWeight: FontWeight.w800,
    );

    return Semantics(
      key: const Key('egg-pie-semantics'),
      label: semanticsLabel,
      image: true,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: dimension,
        child: CustomPaint(
          key: const Key('egg-pie-chart'),
          painter: HuevoPieChartPainter(
            consumption: consumption,
            sale: sale,
            broken: broken,
            consumptionColor: eggConsumptionColor,
            saleColor: eggSaleColor,
            brokenColor: colors.error,
            emptyColor: colors.outlineVariant,
            labelStyle: labelStyle,
          ),
          child: total == 0
              ? Center(
                  child: Text(
                    'Sin datos',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

class HuevoPieChartPainter extends CustomPainter {
  HuevoPieChartPainter({
    required double consumption,
    required double sale,
    required double broken,
    required this.consumptionColor,
    required this.saleColor,
    required this.brokenColor,
    required this.emptyColor,
    required this.labelStyle,
    this.labelGutter = 28,
    this.strokeWidth = 24,
    this.sectionGap = 0.035,
    this.startAngle = -math.pi / 2,
  }) : values = List<double>.unmodifiable([
         _normalizeValue(consumption),
         _normalizeValue(sale),
         _normalizeValue(broken),
       ]);

  static const sliceNames = ['Consumo', 'Venta', 'Rotos'];

  final List<double> values;
  final Color consumptionColor;
  final Color saleColor;
  final Color brokenColor;
  final Color emptyColor;
  final TextStyle labelStyle;
  final double labelGutter;
  final double strokeWidth;
  final double sectionGap;
  final double startAngle;

  List<Color> get colors => [consumptionColor, saleColor, brokenColor];

  List<String?> get percentageLabels {
    final total = values.fold<double>(0, (sum, value) => sum + value);
    if (total == 0) return const [null, null, null];
    return [
      for (final value in values)
        if (value == 0) null else '${(value / total * 100).round()}%',
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final shortestSide = math.min(size.width, size.height);
    final effectiveGutter = math.min(
      math.max(labelGutter, 0.0),
      shortestSide / 4,
    );
    final availableDiameter = math.max(
      0.0,
      shortestSide - (effectiveGutter * 2),
    );
    if (availableDiameter <= 0) return;

    final effectiveStroke = math.min(
      math.max(strokeWidth, 0.0),
      availableDiameter / 2,
    );
    final radius = math.max(0.0, (availableDiameter - effectiveStroke) / 2);
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = effectiveStroke
      ..strokeCap = StrokeCap.butt;
    final total = values.fold<double>(0, (sum, value) => sum + value);

    if (total == 0) {
      canvas.drawCircle(center, radius, paint..color = emptyColor);
      return;
    }

    var angle = startAngle;
    final labels = percentageLabels;
    for (var index = 0; index < values.length; index++) {
      final value = values[index];
      if (value == 0) continue;
      final rawSweep = value / total * math.pi * 2;
      final gap = math.min(math.max(sectionGap, 0.0), rawSweep * 0.2);
      final sweep = math.max(0.0, rawSweep - gap);
      canvas.drawArc(
        rect,
        angle + gap / 2,
        sweep,
        false,
        paint..color = colors[index],
      );

      final label = labels[index];
      if (label == null) {
        angle += rawSweep;
        continue;
      }
      final labelPainter = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: size.width);
      final middleAngle = angle + rawSweep / 2;
      final labelRadius = radius + effectiveStroke / 2 + 12;
      final preferred = center + Offset.fromDirection(middleAngle, labelRadius);
      final maxX = math.max(0.0, size.width - labelPainter.width);
      final maxY = math.max(0.0, size.height - labelPainter.height);
      final offset = Offset(
        (preferred.dx - labelPainter.width / 2).clamp(0.0, maxX),
        (preferred.dy - labelPainter.height / 2).clamp(0.0, maxY),
      );
      labelPainter.paint(canvas, offset);
      angle += rawSweep;
    }
  }

  @override
  bool shouldRepaint(covariant HuevoPieChartPainter oldDelegate) {
    return !listEquals(values, oldDelegate.values) ||
        consumptionColor != oldDelegate.consumptionColor ||
        saleColor != oldDelegate.saleColor ||
        brokenColor != oldDelegate.brokenColor ||
        emptyColor != oldDelegate.emptyColor ||
        labelStyle != oldDelegate.labelStyle ||
        labelGutter != oldDelegate.labelGutter ||
        strokeWidth != oldDelegate.strokeWidth ||
        sectionGap != oldDelegate.sectionGap ||
        startAngle != oldDelegate.startAngle;
  }
}

double _normalizeValue(double value) => value.isFinite && value > 0 ? value : 0;
