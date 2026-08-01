import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rancho/features/animales/animales_provider.dart';
import 'package:rancho/features/animales/animales_repository.dart'
    show AnimalesRepository;
import 'package:rancho/features/animales/baja_eligibility.dart';
import 'package:rancho/features/animales/registrar_baja_sheet.dart';
import 'package:rancho/features/model/animal/animal.dart';
import 'package:rancho/features/model/bajaAnimal/registrar_baja_animales_input.dart';
import 'package:rancho/features/model/catalogoItem/catalogo_item.dart';
import 'package:rancho/features/model/tipoAnimal/tipoAnimal.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('isAnimalEligibleForBaja', () {
    test('accepts an animal acquired on the same calendar day', () {
      expect(
        isAnimalEligibleForBaja(
          _animal(fechaAdquisicion: DateTime(2024, 1, 23)),
          tipoAnimalId: 'type-1',
          fechaBaja: DateTime(2024, 1, 23),
        ),
        isTrue,
      );
    });

    test('accepts an animal acquired before the baja date', () {
      expect(
        isAnimalEligibleForBaja(
          _animal(fechaAdquisicion: DateTime(2024, 1, 22)),
          tipoAnimalId: 'type-1',
          fechaBaja: DateTime(2024, 1, 23),
        ),
        isTrue,
      );
    });

    test('rejects an animal acquired after the baja date', () {
      expect(
        isAnimalEligibleForBaja(
          _animal(fechaAdquisicion: DateTime(2025, 1, 13)),
          tipoAnimalId: 'type-1',
          fechaBaja: DateTime(2024, 1, 23),
        ),
        isFalse,
      );
    });

    test('rejects an inactive animal', () {
      expect(
        isAnimalEligibleForBaja(
          _animal(activo: false),
          tipoAnimalId: 'type-1',
          fechaBaja: DateTime(2024, 1, 23),
        ),
        isFalse,
      );
    });

    test('rejects an animal with an existing baja', () {
      expect(
        isAnimalEligibleForBaja(
          _animal(bajaId: 'baja-1'),
          tipoAnimalId: 'type-1',
          fechaBaja: DateTime(2024, 1, 23),
        ),
        isFalse,
      );
    });

    test('rejects an animal of another type', () {
      expect(
        isAnimalEligibleForBaja(
          _animal(tipoAnimalId: 'type-2'),
          tipoAnimalId: 'type-1',
          fechaBaja: DateTime(2024, 1, 23),
        ),
        isFalse,
      );
    });

    test('normalizes time of day before comparing dates', () {
      expect(
        isAnimalEligibleForBaja(
          _animal(fechaAdquisicion: DateTime(2024, 1, 23, 23, 59)),
          tipoAnimalId: 'type-1',
          fechaBaja: DateTime(2024, 1, 23, 0, 1),
        ),
        isTrue,
      );
    });
  });

  test('date reconciliation removes newly ineligible selections', () {
    final result = reconcileBajaSelection(
      selectedAnimalIds: const ['eligible', 'future'],
      animals: [
        _animal(id: 'eligible', fechaAdquisicion: DateTime(2024, 1, 22)),
        _animal(id: 'future', fechaAdquisicion: DateTime(2025, 1, 13)),
      ],
      tipoAnimalId: 'type-1',
      fechaBaja: DateTime(2024, 1, 23),
    );

    expect(result.eligibleIds, {'eligible'});
    expect(result.removedCount, 1);
  });

  test('unavailable data does not produce a date reconciliation result', () {
    final result = reconcileBajaSelectionIfAvailable(
      selectedAnimalIds: const ['selected'],
      animals: null,
      tipoAnimalId: 'type-1',
      fechaBaja: DateTime(2024, 1, 23),
    );

    expect(result, isNull);
  });

  group('RegistrarBajaSheet', () {
    testWidgets('lists only animals acquired on or before the baja date', (
      tester,
    ) async {
      final repository = _FakeAnimalesRepository([
        _animal(
          id: 'eligible',
          brazalete: 22,
          fechaAdquisicion: DateTime(2024, 1, 22),
        ),
        _animal(
          id: 'future',
          brazalete: 13,
          fechaAdquisicion: DateTime(2025, 1, 13),
        ),
      ]);

      await _pumpSheet(tester, repository);

      expect(find.text('#22 · Gallinas'), findsOneWidget);
      expect(find.text('#13 · Gallinas'), findsNothing);
    });

    testWidgets('rejects a stale selection before calling the repository', (
      tester,
    ) async {
      final repository = _FakeAnimalesRepository([
        _animal(
          id: 'eligible',
          brazalete: 22,
          fechaAdquisicion: DateTime(2024, 1, 22),
        ),
      ]);
      final container = ProviderContainer(
        overrides: [animalesRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      await _pumpSheet(tester, repository, container: container);
      await tester.tap(find.text('Muerte'));
      await tester.tap(find.text('#22 · Gallinas'));
      await tester.pump();

      repository.animals = const [];
      container.invalidate(animalesProvider('farm-1'));
      await tester.pumpAndSettle();

      final saveButton = find.widgetWithText(FilledButton, 'Registrar baja');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pump();

      expect(repository.registrarBajaCalls, 0);
      expect(
        find.textContaining('La selección cambió. Se quitó 1 animal'),
        findsOneWidget,
      );
    });

    testWidgets(
      'waits for a refreshing provider and rejects fresh ineligible data',
      (tester) async {
        final repository = _FakeAnimalesRepository([
          _animal(
            id: 'selected',
            brazalete: 22,
            fechaAdquisicion: DateTime(2024, 1, 22),
          ),
        ]);
        final container = ProviderContainer(
          overrides: [animalesRepositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(container.dispose);

        await _pumpSheet(tester, repository, container: container);
        await tester.tap(find.text('Muerte'));
        await tester.tap(find.text('#22 · Gallinas'));
        await tester.pump();

        final refresh = Completer<List<Animal>>();
        repository.nextAnimals = refresh;
        container.invalidate(animalesProvider('farm-1'));
        await tester.pump();

        final saveButton = find.widgetWithText(FilledButton, 'Registrar baja');
        await tester.ensureVisible(saveButton);
        await tester.tap(saveButton);
        await tester.pump();

        expect(repository.registrarBajaCalls, 0);
        expect(find.text('Guardando…'), findsOneWidget);

        refresh.complete([
          _animal(
            id: 'selected',
            brazalete: 22,
            fechaAdquisicion: DateTime(2025, 1, 13),
          ),
        ]);
        await tester.pumpAndSettle();

        expect(repository.registrarBajaCalls, 0);
        expect(
          find.textContaining('La selección cambió. Se quitó 1 animal'),
          findsOneWidget,
        );
      },
    );

    testWidgets('fails closed when the current provider future fails', (
      tester,
    ) async {
      final repository = _FakeAnimalesRepository([
        _animal(
          id: 'selected',
          brazalete: 22,
          fechaAdquisicion: DateTime(2024, 1, 22),
        ),
      ]);
      final container = ProviderContainer(
        overrides: [animalesRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      await _pumpSheet(tester, repository, container: container);
      await tester.tap(find.text('Muerte'));
      await tester.tap(find.text('#22 · Gallinas'));
      await tester.pump();

      final refresh = Completer<List<Animal>>();
      repository.nextAnimals = refresh;
      container.invalidate(animalesProvider('farm-1'));
      await tester.pump();

      final saveButton = find.widgetWithText(FilledButton, 'Registrar baja');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pump();

      refresh.completeError(StateError('refresh failed'));
      await tester.pumpAndSettle();

      expect(repository.registrarBajaCalls, 0);
      expect(
        find.text(
          'No se pudo actualizar la lista de animales. Intenta nuevamente.',
        ),
        findsOneWidget,
      );
    });
  });
}

Future<void> _pumpSheet(
  WidgetTester tester,
  _FakeAnimalesRepository repository, {
  ProviderContainer? container,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final child = MaterialApp(
    home: Scaffold(
      body: RegistrarBajaSheet(
        granjaId: 'farm-1',
        isDark: false,
        tipoAnimalIdInicial: 'type-1',
        initialBajaDate: DateTime(2024, 1, 23),
      ),
    ),
  );

  await tester.pumpWidget(
    container == null
        ? ProviderScope(
            overrides: [
              animalesRepositoryProvider.overrideWithValue(repository),
            ],
            child: child,
          )
        : UncontrolledProviderScope(container: container, child: child),
  );
  await tester.pumpAndSettle();
}

Animal _animal({
  String id = 'animal-1',
  String tipoAnimalId = 'type-1',
  DateTime? fechaAdquisicion,
  bool activo = true,
  String? bajaId,
  int? brazalete,
}) => Animal(
  id: id,
  granjaId: 'farm-1',
  tipoAnimalId: tipoAnimalId,
  bajaId: bajaId,
  brazalete: brazalete,
  fechaAdquisicion: fechaAdquisicion ?? DateTime(2024, 1, 22),
  activo: activo,
  tipoNombre: 'Gallinas',
  grupoNombre: 'Ponedoras',
);

class _FakeAnimalesRepository extends AnimalesRepository {
  _FakeAnimalesRepository(this.animals) : super(_buildClient());

  List<Animal> animals;
  Completer<List<Animal>>? nextAnimals;
  int registrarBajaCalls = 0;

  @override
  Future<List<TipoAnimal>> getTipos(String granjaId) async => const [
    TipoAnimal(
      id: 'type-1',
      granjaId: 'farm-1',
      nombre: 'Gallinas',
      createdBy: 'user-1',
    ),
  ];

  @override
  Future<List<CatalogoItem>> getRazonesBaja(String granjaId) async => const [
    CatalogoItem(id: 'reason-1', nombre: 'Muerte'),
  ];

  @override
  Future<List<Animal>> getAnimales(String granjaId) {
    final nextResult = nextAnimals;
    if (nextResult != null) {
      nextAnimals = null;
      return nextResult.future;
    }
    return Future.value(animals);
  }

  @override
  Future<void> registrarBajaAnimales(RegistrarBajaAnimalesInput input) async {
    registrarBajaCalls++;
  }
}

SupabaseClient _buildClient() {
  final client = SupabaseClient('https://example.supabase.co', 'anon-key');
  client.auth.stopAutoRefresh();
  return client;
}
