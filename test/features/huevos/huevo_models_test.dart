import 'package:flutter_test/flutter_test.dart';
import 'package:nueva_app/features/huevos/huevo_models.dart';

void main() {
  group('RecoleccionHuevo.fromJson', () {
    test('maps live production columns without period dependency', () {
      final model = RecoleccionHuevo.fromJson({
        'id': 'rec-1',
        'granja_id': 'farm-1',
        'tipo_animal_id': 'tipo-1',
        'grupo_id': 'grupo-1',
        'fecha': '2026-07-03',
        'cantidad_buena': 24,
        'cantidad_merma': 3,
        'notas': 'Morning collection',
        'created_at': '2026-07-03T10:00:00Z',
        'tipo_nombre': 'Ponedoras',
        'grupo_nombre': 'Lote A',
      });

      expect(model.id, 'rec-1');
      expect(model.granjaId, 'farm-1');
      expect(model.tipoAnimalId, 'tipo-1');
      expect(model.grupoId, 'grupo-1');
      expect(model.huevosBuenos, 24);
      expect(model.huevosRotos, 3);
      expect(model.total, 27);
      expect(model.tipoNombre, 'Ponedoras');
      expect(model.grupoNombre, 'Lote A');
    });

    test('keeps joined display names optional when absent', () {
      final model = RecoleccionHuevo.fromJson({
        'id': 'rec-2',
        'granja_id': 'farm-1',
        'tipo_animal_id': 'tipo-2',
        'grupo_id': null,
        'fecha': '2026-07-04',
        'cantidad_buena': 10,
        'cantidad_merma': 0,
        'notas': null,
        'created_at': '2026-07-04T10:00:00Z',
      });

      expect(model.tipoNombre, isEmpty);
      expect(model.grupoNombre, isNull);
      expect(model.total, 10);
    });
  });

  group('ReduccionHuevo.fromJson', () {
    test('maps live salida columns and keeps display names', () {
      final model = ReduccionHuevo.fromJson({
        'id': 'sal-1',
        'granja_id': 'farm-1',
        'tipo_animal_id': 'tipo-1',
        'razon_salida_id': 'reason-1',
        'cantidad': 7,
        'importe_total': 140.5,
        'fecha': '2026-07-03',
        'notas': 'Sold to local store',
        'created_at': '2026-07-03T12:00:00Z',
        'tipo_nombre': 'Ponedoras',
        'razon_nombre': 'Venta',
      });

      expect(model.razonSalidaId, 'reason-1');
      expect(model.cantidad, 7);
      expect(model.importe, 140.5);
      expect(model.tipoNombre, 'Ponedoras');
      expect(model.razonNombre, 'Venta');
      expect(model.razonReduccionId, 'reason-1');
    });

    test('allows null importe_total while keeping empty joined names', () {
      final model = ReduccionHuevo.fromJson({
        'id': 'sal-2',
        'granja_id': 'farm-1',
        'tipo_animal_id': 'tipo-2',
        'razon_salida_id': 'reason-2',
        'cantidad': 2,
        'importe_total': null,
        'fecha': '2026-07-04',
        'notas': null,
        'created_at': '2026-07-04T12:00:00Z',
      });

      expect(model.importe, isNull);
      expect(model.razonNombre, isEmpty);
      expect(model.tipoNombre, isEmpty);
    });
  });

  group('MovHuevo factories', () {
    test('deRecoleccion keeps the mapped production values', () {
      final recoleccion = RecoleccionHuevo(
        id: 'rec-3',
        granjaId: 'farm-1',
        tipoAnimalId: 'tipo-1',
        grupoId: 'grupo-1',
        fecha: DateTime.utc(2026, 7, 5),
        huevosBuenos: 8,
        huevosRotos: 1,
        notas: 'Afternoon collection',
        createdAt: DateTime.utc(2026, 7, 5, 13),
        tipoNombre: 'Ponedoras',
        grupoNombre: 'Lote B',
      );

      final mov = MovHuevo.deRecoleccion(recoleccion);

      expect(mov.tipo, TipoMovHuevo.recoleccion);
      expect(mov.huevosBuenos, 8);
      expect(mov.huevosRotos, 1);
      expect(mov.grupoNombre, 'Lote B');
      expect(mov.notas, 'Afternoon collection');
    });

    test('deReduccion exposes the renamed salida reason identifier', () {
      final reduccion = ReduccionHuevo(
        id: 'sal-3',
        granjaId: 'farm-1',
        tipoAnimalId: 'tipo-1',
        razonSalidaId: 'reason-3',
        cantidad: 4,
        importe: 80,
        fecha: DateTime.utc(2026, 7, 5),
        notas: 'Damaged batch',
        createdAt: DateTime.utc(2026, 7, 5, 14),
        tipoNombre: 'Ponedoras',
        razonNombre: 'Merma',
      );

      final mov = MovHuevo.deReduccion(reduccion);

      expect(mov.tipo, TipoMovHuevo.reduccion);
      expect(mov.cantidad, 4);
      expect(mov.importe, 80);
      expect(mov.razonNombre, 'Merma');
      expect(mov.razonSalidaId, 'reason-3');
      expect(mov.razonReduccionId, 'reason-3');
    });
  });
}
