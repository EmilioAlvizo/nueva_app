import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nueva_app/core/testing/app_widget_keys.dart';
import 'package:nueva_app/core/theme/app_colors.dart';
import 'package:nueva_app/core/theme/app_theme.dart';
import 'package:nueva_app/features/animales/animales_provider.dart';
import 'package:nueva_app/features/huevos/huevo_models.dart';
import 'package:nueva_app/features/huevos/huevo_provider.dart';
import 'package:nueva_app/features/huevos/huevo_repository.dart';
import 'package:nueva_app/features/huevos/huevos_screen.dart';
import 'package:nueva_app/features/model/grupo/grupo.dart';
import 'package:nueva_app/features/model/tipoAnimal/tipoAnimal.dart';

void main() {
  testWidgets('horizontal swipes navigate all tabs and back', (tester) async {
    await _pumpScreen(tester, canEdit: true);

    expect(find.byKey(const Key('egg-segmented-tabs')), findsOneWidget);
    expect(find.byKey(const Key('egg-selected-tab-check')), findsOneWidget);
    _expectEggTabSelected('summary');
    expect(find.byKey(const Key('egg-summary-view')), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);

    await tester.drag(_key(AppWidgetKeys.eggPages), const Offset(-600, 0));
    await tester.pumpAndSettle();
    _expectEggTabSelected('add');
    expect(find.byKey(const ValueKey('egg-fab-add')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('egg-collection-collection-1')),
      findsOneWidget,
    );

    await tester.drag(_key(AppWidgetKeys.eggPages), const Offset(-600, 0));
    await tester.pumpAndSettle();
    _expectEggTabSelected('reduce');
    expect(find.byKey(const ValueKey('egg-fab-reduce')), findsOneWidget);
    expect(find.byKey(const ValueKey('egg-sale-sale-1')), findsOneWidget);

    await tester.drag(_key(AppWidgetKeys.eggPages), const Offset(600, 0));
    await tester.pumpAndSettle();
    _expectEggTabSelected('add');
    expect(find.byKey(const ValueKey('egg-fab-add')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('egg-collection-collection-1')),
      findsOneWidget,
    );

    await tester.drag(_key(AppWidgetKeys.eggPages), const Offset(600, 0));
    await tester.pumpAndSettle();
    _expectEggTabSelected('summary');
    expect(find.byKey(const Key('egg-summary-view')), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('tab taps stay synchronized with horizontal swipes', (
    tester,
  ) async {
    await _pumpScreen(tester, canEdit: true);

    await tester.tap(find.byKey(const ValueKey('egg-tab-reduce')));
    await tester.pumpAndSettle();
    _expectEggTabSelected('reduce');
    expect(find.byKey(const ValueKey('egg-sale-sale-1')), findsOneWidget);

    await tester.drag(_key(AppWidgetKeys.eggPages), const Offset(600, 0));
    await tester.pumpAndSettle();
    _expectEggTabSelected('add');
    expect(find.byKey(const ValueKey('egg-fab-add')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('egg-collection-collection-1')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('egg-tab-summary')));
    await tester.pumpAndSettle();
    _expectEggTabSelected('summary');
    expect(find.byKey(const Key('egg-summary-view')), findsOneWidget);
  });

  testWidgets('tab animation follows the page and retargets midway', (
    tester,
  ) async {
    await _pumpScreen(tester, canEdit: true);

    await tester.tap(find.byKey(const ValueKey('egg-tab-reduce')));
    await tester.pump();
    _expectEggTabSelected('summary');
    expect(_pagePosition(tester, AppWidgetKeys.eggPages), 0);

    await tester.pump(const Duration(milliseconds: 50));
    _expectEggTabSelected('add');
    expect(
      _pagePosition(tester, AppWidgetKeys.eggPages),
      inInclusiveRange(0.5, 1.5),
    );

    await tester.tap(find.byKey(const ValueKey('egg-tab-add')));
    await tester.pumpAndSettle();
    _expectEggTabSelected('add');
    expect(_pagePosition(tester, AppWidgetKeys.eggPages), closeTo(1, 0.001));
    expect(
      find.byKey(const ValueKey('egg-collection-collection-1')),
      findsOneWidget,
    );
  });

  testWidgets('read-only access hides record menus and mutation FABs', (
    tester,
  ) async {
    await _pumpScreen(tester, canEdit: false);

    await tester.tap(find.byKey(const ValueKey('egg-tab-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('egg-record-menu')), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);

    await tester.tap(find.byKey(const ValueKey('egg-tab-reduce')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('egg-record-menu')), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('collection and sale share the ID-resolved animal type color', (
    tester,
  ) async {
    await _pumpScreen(tester, canEdit: false);

    await tester.tap(find.byKey(const ValueKey('egg-tab-add')));
    await tester.pumpAndSettle();
    final collectionStripe = tester.widget<ColoredBox>(
      find.byKey(const Key('egg-animal-type-stripe')),
    );
    expect(collectionStripe.color, AppColors.tipoColor[1]);
    expect(find.text('Display name unrelated to type ID'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('egg-tab-reduce')));
    await tester.pumpAndSettle();
    final saleStripe = tester.widget<ColoredBox>(
      find.byKey(const Key('egg-sale-animal-type-stripe')),
    );
    expect(saleStripe.color, collectionStripe.color);
    expect(saleStripe.color, AppColors.tipoColor[1]);
    expect(find.text('Display name unrelated to type ID'), findsOneWidget);
  });
}

Finder _key(String value) => find.byKey(ValueKey(value));

double _pagePosition(WidgetTester tester, String keyValue) {
  return tester.widget<PageView>(_key(keyValue)).controller!.page!;
}

void _expectEggTabSelected(String tabName) {
  expect(
    find.descendant(
      of: find.byKey(ValueKey('egg-tab-$tabName')),
      matching: find.byKey(const Key('egg-selected-tab-check')),
    ),
    findsOneWidget,
  );
}

Future<void> _pumpScreen(WidgetTester tester, {required bool canEdit}) async {
  const farmId = 'farm-1';
  final repository = _FakeHuevoRepository(canEdit: canEdit);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        huevoRepositoryProvider.overrideWithValue(repository),
        tiposAnimalProvider(farmId).overrideWith((ref) async => _animalTypes),
        gruposProvider(farmId).overrideWith((ref) async => _groups),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: const HuevosScreen(granjaId: farmId),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _animalTypes = [
  TipoAnimal(
    id: 'type-1',
    granjaId: 'farm-1',
    nombre: 'Gallinas',
    createdBy: 'user-1',
  ),
  TipoAnimal(
    id: 'type-2',
    granjaId: 'farm-1',
    nombre: 'Codornices',
    createdBy: 'user-1',
  ),
];

const _groups = [
  Grupo(
    id: 'group-1',
    granjaId: 'farm-1',
    tipoAnimalId: 'type-1',
    nombre: 'Ponedoras',
  ),
];

final class _FakeHuevoRepository implements HuevoRepository {
  _FakeHuevoRepository({required this.canEdit});

  final bool canEdit;

  @override
  Future<List<EggCollection>> getCollections(String farmId) async => [
    EggCollection(
      id: 'collection-1',
      farmId: farmId,
      groupId: 'group-1',
      date: DateTime.now(),
      goodEggs: 18,
      brokenEggs: 2,
      createdAt: DateTime.now(),
      groupName: 'Ponedoras',
      animalTypeId: 'type-2',
      animalTypeName: 'Display name unrelated to type ID',
      authorName: 'Ana Pérez',
    ),
  ];

  @override
  Future<List<EggSale>> getSales(String farmId) async => [
    EggSale(
      id: 'sale-1',
      farmId: farmId,
      groupId: 'group-1',
      date: DateTime.now(),
      quantity: 4,
      unitPrice: 3,
      createdAt: DateTime.now(),
      groupName: 'Ponedoras',
      animalTypeId: 'type-2',
      animalTypeName: 'Display name unrelated to type ID',
      authorName: 'Ana Pérez',
    ),
  ];

  @override
  Future<EggAccess> getAccess(String farmId) async =>
      EggAccess(canEdit: canEdit);

  @override
  Future<void> createCollection(EggCollectionInput input) async {}

  @override
  Future<void> updateCollection({
    required String collectionId,
    required EggCollectionInput input,
  }) async {}

  @override
  Future<void> deleteCollection({
    required String farmId,
    required String collectionId,
  }) async {}

  @override
  Future<void> createSale(EggSaleInput input) async {}

  @override
  Future<void> updateSale({
    required String saleId,
    required EggSaleInput input,
  }) async {}

  @override
  Future<void> deleteSale({
    required String farmId,
    required String saleId,
  }) async {}
}
