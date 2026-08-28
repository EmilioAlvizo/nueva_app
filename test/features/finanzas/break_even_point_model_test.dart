import 'package:flutter_test/flutter_test.dart';
import 'package:rancho/features/finanzas/data/models/break_even_point_model.dart';

void main() {
  group('BreakEvenPointModel', () {
    test('maps every numeric field from strings and numbers', () {
      final entity = BreakEvenPointModel.fromJson({
        ..._validJson,
        'buenos': '97',
        'rotos': 2,
        'total_costo_comidas': '800',
        'punto_de_equilibrio': 8.2474,
        'dias_mezcla': '26',
        'consumo_total': 80,
        'aves_promedio_ponderado': '15',
        'huevos_por_dia': 3.7308,
        'huevos_por_dia_ave': '0.2487',
        'consumo_por_dia': 3.0769,
        'consumo_por_dia_ave': '0.2051',
        'precio_venta_promedio': 5,
        'margen_porcentaje': '-39.37',
      }).toEntity();

      expect(entity.farmId, '48b129e9-a48b-438a-a401-96d4dd863da5');
      expect(entity.groupId, '7428302e-9d3b-4967-9baa-4747c98778bc');
      expect(entity.startedAt, DateTime(2026, 7, 1));
      expect(entity.endedAt, isNull);
      expect(entity.calculatedEndAt, DateTime(2026, 7, 26));
      expect(entity.mixtureDays, 26);
      expect(entity.goodEggs, 97);
      expect(entity.brokenEggs, 2);
      expect(entity.totalFoodCost, 800);
      expect(entity.totalFeedConsumption, 80);
      expect(entity.weightedAverageBirds, 15);
      expect(entity.eggsPerDay, closeTo(3.7308, 0.000001));
      expect(entity.eggsPerDayPerBird, closeTo(0.2487, 0.000001));
      expect(entity.feedPerDay, closeTo(3.0769, 0.000001));
      expect(entity.feedPerDayPerBird, closeTo(0.2051, 0.000001));
      expect(entity.breakEvenPrice, closeTo(8.2474, 0.000001));
      expect(entity.averageSalePrice, 5);
      expect(entity.marginPercentage, closeTo(-39.37, 0.000001));
    });

    test('maps every numeric field when Supabase encodes it as a string', () {
      final entity = BreakEvenPointModel.fromJson({
        ..._validJson,
        for (final key in _numericKeys) key: '${_validJson[key]}',
      }).toEntity();

      expect(entity.goodEggs, 97);
      expect(entity.brokenEggs, 2);
      expect(entity.totalFoodCost, 800);
      expect(entity.breakEvenPrice, closeTo(8.2474, 0.000001));
      expect(entity.mixtureDays, 26);
      expect(entity.totalFeedConsumption, 80);
      expect(entity.weightedAverageBirds, 15);
      expect(entity.eggsPerDay, closeTo(3.7308, 0.000001));
      expect(entity.eggsPerDayPerBird, closeTo(0.2487, 0.000001));
      expect(entity.feedPerDay, closeTo(3.0769, 0.000001));
      expect(entity.feedPerDayPerBird, closeTo(0.2051, 0.000001));
      expect(entity.averageSalePrice, 5);
      expect(entity.marginPercentage, closeTo(-39.37, 0.000001));
    });

    test('preserves nullable break-even, sale price, and margin values', () {
      final entity = BreakEvenPointModel.fromJson({
        ..._validJson,
        'punto_de_equilibrio': null,
        'precio_venta_promedio': null,
        'margen_porcentaje': null,
      }).toEntity();

      expect(entity.breakEvenPrice, isNull);
      expect(entity.averageSalePrice, isNull);
      expect(entity.marginPercentage, isNull);
    });

    test('preserves unavailable per-bird metrics as null', () {
      final entity = BreakEvenPointModel.fromJson({
        ..._validJson,
        'aves_promedio_ponderado': 0,
        'huevos_por_dia_ave': null,
        'consumo_por_dia_ave': null,
      }).toEntity();

      expect(entity.weightedAverageBirds, 0);
      expect(entity.eggsPerDayPerBird, isNull);
      expect(entity.feedPerDayPerBird, isNull);
    });

    test('rejects malformed required identity and calculated values', () {
      expect(
        () => BreakEvenPointModel.fromJson({..._validJson, 'granja_id': 'bad'}),
        throwsFormatException,
      );
      expect(
        () => BreakEvenPointModel.fromJson({
          ..._validJson,
          'fecha_fin_calculada': null,
        }),
        throwsFormatException,
      );

      for (final key in [
        'dias_mezcla',
        'consumo_total',
        'aves_promedio_ponderado',
        'huevos_por_dia',
        'huevos_por_dia_ave',
        'consumo_por_dia',
        'consumo_por_dia_ave',
      ]) {
        expect(
          () => BreakEvenPointModel.fromJson({..._validJson, key: 'invalid'}),
          throwsFormatException,
          reason: key,
        );
      }
    });

    test('rejects malformed nullable numeric values when present', () {
      for (final key in [
        'punto_de_equilibrio',
        'precio_venta_promedio',
        'margen_porcentaje',
      ]) {
        expect(
          () => BreakEvenPointModel.fromJson({..._validJson, key: 'invalid'}),
          throwsFormatException,
          reason: key,
        );
      }
    });
  });
}

final _validJson = <String, Object?>{
  'fecha_inicio': '2026-07-01',
  'fecha_termino': null,
  'mezcla_id': '416e648e-1dd2-4a2f-8246-e42bcc6f36cb',
  'grupo_nombre': 'Ponedoras',
  'buenos': 97,
  'rotos': 2,
  'total_costo_comidas': 800,
  'punto_de_equilibrio': 8.2474,
  'granja_id': '48b129e9-a48b-438a-a401-96d4dd863da5',
  'grupo_id': '7428302e-9d3b-4967-9baa-4747c98778bc',
  'fecha_fin_calculada': '2026-07-26',
  'dias_mezcla': 26,
  'consumo_total': 80,
  'aves_promedio_ponderado': 15,
  'huevos_por_dia': 3.7308,
  'huevos_por_dia_ave': 0.2487,
  'consumo_por_dia': 3.0769,
  'consumo_por_dia_ave': 0.2051,
  'precio_venta_promedio': 5,
  'margen_porcentaje': -39.37,
};

const _numericKeys = [
  'buenos',
  'rotos',
  'total_costo_comidas',
  'punto_de_equilibrio',
  'dias_mezcla',
  'consumo_total',
  'aves_promedio_ponderado',
  'huevos_por_dia',
  'huevos_por_dia_ave',
  'consumo_por_dia',
  'consumo_por_dia_ave',
  'precio_venta_promedio',
  'margen_porcentaje',
];
