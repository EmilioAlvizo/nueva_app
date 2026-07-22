import 'package:flutter/material.dart';

import '../animales/tipo_filtro.dart';
import '../model/grupo/grupo.dart';
import '../model/tipoAnimal/tipoAnimal.dart';
import 'huevo_models.dart';

class EggFilterBar extends StatelessWidget {
  const EggFilterBar({
    super.key,
    required this.animalTypes,
    required this.groups,
    required this.selectedAnimalTypeId,
    required this.filters,
    required this.onAnimalTypeChanged,
    required this.onGroupChanged,
    required this.onPeriodChanged,
  });

  final List<TipoAnimal> animalTypes;
  final List<Grupo> groups;
  final String selectedAnimalTypeId;
  final EggFilters filters;
  final ValueChanged<String> onAnimalTypeChanged;
  final ValueChanged<String?> onGroupChanged;
  final ValueChanged<EggPeriod> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    final filteredGroups = groups
        .where(
          (group) =>
              selectedAnimalTypeId == 'all' ||
              group.tipoAnimalId == selectedAnimalTypeId,
        )
        .toList();
    final selectedType = animalTypes.where(
      (type) => type.id == selectedAnimalTypeId,
    );
    final selectedGroup = filteredGroups.where(
      (group) => group.id == filters.groupId,
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _FilterButton(
            key: const Key('egg-animal-filter'),
            icon: Icons.pets_outlined,
            label: selectedType.isEmpty
                ? 'Todos los tipos'
                : selectedType.first.nombre,
            active: selectedAnimalTypeId != 'all',
            onTap: () => showTipoFiltroPicker(
              context,
              tipos: animalTypes,
              grupos: groups,
              selected: selectedAnimalTypeId,
              onChanged: onAnimalTypeChanged,
            ),
          ),
          const SizedBox(width: 8),
          _FilterButton(
            key: const Key('egg-group-filter'),
            icon: Icons.groups_2_outlined,
            label: selectedGroup.isEmpty
                ? 'Todos los grupos'
                : selectedGroup.first.nombre,
            active: selectedGroup.isNotEmpty,
            onTap: () => _showChoiceSheet<String?>(
              context,
              title: 'Filtrar por grupo',
              selected: selectedGroup.isEmpty ? null : selectedGroup.first.id,
              choices: [
                const (value: null, label: 'Todos los grupos'),
                for (final group in filteredGroups)
                  (value: group.id, label: group.nombre),
              ],
              onChanged: onGroupChanged,
            ),
          ),
          const SizedBox(width: 8),
          _FilterButton(
            key: const Key('egg-period-filter'),
            icon: Icons.calendar_month_outlined,
            label: filters.period.label,
            active: filters.period != EggPeriod.total,
            onTap: () => _showChoiceSheet<EggPeriod>(
              context,
              title: 'Seleccionar periodo',
              selected: filters.period,
              choices: [
                for (final period in EggPeriod.values)
                  (value: period, label: period.label),
              ],
              onChanged: onPeriodChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: active ? colors.primaryContainer : colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            border: Border.all(color: colors.outlineVariant),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 19),
              const SizedBox(width: 8),
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required T selected,
  required List<({T value, String label})> choices,
  required ValueChanged<T> onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          for (final choice in choices)
            ListTile(
              title: Text(choice.label),
              contentPadding: EdgeInsets.zero,
              minTileHeight: 48,
              trailing: choice.value == selected
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: () {
                onChanged(choice.value);
                Navigator.of(sheetContext).pop();
              },
            ),
        ],
      ),
    ),
  );
}
