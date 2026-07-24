import 'package:flutter/material.dart';

import '../animales/tipo_filtro.dart';
import '../model/grupo/grupo.dart';
import '../model/tipoAnimal/tipoAnimal.dart';
import 'huevo_models.dart';

List<Grupo> eggGroupsForType({
  required List<Grupo> groups,
  required String animalTypeId,
}) {
  return [
    for (final group in groups)
      if (animalTypeId == 'all' || group.tipoAnimalId == animalTypeId) group,
  ];
}

String? resolveEggGroupForType({
  required String? selectedGroupId,
  required List<Grupo> groups,
  required String animalTypeId,
}) {
  if (selectedGroupId == null) return null;
  return groups.any(
        (group) =>
            group.id == selectedGroupId &&
            (animalTypeId == 'all' || group.tipoAnimalId == animalTypeId),
      )
      ? selectedGroupId
      : null;
}

List<EggGroupChoice> buildEggGroupChoices({
  required List<Grupo> groups,
  required List<TipoAnimal> animalTypes,
  required String animalTypeId,
}) {
  final filteredGroups = eggGroupsForType(
    groups: groups,
    animalTypeId: animalTypeId,
  );
  return [
    for (final group in filteredGroups)
      EggGroupChoice(
        id: group.id,
        name: group.nombre,
        animalTypeId: group.tipoAnimalId,
        animalTypeName:
            animalTypes
                .where((type) => type.id == group.tipoAnimalId)
                .map((type) => type.nombre)
                .firstOrNull ??
            'Tipo desconocido',
      ),
  ];
}

String? resolveValidEggGroupId(
  String? selectedGroupId,
  List<EggGroupChoice> groups,
) {
  if (selectedGroupId == null) return null;
  return groups.any((group) => group.id == selectedGroupId)
      ? selectedGroupId
      : null;
}

class EggGroupFilterBadgeButton extends StatelessWidget {
  const EggGroupFilterBadgeButton({
    super.key,
    required this.isDark,
    required this.groups,
    required this.selectedGroupId,
    required this.onChanged,
    this.compact = false,
  });

  final bool isDark;
  final List<Grupo> groups;
  final String? selectedGroupId;
  final ValueChanged<String?> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final selected = groups.where((group) => group.id == selectedGroupId);
    return FilterBadgeButton(
      key: const Key('egg-group-filter'),
      isDark: isDark,
      icon: Icons.groups_2_outlined,
      label: selected.isEmpty ? 'Todos los grupos' : selected.first.nombre,
      tooltip: 'Filtrar por grupo',
      active: selected.isNotEmpty,
      compact: compact,
      onTap: () => showEggChoiceSheet<String?>(
        context,
        title: 'Filtrar por grupo',
        subtitle: 'Muestra únicamente los registros del grupo seleccionado.',
        selected: selected.isEmpty ? null : selected.first.id,
        choices: [
          const (value: null, label: 'Todos los grupos'),
          for (final group in groups) (value: group.id, label: group.nombre),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class EggPeriodFilterBadgeButton extends StatelessWidget {
  const EggPeriodFilterBadgeButton({
    super.key,
    required this.isDark,
    required this.period,
    required this.onChanged,
    this.compact = false,
  });

  final bool isDark;
  final EggPeriod period;
  final ValueChanged<EggPeriod> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return FilterBadgeButton(
      key: const Key('egg-period-filter'),
      isDark: isDark,
      icon: Icons.calendar_month_outlined,
      label: period.label,
      tooltip: 'Filtrar por periodo',
      active: period != EggPeriod.total,
      compact: compact,
      onTap: () => showEggChoiceSheet<EggPeriod>(
        context,
        title: 'Seleccionar periodo',
        subtitle: 'El periodo se aplica a recolecciones y ventas.',
        selected: period,
        choices: [
          for (final value in EggPeriod.values)
            (value: value, label: value.label),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class EggFilterSummary extends StatelessWidget {
  const EggFilterSummary({
    super.key,
    required this.animalTypes,
    required this.groups,
    required this.selectedAnimalTypeId,
    required this.filters,
  });

  final List<TipoAnimal> animalTypes;
  final List<Grupo> groups;
  final String selectedAnimalTypeId;
  final EggFilters filters;

  @override
  Widget build(BuildContext context) {
    final selectedType = animalTypes.where(
      (type) => type.id == selectedAnimalTypeId,
    );
    final selectedGroup = groups.where((group) => group.id == filters.groupId);
    final summary = [
      selectedType.isEmpty ? 'Todos los tipos' : selectedType.first.nombre,
      selectedGroup.isEmpty ? 'Todos los grupos' : selectedGroup.first.nombre,
      filters.period.label,
    ].join(' · ');
    final colors = Theme.of(context).colorScheme;
    return Padding(
      key: const Key('egg-filter-summary'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          Text('Filtros', style: TextStyle(fontSize: 11, height: 1.4)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              summary,
              key: const Key('egg-filter-summary-value'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 11, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showEggChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required String subtitle,
  required T selected,
  required List<({T value, String label})> choices,
  required ValueChanged<T> onChanged,
}) {
  final colors = Theme.of(context).colorScheme;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: colors.surface,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.onSurface.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            for (final choice in choices)
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  onChanged(choice.value);
                  Navigator.of(sheetContext).pop();
                },
                child: Container(
                  constraints: const BoxConstraints(minHeight: 52),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: choice.value == selected
                        ? colors.onSurface.withValues(alpha: 0.06)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: choice.value == selected
                          ? colors.outline
                          : colors.outlineVariant,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          choice.label,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (choice.value == selected)
                        Icon(Icons.check_rounded, color: colors.primary),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
