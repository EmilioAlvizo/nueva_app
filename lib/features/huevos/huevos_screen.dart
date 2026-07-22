import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../animales/animales_provider.dart';
import '../animales/tipo_filtro.dart';
import '../model/grupo/grupo.dart';
import '../model/tipoAnimal/tipoAnimal.dart';
import 'huevo_cards.dart';
import 'huevo_filters.dart';
import 'huevo_forms.dart';
import 'huevo_models.dart';
import 'huevo_provider.dart';
import 'huevo_summary.dart';

enum EggTab { summary, add, reduce }

class HuevosScreen extends ConsumerStatefulWidget {
  const HuevosScreen({super.key, required this.granjaId});

  final String granjaId;

  @override
  ConsumerState<HuevosScreen> createState() => _HuevosScreenState();
}

class _HuevosScreenState extends ConsumerState<HuevosScreen> {
  EggTab _tab = EggTab.summary;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(huevoDataProvider(widget.granjaId));
    final access = ref.watch(huevoAccessProvider(widget.granjaId));
    final mutation = ref.watch(huevoMutationsProvider);
    final filters = ref.watch(huevoFiltersProvider(widget.granjaId));
    final animalTypeId = ref.watch(tipoFiltroProvider);
    final animalTypes =
        ref.watch(tiposAnimalProvider(widget.granjaId)).value ?? [];
    final groups = ref.watch(gruposProvider(widget.granjaId)).value ?? [];
    final canEdit = switch (access) {
      AsyncData(:final value) => value.canEdit && !mutation.isLoading,
      _ => false,
    };
    final groupChoices = _groupChoices(
      groups: groups,
      animalTypes: animalTypes,
      animalTypeId: animalTypeId,
    );
    final selectedGroupIsValid =
        filters.groupId == null ||
        groupChoices.any((group) => group.id == filters.groupId);
    final effectiveFilters = selectedGroupIsValid
        ? filters
        : filters.copyWith(clearGroup: true);

    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: _SegmentedTabs(
                    selected: _tab,
                    onSelected: (tab) => setState(() => _tab = tab),
                  ),
                ),
                EggFilterBar(
                  animalTypes: animalTypes,
                  groups: groups,
                  selectedAnimalTypeId: animalTypeId,
                  filters: effectiveFilters,
                  onAnimalTypeChanged: (value) {
                    ref.read(tipoFiltroProvider.notifier).set(value);
                    final selectedGroup = groups.where(
                      (group) => group.id == filters.groupId,
                    );
                    if (selectedGroup.isNotEmpty &&
                        value != 'all' &&
                        selectedGroup.first.tipoAnimalId != value) {
                      ref
                          .read(huevoFiltersProvider(widget.granjaId).notifier)
                          .setGroup(null);
                    }
                  },
                  onGroupChanged: (value) => ref
                      .read(huevoFiltersProvider(widget.granjaId).notifier)
                      .setGroup(value),
                  onPeriodChanged: (value) => ref
                      .read(huevoFiltersProvider(widget.granjaId).notifier)
                      .setPeriod(value),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: data.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => _ErrorState(
                      onRetry: () =>
                          ref.invalidate(huevoDataProvider(widget.granjaId)),
                    ),
                    data: (value) {
                      final filtered = value.filtered(
                        animalTypeId: animalTypeId,
                        filters: effectiveFilters,
                        now: DateTime.now(),
                      );
                      return switch (_tab) {
                        EggTab.summary => EggSummaryView(
                          summary: EggSummary.fromData(filtered),
                        ),
                        EggTab.add => _CollectionsList(
                          collections: filtered.collections,
                          canEdit: canEdit,
                          onEdit: (collection) => _openCollectionForm(
                            groupChoices,
                            collection: collection,
                          ),
                          onDelete: _deleteCollection,
                        ),
                        EggTab.reduce => _SalesList(
                          sales: filtered.sales,
                          canEdit: canEdit,
                          onEdit: (sale) =>
                              _openSaleForm(groupChoices, sale: sale),
                          onDelete: _deleteSale,
                        ),
                      };
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: canEdit && _tab != EggTab.summary
          ? FloatingActionButton.extended(
              key: ValueKey('egg-fab-${_tab.name}'),
              tooltip: _tab == EggTab.add ? 'Nueva recolección' : 'Nueva venta',
              onPressed: _tab == EggTab.add
                  ? () => _openCollectionForm(groupChoices)
                  : () => _openSaleForm(groupChoices),
              icon: const Icon(Icons.add_rounded),
              label: Text(_tab == EggTab.add ? 'Recolectar' : 'Vender'),
            )
          : null,
    );
  }

  Future<void> _openCollectionForm(
    List<EggGroupChoice> groups, {
    EggCollection? collection,
  }) {
    final filters = ref.read(huevoFiltersProvider(widget.granjaId));
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EggCollectionForm(
        farmId: widget.granjaId,
        groups: groups,
        collection: collection,
        initialGroupId: collection == null ? filters.groupId : null,
        onSave: (input) {
          if (collection == null) {
            return ref
                .read(huevoMutationsProvider.notifier)
                .createCollection(input);
          }
          return ref
              .read(huevoMutationsProvider.notifier)
              .updateCollection(collectionId: collection.id, input: input);
        },
      ),
    );
  }

  Future<void> _openSaleForm(List<EggGroupChoice> groups, {EggSale? sale}) {
    final filters = ref.read(huevoFiltersProvider(widget.granjaId));
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EggSaleForm(
        farmId: widget.granjaId,
        groups: groups,
        sale: sale,
        initialGroupId: sale == null ? filters.groupId : null,
        onSave: (input) {
          if (sale == null) {
            return ref.read(huevoMutationsProvider.notifier).createSale(input);
          }
          return ref
              .read(huevoMutationsProvider.notifier)
              .updateSale(saleId: sale.id, input: input);
        },
      ),
    );
  }

  Future<void> _deleteCollection(EggCollection collection) async {
    final confirmed = await _confirmDelete(
      title: 'Eliminar recolección',
      message: 'Esta acción eliminará la recolección de forma permanente.',
    );
    if (!confirmed || !mounted) return;
    try {
      await ref
          .read(huevoMutationsProvider.notifier)
          .deleteCollection(
            farmId: widget.granjaId,
            collectionId: collection.id,
          );
    } catch (_) {
      if (!mounted) return;
      _showError('No se pudo eliminar la recolección.');
    }
  }

  Future<void> _deleteSale(EggSale sale) async {
    final confirmed = await _confirmDelete(
      title: 'Eliminar venta',
      message: 'Esta acción eliminará la venta de forma permanente.',
    );
    if (!confirmed || !mounted) return;
    try {
      await ref
          .read(huevoMutationsProvider.notifier)
          .deleteSale(farmId: widget.granjaId, saleId: sale.id);
    } catch (_) {
      if (!mounted) return;
      _showError('No se pudo eliminar la venta.');
    }
  }

  Future<bool> _confirmDelete({
    required String title,
    required String message,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({required this.selected, required this.onSelected});

  final EggTab selected;
  final ValueChanged<EggTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<EggTab>(
        key: const Key('egg-segmented-tabs'),
        segments: const [
          ButtonSegment(value: EggTab.summary, label: Text('Resumen')),
          ButtonSegment(value: EggTab.add, label: Text('Agregar')),
          ButtonSegment(value: EggTab.reduce, label: Text('Reducir')),
        ],
        selected: {selected},
        showSelectedIcon: false,
        onSelectionChanged: (selection) => onSelected(selection.first),
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? const Color(0xFFF59E0B)
                : colors.surfaceContainerHigh;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? const Color(0xFF2A1700)
                : colors.onSurfaceVariant;
          }),
        ),
      ),
    );
  }
}

