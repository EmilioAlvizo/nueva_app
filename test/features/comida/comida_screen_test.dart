import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rancho/features/comida/comida_models.dart';
import 'package:rancho/features/comida/comida_provider.dart';
import 'package:rancho/features/comida/comida_repository.dart';
import 'package:rancho/features/comida/comida_screen.dart';

void main() {
  testWidgets('shows the two redesigned tabs, metrics, and visible actions', (
    tester,
  ) async {
    await tester.pumpWidget(const _TestApp(repository: _FakeRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Mezclas'), findsWidgets);
    expect(find.text('Categorías'), findsWidgets);
    expect(find.text('Gasto total'), findsOneWidget);
    expect(find.text('Total', skipOffstage: false), findsWidgets);
    expect(find.text('Agregar'), findsNothing);
    expect(find.text('Activa'), findsOneWidget);
    expect(find.byTooltip('Editar mezcla'), findsOneWidget);
    expect(find.byTooltip('Eliminar mezcla'), findsOneWidget);
    expect(find.byTooltip('Nueva mezcla'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('food-tab-Categorías')));
    await tester.pumpAndSettle();

    expect(find.text('Maíz'), findsOneWidget);
    expect(find.byTooltip('Editar categoría'), findsOneWidget);
    expect(find.byTooltip('Eliminar categoría'), findsOneWidget);
    expect(find.byTooltip('Nueva categoría'), findsOneWidget);
  });

  testWidgets('opens mixture form after async categories and groups load', (
    tester,
  ) async {
    final repository = _AsyncFakeRepository();
    await tester.pumpWidget(_TestApp(repository: repository));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byKey(const ValueKey('comida-fab-mixtures')));
    await tester.pump();
    repository.categories.complete(
      await const _FakeRepository().getCategories('farm-1'),
    );
    repository.groups.complete(
      await const _FakeRepository().getGroups('farm-1'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nueva mezcla'), findsOneWidget);
    expect(find.text('Selecciona un grupo'), findsOneWidget);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.repository});

  final ComidaRepository repository;

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [comidaRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: const ComidaScreen(granjaId: 'farm-1'),
    ),
  );
}

class _FakeRepository implements ComidaRepository {
  const _FakeRepository();

  @override
  Future<FoodAccess> getAccess(String farmId) async =>
      const FoodAccess(canEdit: true);

  @override
  Future<List<FoodCategory>> getCategories(String farmId) async => const [
    FoodCategory(id: 'cat-1', farmId: 'farm-1', name: 'Maíz', isActive: true),
  ];

  @override
  Future<List<FoodGroup>> getGroups(String farmId) async => const [
    FoodGroup(id: 'group-1', name: 'Ponedoras'),
  ];

  @override
  Future<List<FoodMixture>> getMixtures(String farmId) async => [
    FoodMixture(
      id: 'mix-1',
      farmId: 'farm-1',
      groupId: 'group-1',
      groupName: 'Ponedoras',
      startDate: DateTime(2026, 7, 10),
      updatedAt: DateTime(2026, 7, 10, 11),
      ingredients: const [
        MixtureIngredient(
          id: 'line-1',
          foodId: 'food-1',
          categoryId: 'cat-1',
          categoryName: 'Maíz',
          categoryIsActive: true,
          quantityKg: 10,
          totalCost: 25,
        ),
      ],
    ),
  ];

  @override
  Future<void> createCategory({
    required String farmId,
    required String name,
  }) async {}

  @override
  Future<void> createMixture(MixtureInput input) async {}

  @override
  Future<void> deleteCategory({
    required String farmId,
    required String categoryId,
  }) async {}

  @override
  Future<void> deleteMixture({
    required String farmId,
    required String mixtureId,
  }) async {}

  @override
  Future<void> updateCategory({
    required String farmId,
    required String categoryId,
    required String name,
  }) async {}

  @override
  Future<void> updateMixture({
    required String mixtureId,
    required MixtureInput input,
  }) async {}
}

class _AsyncFakeRepository extends _FakeRepository {
  final categories = Completer<List<FoodCategory>>();
  final groups = Completer<List<FoodGroup>>();

  @override
  Future<List<FoodCategory>> getCategories(String farmId) => categories.future;

  @override
  Future<List<FoodGroup>> getGroups(String farmId) => groups.future;
}
