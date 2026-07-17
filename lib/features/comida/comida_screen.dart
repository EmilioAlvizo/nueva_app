import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import 'comida_models.dart';
import 'comida_provider.dart';
import 'forms/category_form_sheet.dart';
import 'forms/mixture_form_sheet.dart';
import 'widgets/category_card.dart';
import 'widgets/comida_metrics.dart';
import 'widgets/comida_states.dart';
import 'widgets/mixture_card.dart';

enum ComidaTab { mixtures, categories }

class ComidaScreen extends ConsumerStatefulWidget {
  const ComidaScreen({super.key, required this.granjaId});

  final String granjaId;

  @override
  ConsumerState<ComidaScreen> createState() => _ComidaScreenState();
}

class _ComidaScreenState extends ConsumerState<ComidaScreen> {
  late final PageController _pageController;
  ComidaTab _activeTab = ComidaTab.mixtures;

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
    final access = ref.watch(foodAccessProvider(widget.granjaId));
    final mutation = ref.watch(foodMutationsProvider);
    final canEdit = switch (access) {
      AsyncData(:final value) => value.canEdit && !mutation.isLoading,
      _ => false,
    };
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.bg
          : AppColors.bgCard3Lg,
      body: SafeArea(
        child: Column(
          children: [
            _SegmentedTabs(activeTab: _activeTab, onSelected: _selectTab),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) =>
                    setState(() => _activeTab = ComidaTab.values[index]),
                children: [
                  _MixturesTab(
                    farmId: widget.granjaId,
                    canEdit: canEdit,
                    onEdit: _openMixtureForm,
                    onDelete: _confirmMixtureDelete,
                  ),
                  _CategoriesTab(
                    farmId: widget.granjaId,
                    canEdit: canEdit,
                    onEdit: _openCategoryForm,
                    onDelete: _confirmCategoryDelete,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              key: ValueKey('comida-fab-${_activeTab.name}'),
              tooltip: _activeTab == ComidaTab.mixtures
                  ? 'Nueva mezcla'
                  : 'Nueva categoría',
              onPressed: _activeTab == ComidaTab.mixtures
                  ? () => _openMixtureForm(null)
                  : () => _openCategoryForm(null),
              backgroundColor: const Color(0xFFB8E6CF),
              foregroundColor: const Color(0xFF14392A),
              child: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }

  void _selectTab(ComidaTab tab) {
    setState(() => _activeTab = tab);
    _pageController.animateToPage(
      ComidaTab.values.indexOf(tab),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _openCategoryForm(FoodCategory? category) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          CategoryFormSheet(farmId: widget.granjaId, category: category),
    );
  }

  Future<void> _openMixtureForm(FoodMixture? mixture) async {
    late final List<FoodCategory> categoryValues;
    late final List<FoodGroup> groupValues;
    try {
      final values = await (
        ref.read(foodCategoriesProvider(widget.granjaId).future),
        ref.read(foodGroupsProvider(widget.granjaId).future),
      ).wait;
      categoryValues = values.$1;
      groupValues = values.$2;
    } catch (_) {
      if (mounted) {
        _snack('No pudimos cargar categorías y grupos.', isError: true);
      }
      return;
    }
    if (!mounted) return;
    if (categoryValues.isEmpty && mixture == null) {
      _snack(
        'Crea al menos una categoría antes de registrar una mezcla.',
        isError: true,
      );
      return;
    }
    if (groupValues.isEmpty) {
      _snack(
        'Crea al menos un grupo antes de registrar una mezcla.',
        isError: true,
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MixtureFormSheet(
        farmId: widget.granjaId,
        categories: categoryValues,
        groups: groupValues,
        mixture: mixture,
      ),
    );
  }

  Future<void> _confirmMixtureDelete(FoodMixture mixture) async {
    final confirmed = await _confirm(
      title: 'Eliminar mezcla',
      message:
          'Se eliminará la mezcla y únicamente sus compras de ingredientes asociadas.',
    );
    if (!confirmed || !mounted) return;
    try {
      await ref
          .read(foodMutationsProvider.notifier)
          .deleteMixture(farmId: widget.granjaId, mixtureId: mixture.id);
      if (mounted) _snack('Mezcla eliminada.');
    } catch (error) {
      if (mounted) _snack(_errorMessage(error), isError: true);
    }
  }

  Future<void> _confirmCategoryDelete(FoodCategory category) async {
    final confirmed = await _confirm(
      title: 'Eliminar categoría',
      message:
          'Si tiene mezclas históricas se desactivará; de lo contrario se eliminará definitivamente.',
    );
    if (!confirmed || !mounted) return;
    try {
      await ref
          .read(foodMutationsProvider.notifier)
          .deleteCategory(farmId: widget.granjaId, categoryId: category.id);
      if (mounted) _snack('Categoría eliminada.');
    } catch (error) {
      if (mounted) _snack(_errorMessage(error), isError: true);
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.negative,
              ),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      ) ??
      false;

  void _snack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.negative : AppColors.greenDark,
      ),
    );
  }

  static String _errorMessage(Object error) => switch (error) {
    PostgrestException(:final message) => message,
    ArgumentError(:final message) => '$message',
    _ => 'No se pudo completar la operación.',
  };
}

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({required this.activeTab, required this.onSelected});

