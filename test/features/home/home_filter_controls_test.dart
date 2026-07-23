import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nueva_app/core/theme/app_theme.dart';
import 'package:nueva_app/features/home/home_screen.dart';
import 'package:nueva_app/features/huevos/huevo_models.dart';
import 'package:nueva_app/features/model/grupo/grupo.dart';
import 'package:nueva_app/features/model/tipoAnimal/tipoAnimal.dart';

void main() {
  const animalTypes = [
    TipoAnimal(
      id: 'type-1',
      granjaId: 'farm-1',
      nombre: 'Gallinas',
      createdBy: 'user-1',
    ),
  ];
  const groups = [
    Grupo(
      id: 'group-1',
      granjaId: 'farm-1',
      tipoAnimalId: 'type-1',
      nombre: 'Ponedoras',
    ),
  ];

  testWidgets('places animal-only and egg-only filters on their branches', (
    tester,
  ) async {
    await _pumpControls(
      tester,
      branchIndex: 0,
      animalTypes: animalTypes,
      groups: groups,
    );
    expect(find.byKey(const Key('animal-type-filter')), findsNothing);
    expect(find.byKey(const Key('egg-group-filter')), findsNothing);
    expect(find.byKey(const Key('egg-period-filter')), findsNothing);

    await _pumpControls(
      tester,
      branchIndex: 1,
      animalTypes: animalTypes,
      groups: groups,
    );
    expect(find.byKey(const Key('animal-type-filter')), findsOneWidget);
    expect(find.byKey(const Key('egg-group-filter')), findsNothing);
    expect(find.byKey(const Key('egg-period-filter')), findsNothing);

    await _pumpControls(
      tester,
      branchIndex: 2,
      animalTypes: animalTypes,
      groups: groups,
    );
    expect(find.byKey(const Key('animal-type-filter')), findsOneWidget);
    expect(find.byKey(const Key('egg-group-filter')), findsOneWidget);
    expect(find.byKey(const Key('egg-period-filter')), findsOneWidget);
  });

  testWidgets('compact egg controls do not overflow and open choice sheets', (
    tester,
  ) async {
    await _pumpControls(
      tester,
      branchIndex: 2,
      animalTypes: animalTypes,
      groups: groups,
      width: 240,
      filters: const EggFilters(groupId: 'group-1'),
    );

    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('egg-group-filter')));
    await tester.pumpAndSettle();
    expect(find.text('Filtrar por grupo'), findsOneWidget);
    expect(find.text('Ponedoras'), findsWidgets);

    await tester.tap(find.text('Ponedoras').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('egg-period-filter')));
    await tester.pumpAndSettle();
    expect(find.text('Seleccionar periodo'), findsOneWidget);
    expect(find.text('Mensual'), findsOneWidget);
  });
}

Future<void> _pumpControls(
  WidgetTester tester, {
  required int branchIndex,
  required List<TipoAnimal> animalTypes,
  required List<Grupo> groups,
  double width = 400,
  EggFilters filters = const EggFilters(),
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: HomeFilterControls(
              branchIndex: branchIndex,
              isDark: true,
              compact: width < 560,
              animalTypes: animalTypes,
              groups: groups,
              selectedAnimalTypeId: 'type-1',
              filters: filters,
              onAnimalTypeChanged: (_) {},
              onGroupChanged: (_) {},
              onPeriodChanged: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
}
