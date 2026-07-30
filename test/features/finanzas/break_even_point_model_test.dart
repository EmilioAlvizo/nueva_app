import 'package:flutter_test/flutter_test.dart';
import 'package:nueva_app/features/finanzas/data/models/break_even_point_model.dart';

void main() {
  group('BreakEvenPointModel', () {
    test('maps numeric strings and numbers to a typed entity', () {
      final entity = BreakEvenPointModel.fromJson({
        'fecha_inicio': '2023-12-11',
        'fecha_termino': '2024-02-12',
        'mezcla_id': '97eb3256-1dd0-42cf-91d0-7d5b84e23b62',
        'grupo_nombre': 'Gallinero',
        'buenos': '184',
        'rotos': 0,
        'total_costo_comidas': '610',
        'punto_de_equilibrio': '3.3152173913043478',
      }).toEntity();

      expect(entity.startedAt, DateTime(2023, 12, 11));
      expect(entity.endedAt, DateTime(2024, 2, 12));
      expect(entity.mixtureId, '97eb3256-1dd0-42cf-91d0-7d5b84e23b62');
      expect(entity.groupName, 'Gallinero');
      expect(entity.goodEggs, 184);
      expect(entity.brokenEggs, 0);
      expect(entity.totalFoodCost, 610);
      expect(entity.breakEvenPrice, closeTo(3.3152173913043478, 0.000001));
    });

    test('preserves nullable end date and break-even value', () {
      final entity = BreakEvenPointModel.fromJson({
        'fecha_inicio': '2026-07-01',
        'fecha_termino': null,
        'mezcla_id': '416e648e-1dd2-4a2f-8246-e42bcc6f36cb',
        'grupo_nombre': 'Ponedoras',
        'buenos': 0,
        'rotos': '2',
        'total_costo_comidas': 18.5,
        'punto_de_equilibrio': null,
      }).toEntity();

      expect(entity.endedAt, isNull);
      expect(entity.breakEvenPrice, isNull);
      expect(entity.totalFoodCost, 18.5);
    });

    test('rejects malformed required identity fields', () {
      final valid = <String, Object?>{
        'fecha_inicio': '2026-07-01',
        'fecha_termino': null,
        'mezcla_id': '416e648e-1dd2-4a2f-8246-e42bcc6f36cb',
        'grupo_nombre': 'Ponedoras',
        'buenos': 12,
        'rotos': 1,
        'total_costo_comidas': '45.25',
        'punto_de_equilibrio': '3.77',
      };

      expect(
        () => BreakEvenPointModel.fromJson({...valid, 'mezcla_id': 'bad-id'}),
        throwsFormatException,
      );
      expect(
        () => BreakEvenPointModel.fromJson({...valid, 'grupo_nombre': ' '}),
        throwsFormatException,
      );
      expect(
        () => BreakEvenPointModel.fromJson({...valid, 'fecha_inicio': null}),
        throwsFormatException,
      );
    });

    test('rejects malformed required numeric values', () {
      final valid = <String, Object?>{
        'fecha_inicio': '2026-07-01',
        'fecha_termino': null,
        'mezcla_id': '416e648e-1dd2-4a2f-8246-e42bcc6f36cb',
        'grupo_nombre': 'Ponedoras',
        'buenos': 12,
        'rotos': 1,
        'total_costo_comidas': '45.25',
        'punto_de_equilibrio': '3.77',
      };

      expect(
        () => BreakEvenPointModel.fromJson({...valid, 'buenos': 'many'}),
        throwsFormatException,
      );
      expect(
        () => BreakEvenPointModel.fromJson({
          ...valid,
          'total_costo_comidas': double.nan,
        }),
        throwsFormatException,
      );
      expect(
        () => BreakEvenPointModel.fromJson({
          ...valid,
          'punto_de_equilibrio': 'invalid',
        }),
        throwsFormatException,
      );
    });
  });
}
