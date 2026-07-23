import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nueva_app/core/theme/app_colors.dart';
import 'package:nueva_app/features/animales/tipo_filtro.dart';
import 'package:nueva_app/features/huevos/huevo_filters.dart';
import 'package:nueva_app/features/huevos/huevo_models.dart';
import 'package:nueva_app/features/huevos/huevo_provider.dart';
import 'package:nueva_app/features/model/grupo/grupo.dart';
import 'package:nueva_app/features/model/tipoAnimal/tipoAnimal.dart';

void main() {
  const types = [
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
  const groups = [
    Grupo(
      id: 'group-1',
      granjaId: 'farm-1',
      tipoAnimalId: 'type-1',
      nombre: 'Ponedoras',
    ),
    Grupo(
      id: 'group-2',
      granjaId: 'farm-1',
      tipoAnimalId: 'type-2',
      nombre: 'Codornices A',
    ),
  ];

  test('animal type colors are ID-based with canonical fallback', () {
    expect(colorParaTipoAnimal('type-2', types), AppColors.tipoColor[1]);
    expect(colorParaTipoAnimal('missing', types), AppColors.tipoColor.first);
    expect(colorParaTipoAnimal('', types), AppColors.tipoColor.first);
  });

  test('group helpers constrain and resolve groups against animal type', () {
    expect(eggGroupsForType(groups: groups, animalTypeId: 'type-1'), [
      groups.first,
    ]);
    expect(
      resolveEggGroupForType(
        selectedGroupId: 'group-1',
        groups: groups,
        animalTypeId: 'type-2',
      ),
      isNull,
    );
    expect(
      resolveEggGroupForType(
        selectedGroupId: 'group-1',
        groups: groups,
        animalTypeId: 'all',
      ),
      'group-1',
    );
  });

  test('builds display choices and resolves only listed identifiers', () {
    final choices = buildEggGroupChoices(
      groups: groups,
      animalTypes: types,
      animalTypeId: 'type-2',
    );

    expect(choices.single.id, 'group-2');
    expect(choices.single.displayName, 'Codornices A · Codornices');
    expect(resolveValidEggGroupId('group-2', choices), 'group-2');
    expect(resolveValidEggGroupId('group-1', choices), isNull);
  });

  test('animal type is shared while egg filters are farm-scoped', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final farmA = container.listen(huevoFiltersProvider('farm-a'), (_, _) {});
    final farmB = container.listen(huevoFiltersProvider('farm-b'), (_, _) {});
    addTearDown(farmA.close);
    addTearDown(farmB.close);

    container.read(tipoFiltroProvider.notifier).set('type-1');
    container.read(huevoFiltersProvider('farm-a').notifier).setGroup('group-1');
    container
        .read(huevoFiltersProvider('farm-a').notifier)
        .setPeriod(EggPeriod.total);

    expect(container.read(tipoFiltroProvider), 'type-1');
    expect(
      container.read(huevoFiltersProvider('farm-a')),
      const EggFilters(groupId: 'group-1', period: EggPeriod.total),
    );
    expect(container.read(huevoFiltersProvider('farm-b')), const EggFilters());
  });
}