class _CollectionsList extends StatelessWidget {
  const _CollectionsList({
    required this.collections,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });

  final List<EggCollection> collections;
  final bool canEdit;
  final ValueChanged<EggCollection> onEdit;
  final ValueChanged<EggCollection> onDelete;

  @override
  Widget build(BuildContext context) {
    if (collections.isEmpty) {
      return const _EmptyState(
        icon: Icons.egg_outlined,
        title: 'Sin recolecciones',
        message: 'No hay recolecciones para los filtros seleccionados.',
      );
    }
    return ListView.separated(
      key: const Key('egg-collections-list'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 112),
      itemCount: collections.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final collection = collections[index];
        return EggCollectionCard(
          collection: collection,
          canEdit: canEdit,
          onEdit: () => onEdit(collection),
          onDelete: () => onDelete(collection),
        );
      },
    );
  }
}

class _SalesList extends StatelessWidget {
  const _SalesList({
    required this.sales,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });

  final List<EggSale> sales;
  final bool canEdit;
  final ValueChanged<EggSale> onEdit;
  final ValueChanged<EggSale> onDelete;

  @override
  Widget build(BuildContext context) {
    if (sales.isEmpty) {
      return const _EmptyState(
        icon: Icons.point_of_sale_outlined,
        title: 'Sin ventas',
        message: 'No hay ventas para los filtros seleccionados.',
      );
    }
    return ListView.separated(
      key: const Key('egg-sales-list'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 112),
      itemCount: sales.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final sale = sales[index];
        return EggSaleCard(
          sale: sale,
          canEdit: canEdit,
          onEdit: () => onEdit(sale),
          onDelete: () => onDelete(sale),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: colors.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            const Text('No se pudieron cargar los registros de huevos.'),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

List<EggGroupChoice> _groupChoices({
  required List<Grupo> groups,
  required List<TipoAnimal> animalTypes,
  required String animalTypeId,
}) {
  return [
    for (final group in groups)
      if (animalTypeId == 'all' || group.tipoAnimalId == animalTypeId)
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
