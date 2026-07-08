import 'package:flutter_test/flutter_test.dart';
import 'package:nueva_app/features/model/altaAnimales/altaAnimales.dart';
import 'package:nueva_app/features/model/altaAnimales/registrar_alta_animales_input.dart';
import 'package:nueva_app/features/model/animal/animal.dart';

void main() {
  group('RegistrarAltaAnimalesInput.toRpcParams', () {
    test('maps the expected rpc payload', () {
      final input = RegistrarAltaAnimalesInput(
        granjaId: 'farm-1',
        tipoAnimalId: 'type-1',
        grupoId: 'group-1',
        propositoId: 'purpose-1',
        tipoAdquisicionId: 'acquisition-1',
        fechaAlta: DateTime.utc(2026, 7, 8),
        cantidad: 2,
        bracelets: const [21, 22],
        proveedor: 'Proveedor',
        costoTotal: 87.5,
        notas: 'Observaciones',
      );

      expect(input.toRpcParams(), {
        'granja_id': 'farm-1',
        'tipo_animal_id': 'type-1',
        'grupo_id': 'group-1',
        'proposito_id': 'purpose-1',
        'tipo_adquisicion_id': 'acquisition-1',
        'fecha_alta': '2026-07-08',
        'cantidad': 2,
        'bracelets': [21, 22],
        'proveedor': 'Proveedor',
        'costo_total': 87.5,
        'notas': 'Observaciones',
      });
    });

    test('keeps optional payload members nullable when omitted', () {
      final input = RegistrarAltaAnimalesInput(
        granjaId: 'farm-1',
        tipoAnimalId: 'type-1',
        fechaAlta: DateTime.utc(2026, 7, 8),
        cantidad: 1,
      );

      expect(input.toRpcParams()['grupo_id'], isNull);
      expect(input.toRpcParams()['proposito_id'], isNull);
      expect(input.toRpcParams()['tipo_adquisicion_id'], isNull);
      expect(input.toRpcParams()['bracelets'], isNull);
      expect(input.toRpcParams()['proveedor'], isNull);
      expect(input.toRpcParams()['costo_total'], isNull);
      expect(input.toRpcParams()['notas'], isNull);
    });
  });

  group('AltaAnimales.fromJson', () {
    test('maps createdAt from created_at', () {
      final alta = AltaAnimales.fromJson({
        'id': 'alta-1',
        'granja_id': 'farm-1',
        'tipo_animal_id': 'type-1',
        'grupo_id': 'group-1',
        'proposito_id': null,
        'tipo_adquisicion_id': null,
        'proveedor': 'Proveedor',
        'fecha_alta': '2026-07-08',
        'cantidad_animales': 4,
        'costo_total': 123.45,
        'notas': 'Observaciones',
        'created_by': 'user-1',
        'created_at': '2026-07-08T14:30:00Z',
        'brazaletes': [1, 2, 3, 4],
      });

      expect(alta.createdAt, DateTime.parse('2026-07-08T14:30:00Z'));
      expect(alta.fechaAlta, DateTime.parse('2026-07-08'));
    });

    test('keeps nullable relationship fields nullable', () {
      final alta = AltaAnimales.fromJson({
        'id': 'alta-2',
        'granja_id': 'farm-1',
        'tipo_animal_id': 'type-1',
        'grupo_id': null,
        'proposito_id': null,
        'tipo_adquisicion_id': null,
        'proveedor': null,
        'fecha_alta': '2026-07-08',
        'cantidad_animales': 1,
        'costo_total': null,
        'notas': null,
        'created_by': 'user-1',
        'created_at': '2026-07-08T14:30:00Z',
      });

      expect(alta.grupoId, isNull);
      expect(alta.propositoId, isNull);
      expect(alta.tipoAdquisicionId, isNull);
      expect(alta.brazaletes, isEmpty);
    });
  });

  group('Animal.fromJson', () {
    test('uses Sin grupo when the joined group is null', () {
      final animal = Animal.fromJson({
        'id': 'animal-1',
        'granja_id': 'farm-1',
        'tipo_animal_id': 'type-1',
        'grupo_id': null,
        'alta_id': null,
        'baja_id': null,
        'brazalete': null,
        'proposito_id': null,
        'tipo_adquisicion_id': null,
        'fecha_adquisicion': '2026-07-08',
        'costo_adquisicion': null,
        'activo': true,
        'notas': null,
        'tipo_nombre': 'Gallina',
        'grupo_nombre': null,
      });

      expect(animal.grupoNombre, 'Sin grupo');
      expect(animal.altaId, isNull);
      expect(animal.brazalete, isNull);
    });

    test('preserves the joined group name when it exists', () {
      final animal = Animal.fromJson({
        'id': 'animal-2',
        'granja_id': 'farm-1',
        'tipo_animal_id': 'type-1',
        'grupo_id': 'group-9',
        'alta_id': 'alta-9',
        'baja_id': null,
        'brazalete': 18,
        'proposito_id': 'purpose-1',
        'tipo_adquisicion_id': 'acquisition-1',
        'fecha_adquisicion': '2026-07-08',
        'costo_adquisicion': 45.5,
        'activo': false,
        'notas': 'Observaciones',
        'tipo_nombre': 'Gallina',
        'grupo_nombre': 'Corral Norte',
      });

      expect(animal.grupoNombre, 'Corral Norte');
      expect(animal.altaId, 'alta-9');
      expect(animal.brazalete, 18);
    });
  });
}
