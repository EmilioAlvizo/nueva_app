import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/testing/app_widget_keys.dart';
import '../../core/theme/app_colors.dart';
import '../animales/animales_provider.dart';
import '../animales/tipo_filtro.dart';
import '../model/tipoAnimal/tipoAnimal.dart';
import 'huevo_cards.dart';
import 'huevo_filters.dart';
import 'huevo_forms.dart';
import 'huevo_models.dart';
import 'huevo_pie_chart.dart';
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
  late final PageController _pageController;
  EggTab _tab = EggTab.summary;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(huevoDataProvider(widget.granjaId));
    final access = ref.watch(huevoAccessProvider(widget.granjaId));
    final mutation = ref.watch(huevoMutationsProvider);
    final filters = ref.watch(huevoFiltersProvider(widget.granjaId));
    final animalTypeId = ref.watch(tipoFiltroProvider);
    final animalTypesAsync = ref.watch(tiposAnimalProvider(widget.granjaId));
    final groupsAsync = ref.watch(gruposProvider(widget.granjaId));
    final animalTypes = animalTypesAsync.value ?? [];
    final groups = groupsAsync.value ?? [];
    final animalTypeIsValid =
        animalTypeId == 'all' ||
        animalTypes.any((type) => type.id == animalTypeId);
    final effectiveAnimalTypeId = animalTypeIsValid ? animalTypeId : 'all';
    final canEdit = switch (access) {
      AsyncData(:final value) => value.canEdit && !mutation.isLoading,
      _ => false,
    };
    final groupChoices = buildEggGroupChoices(
      groups: groups,
      animalTypes: animalTypes,
      animalTypeId: effectiveAnimalTypeId,
    );
    final resolvedGroupId = resolveValidEggGroupId(
      filters.groupId,
      groupChoices,
    );
    final selectedGroupIsValid = filters.groupId == resolvedGroupId;
    final effectiveFilters = selectedGroupIsValid
        ? filters
        : filters.copyWith(clearGroup: true);

    if (animalTypesAsync.hasValue && !animalTypeIsValid ||
        groupsAsync.hasValue && !selectedGroupIsValid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!animalTypeIsValid && ref.read(tipoFiltroProvider) != 'all') {
          ref.read(tipoFiltroProvider.notifier).clear();
        }
        final current = ref.read(huevoFiltersProvider(widget.granjaId));
        if (!selectedGroupIsValid && current.groupId != null) {
          ref
              .read(huevoFiltersProvider(widget.granjaId).notifier)
              .setGroup(null);
        }
      });
    }

    late final List<Widget> pages;
    switch (data) {
      case AsyncLoading():
        pages = const [
          Center(child: CircularProgressIndicator()),
          Center(child: CircularProgressIndicator()),
          Center(child: CircularProgressIndicator()),
        ];
      case AsyncError():
        pages = [
          _ErrorState(
            onRetry: () => ref.invalidate(huevoDataProvider(widget.granjaId)),
          ),
          _ErrorState(
            onRetry: () => ref.invalidate(huevoDataProvider(widget.granjaId)),
          ),
          _ErrorState(
            onRetry: () => ref.invalidate(huevoDataProvider(widget.granjaId)),
          ),
        ];
      case AsyncData(:final value):
        final filtered = value.filtered(
          animalTypeId: effectiveAnimalTypeId,
          filters: effectiveFilters,
          now: DateTime.now(),
        );
        pages = [
          EggSummaryView(summary: EggSummary.fromData(filtered)),
          _CollectionsList(
            collections: filtered.collections,
            animalTypes: animalTypes,
            canEdit: canEdit,
            onEdit: (collection) =>
                _openCollectionForm(groupChoices, collection: collection),
            onDelete: _deleteCollection,
          ),
          _SalesList(
            sales: filtered.sales,
            animalTypes: animalTypes,
            canEdit: canEdit,
            onEdit: (sale) => _openSaleForm(groupChoices, sale: sale),
            onDelete: _deleteSale,
          ),
        ];
    }

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final fabRight = constraints.maxWidth > 920
                ? (constraints.maxWidth - 920) / 2 + 16
                : 16.0;
            return Stack(
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 920),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                          child: _SegmentedTabs(
                            selected: _tab,
                            onSelected: _selectTab,
                          ),
                        ),
                        EggFilterSummary(
                          animalTypes: animalTypes,
                          groups: groups,
                          selectedAnimalTypeId: effectiveAnimalTypeId,
                          filters: effectiveFilters,
                        ),
                        Expanded(
                          child: PageView(
                            key: const ValueKey(AppWidgetKeys.eggPages),
                            controller: _pageController,
                            onPageChanged: _onPageChanged,
                            children: pages,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (canEdit && _tab != EggTab.summary)
                  Positioned(
                    right: fabRight,
                    bottom: 16,
                    child: FloatingActionButton.extended(
                      key: ValueKey('egg-fab-${_tab.name}'),
                      tooltip: _tab == EggTab.add
                          ? 'Nueva recolección'
                          : 'Nueva venta',
                      backgroundColor: eggConsumptionColor,
                      foregroundColor: Colors.white,
                      onPressed: _tab == EggTab.add
                          ? () => _openCollectionForm(groupChoices)
                          : () => _openSaleForm(groupChoices),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(_tab == EggTab.add ? 'Recolectar' : 'Vender'),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _selectTab(EggTab tab) {
    if (_pageController.hasClients) {
      unawaited(
        _pageController.animateToPage(
          tab.index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        ),
      );
      return;
    }

    if (_tab == tab) return;
    setState(() => _tab = tab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients || _tab != tab) return;
      _pageController.jumpToPage(tab.index);
    });
  }

  void _onPageChanged(int index) {
    final tab = EggTab.values[index];
    if (_tab == tab) return;
    setState(() => _tab = tab);
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
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (_) => EggCollectionForm(
        farmId: widget.granjaId,
        groups: groups,
        collection: collection,
        initialGroupId: collection == null
            ? resolveValidEggGroupId(filters.groupId, groups)
            : null,
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
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (_) => EggSaleForm(
        farmId: widget.granjaId,
        groups: groups,
        sale: sale,
        initialGroupId: sale == null
            ? resolveValidEggGroupId(filters.groupId, groups)
            : null,
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
    return Row(
      key: const Key('egg-segmented-tabs'),
      children: [
        for (final tab in EggTab.values) ...[
          if (tab != EggTab.summary) const SizedBox(width: 7),
          Expanded(
            child: Semantics(
              selected: selected == tab,
              button: true,
              child: InkWell(
                key: ValueKey('egg-tab-${tab.name}'),
                onTap: () => onSelected(tab),
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  height: 48,
                  decoration: BoxDecoration(
                    color: selected == tab
                        ? AppColors.naranjao
                        : colors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (selected == tab) ...[
                        const Icon(
                          Icons.check_rounded,
                          key: Key('egg-selected-tab-check'),
                          size: 17,
                          color: Color(0xFF2A1700),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          switch (tab) {
                            EggTab.summary => 'Resumen',
                            EggTab.add => 'Agregar',
                            EggTab.reduce => 'Reducir',
                          },
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: selected == tab
                                    ? const Color(0xFF2A1700)
                                    : colors.onSurfaceVariant,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CollectionsList extends StatelessWidget {
  const _CollectionsList({
    required this.collections,
    required this.animalTypes,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });

  final List<EggCollection> collections;
  final List<TipoAnimal> animalTypes;
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
          stripeColor: colorParaTipoAnimal(
            collection.animalTypeId,
            animalTypes,
          ),
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
    required this.animalTypes,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });

  final List<EggSale> sales;
  final List<TipoAnimal> animalTypes;
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
          stripeColor: colorParaTipoAnimal(sale.animalTypeId, animalTypes),
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
