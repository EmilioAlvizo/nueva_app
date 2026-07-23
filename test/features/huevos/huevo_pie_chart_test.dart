import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nueva_app/features/huevos/huevo_pie_chart.dart';

void main() {
  group('HuevoPieChartPainter', () {
    test('normalizes negative and non-finite values to an all-zero chart', () {
      final painter = _painter(
        consumption: -1,
        sale: double.nan,
        broken: double.infinity,
      );

      expect(painter.values, [0, 0, 0]);
      expect(painter.percentageLabels, [null, null, null]);
      expect(() => _paint(painter, const Size(184, 184)), returnsNormally);
    });

    test('omits labels for zero slices', () {
      final painter = _painter(consumption: 3, sale: 0, broken: 1);

      expect(painter.percentageLabels, ['75%', null, '25%']);
    });

    test('paints safely inside very small and non-square bounds', () {
      final painter = _painter(consumption: 1, sale: 1, broken: 1);

      expect(() => _paint(painter, const Size(24, 18)), returnsNormally);
      expect(() => _paint(painter, const Size(1, 1)), returnsNormally);
      expect(() => _paint(painter, Size.zero), returnsNormally);
    });

    test('shouldRepaint compares every immutable paint input', () {
      final original = _painter(consumption: 1, sale: 2, broken: 3);

      expect(
        _painter(consumption: 1, sale: 2, broken: 3).shouldRepaint(original),
        isFalse,
      );
      expect(
        _painter(consumption: 2, sale: 2, broken: 3).shouldRepaint(original),
        isTrue,
      );
      expect(
        _painter(
          consumption: 1,
          sale: 2,
          broken: 3,
          emptyColor: Colors.black,
        ).shouldRepaint(original),
        isTrue,
      );
      expect(
        _painter(
          consumption: 1,
          sale: 2,
          broken: 3,
          labelStyle: const TextStyle(fontSize: 13),
        ).shouldRepaint(original),
        isTrue,
      );
    });
  });

  group('HuevoPieChart widget', () {
    testWidgets('exposes all-zero semantics and empty state', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: HuevoPieChart(consumption: 0, sale: 0, broken: 0),
            ),
          ),
        );

        expect(find.text('Sin datos'), findsOneWidget);
        expect(
          tester.getSemantics(find.byKey(const Key('egg-pie-semantics'))),
          matchesSemantics(
            label: 'Destino de los huevos: sin datos',
            isImage: true,
          ),
        );
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('normalizes values in semantics and accepts tight bounds', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox.square(
                dimension: 24,
                child: HuevoPieChart(
                  consumption: -5,
                  sale: 4,
                  broken: double.nan,
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(
          tester.getSemantics(find.byKey(const Key('egg-pie-semantics'))),
          matchesSemantics(
            label: 'Destino de los huevos: consumo 0, venta 4, rotos 0',
            isImage: true,
          ),
        );
      } finally {
        semantics.dispose();
      }
    });
  });
}

HuevoPieChartPainter _painter({
  required double consumption,
  required double sale,
  required double broken,
  Color emptyColor = Colors.grey,
  TextStyle labelStyle = const TextStyle(fontSize: 12),
}) {
  return HuevoPieChartPainter(
    consumption: consumption,
    sale: sale,
    broken: broken,
    consumptionColor: eggConsumptionColor,
    saleColor: eggSaleColor,
    brokenColor: Colors.red,
    emptyColor: emptyColor,
    labelStyle: labelStyle,
  );
}

void _paint(CustomPainter painter, Size size) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  painter.paint(canvas, size);
  recorder.endRecording();
}