  final ComidaTab activeTab;
  final ValueChanged<ComidaTab> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
    child: Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          _TabButton(
            label: 'Mezclas',
            selected: activeTab == ComidaTab.mixtures,
            onTap: () => onSelected(ComidaTab.mixtures),
          ),
          _TabButton(
            label: 'Categorías',
            selected: activeTab == ComidaTab.categories,
            onTap: () => onSelected(ComidaTab.categories),
          ),
        ],
      ),
    ),
  );
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        key: ValueKey('food-tab-$label'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minHeight: 46),
          decoration: BoxDecoration(
            color: selected ? AppColors.naranjao : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (selected) ...[
                const Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: AppColors.textPrimaryLg,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? AppColors.textPrimaryLg
                      : AppColors.textSecondary,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _MixturesTab extends ConsumerWidget {
  const _MixturesTab({
    required this.farmId,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });

  final String farmId;
  final bool canEdit;
  final ValueChanged<FoodMixture> onEdit;
  final ValueChanged<FoodMixture> onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mixtures = ref.watch(foodMixturesProvider(farmId));
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(foodMixturesProvider(farmId));
        await ref.read(foodMixturesProvider(farmId).future);
      },
      child: CustomScrollView(
        key: const PageStorageKey('food-mixtures'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            sliver: SliverToBoxAdapter(
              child: switch (mixtures) {
                AsyncData(:final value) => ComidaMetrics(
                  stats: FoodStats.forMixtures(value),
                  countLabel: 'Mezclas',
                ),
                _ => const ComidaMetricsLoading(),
              },
            ),
          ),
          switch (mixtures) {
            AsyncLoading() => const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            ),
            AsyncError() => SliverFillRemaining(
              hasScrollBody: false,
              child: ComidaErrorState(
                onRetry: () => ref.invalidate(foodMixturesProvider(farmId)),
              ),
            ),
            AsyncData(:final value) when value.isEmpty =>
              const SliverFillRemaining(
                hasScrollBody: false,
                child: ComidaEmptyState(
                  icon: Icons.blender_outlined,
                  title: 'Aún no hay mezclas',
                  message:
                      'Usa el botón + para registrar la primera mezcla de alimento.',
                ),
              ),
            AsyncData(:final value) => SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 112),
              sliver: SliverList.separated(
                itemCount: value.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final mixture = value[index];
                  return MixtureCard(
                    mixture: mixture,
                    canEdit: canEdit,
                    onEdit: () => onEdit(mixture),
                    onDelete: () => onDelete(mixture),
                  );
                },
              ),
            ),
          },
        ],
      ),
    );
  }
}

class _CategoriesTab extends ConsumerWidget {
  const _CategoriesTab({
    required this.farmId,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });

  final String farmId;
  final bool canEdit;
  final ValueChanged<FoodCategory> onEdit;
  final ValueChanged<FoodCategory> onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(foodCategoriesProvider(farmId));
    final mixtures = ref.watch(foodMixturesProvider(farmId));
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(foodCategoriesProvider(farmId));
        ref.invalidate(foodMixturesProvider(farmId));
        await Future.wait([
          ref.read(foodCategoriesProvider(farmId).future),
          ref.read(foodMixturesProvider(farmId).future),
        ]);
      },
      child: CustomScrollView(
        key: const PageStorageKey('food-categories'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            sliver: SliverToBoxAdapter(
              child: switch ((mixtures, categories)) {
                (
                  AsyncData(value: final mixtureValues),
                  AsyncData(value: final categoryValues),
                ) =>
                  ComidaMetrics(
                    stats: FoodStats.forCategories(
                      mixtures: mixtureValues,
                      categories: categoryValues,
                    ),
                    countLabel: 'Categorías',
                  ),
                _ => const ComidaMetricsLoading(),
              },
            ),
          ),
          switch (categories) {
            AsyncLoading() => const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            ),
            AsyncError() => SliverFillRemaining(
              hasScrollBody: false,
              child: ComidaErrorState(
                onRetry: () => ref.invalidate(foodCategoriesProvider(farmId)),
              ),
            ),
            AsyncData(:final value) when value.isEmpty =>
              const SliverFillRemaining(
                hasScrollBody: false,
                child: ComidaEmptyState(
                  icon: Icons.sell_outlined,
                  title: 'Aún no hay categorías',
                  message:
                      'Crea categorías para poder armar mezclas de alimento.',
                ),
              ),
            AsyncData(:final value) => SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 112),
              sliver: SliverList.separated(
                itemCount: value.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final category = value[index];
                  return CategoryCard(
                    category: category,
                    canEdit: canEdit,
                    onEdit: () => onEdit(category),
                    onDelete: () => onDelete(category),
                  );
                },
              ),
            ),
          },
        ],
      ),
    );
  }
}
