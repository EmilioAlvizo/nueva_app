import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/localization_extension.dart';
import '../../../../core/testing/app_widget_keys.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../animales/animales_provider.dart';
import '../../../comida/comida_provider.dart';
import '../../domain/economics_v2_models.dart';
import '../providers/cycle_providers.dart';
import '../widgets/economics_v2_lifecycle_panel.dart';

class CyclesListScreen extends ConsumerStatefulWidget {
  const CyclesListScreen({super.key, required this.farmId});

  final String farmId;

  @override
  ConsumerState<CyclesListScreen> createState() => _CyclesListScreenState();
}

class _CyclesListScreenState extends ConsumerState<CyclesListScreen> {
  var _selectedPurpose = EconomicsV2Purpose.postura;
  String? _loadedCycleId;

  @override
  Widget build(BuildContext context) {
    final cycles = ref.watch(economicsV2CyclesProvider(widget.farmId));
    final result = ref.watch(economicsV2MutationsProvider);
    final purposes = ref.watch(propositosProvider(widget.farmId));
    final animals = ref.watch(animalesProvider(widget.farmId));
    final mixtures = ref.watch(foodMixturesProvider(widget.farmId));

    return Scaffold(
      appBar: AppBar(title: const Text('Cycles')),
      body: cycles.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _LoadError(
          message: '$error',
          onRetry: () =>
              ref.invalidate(economicsV2CyclesProvider(widget.farmId)),
        ),
        data: (items) {
          if (items.isNotEmpty) _loadCalculation(items.first);
          return _CyclesBody(
            lifecyclePanel: EconomicsV2LifecyclePanel(
              farmId: widget.farmId,
              purposes: _valuesOrEmpty(purposes),
              animals: _valuesOrEmpty(animals),
              mixtures: _valuesOrEmpty(mixtures),
              onCreate: (request) => ref
                  .read(economicsV2LifecycleMutationsProvider.notifier)
                  .create(request),
              onAssignAnimal: (request) => ref
                  .read(economicsV2LifecycleMutationsProvider.notifier)
                  .assignAnimal(request),
              onRecordExpense: (request) => ref
                  .read(economicsV2LifecycleMutationsProvider.notifier)
                  .recordExpense(request),
              onLinkFeed: (request) => ref
                  .read(economicsV2LifecycleMutationsProvider.notifier)
                  .linkFeed(request),
            ),
            items: items,
            selectedPurpose: _selectedPurpose,
            result: result,
            onSelected: (purpose) {
              final cycle = items.first;
              setState(() => _selectedPurpose = purpose);
              unawaited(_calculate(cycle.id));
            },
            onRefresh: () async {
              ref.invalidate(economicsV2CyclesProvider(widget.farmId));
              await ref.read(economicsV2CyclesProvider(widget.farmId).future);
              if (items.isNotEmpty) await _calculate(items.first.id);
            },
          );
        },
      ),
    );
  }

  void _loadCalculation(EconomicsV2Cycle cycle) {
    if (_loadedCycleId == cycle.id) return;
    _loadedCycleId = cycle.id;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_calculate(cycle.id)),
    );
  }

  Future<void> _calculate(String cycleId) async {
    await ref
        .read(economicsV2MutationsProvider.notifier)
        .calculate(farmId: widget.farmId, cycleId: cycleId);
  }
}

List<T> _valuesOrEmpty<T>(AsyncValue<List<T>> value) => switch (value) {
  AsyncData(:final value) => value,
  _ => const [],
};

class _CyclesBody extends StatelessWidget {
  const _CyclesBody({
    required this.lifecyclePanel,
    required this.items,
    required this.selectedPurpose,
    required this.result,
    required this.onSelected,
    required this.onRefresh,
  });

  final Widget lifecyclePanel;
  final List<EconomicsV2Cycle> items;
  final EconomicsV2Purpose selectedPurpose;
  final AsyncValue<EconomicsV2Result?> result;
  final ValueChanged<EconomicsV2Purpose> onSelected;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    child: ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.isEmpty ? 2 : items.length + 2,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => switch (index) {
        0 when items.isEmpty => lifecyclePanel,
        0 => EconomicsV2PurposePanel(
          selected: selectedPurpose,
          result: result,
          onSelected: onSelected,
        ),
        1 when items.isEmpty => const _EmptyCycles(),
        1 => lifecyclePanel,
        _ => _EconomicsV2CycleCard(cycle: items[index - 2]),
      },
    ),
  );
}

class EconomicsV2PurposePanel extends StatelessWidget {
  const EconomicsV2PurposePanel({
    required this.selected,
    required this.result,
    required this.onSelected,
    super.key,
  });

  final EconomicsV2Purpose selected;
  final AsyncValue<EconomicsV2Result?> result;
  final ValueChanged<EconomicsV2Purpose> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: [
                for (final purpose in EconomicsV2Purpose.values)
                  Semantics(
                    key: ValueKey(purpose.widgetKey),
                    label: purpose.selectionLabel(l10n),
                    selected: selected == purpose,
                    child: ChoiceChip(
                      label: Text(purpose.label(l10n)),
                      selected: selected == purpose,
                      onSelected: (_) => onSelected(purpose),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(l10n.economicsV2AttributableCost),
            Text(l10n.economicsV2CanonicalRevenue),
            Text(l10n.economicsV2BreakEven),
            Text(selected.basisLabel(l10n)),
            _EconomicsV2ResultView(result: result),
          ],
        ),
      ),
    );
  }
}

class _EconomicsV2ResultView extends StatelessWidget {
  const _EconomicsV2ResultView({required this.result});

  final AsyncValue<EconomicsV2Result?> result;

  @override
  Widget build(BuildContext context) => switch (result) {
    AsyncLoading() => const Padding(
      padding: EdgeInsets.only(top: 12),
      child: Center(child: CircularProgressIndicator()),
    ),
    AsyncError(:final error) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text('$error'),
    ),
    AsyncData(value: final EconomicsV2Calculation calculation) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(calculation.totalCost.toStringAsFixed(2)),
        Text(calculation.revenue.toStringAsFixed(2)),
        Text(calculation.margin.toStringAsFixed(2)),
        Text(calculation.breakEven?.toStringAsFixed(2) ?? '—'),
      ],
    ),
    AsyncData(value: final EconomicsV2Projection projection) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(projection.projectedTotalCost.toStringAsFixed(2)),
        Text(projection.projectedRevenue.toStringAsFixed(2)),
        Text(projection.projectedMargin.toStringAsFixed(2)),
      ],
    ),
    AsyncData() => const SizedBox.shrink(),
  };
}

extension EconomicsV2PurposePresentation on EconomicsV2Purpose {
  String get widgetKey => switch (this) {
    EconomicsV2Purpose.postura => AppWidgetKeys.economicsV2PurposePostura,
    EconomicsV2Purpose.carne => AppWidgetKeys.economicsV2PurposeCarne,
    EconomicsV2Purpose.ornamental => AppWidgetKeys.economicsV2PurposeOrnamental,
  };

  String label(AppLocalizations l10n) => switch (this) {
    EconomicsV2Purpose.postura => l10n.economicsV2PurposePostura,
    EconomicsV2Purpose.carne => l10n.economicsV2PurposeCarne,
    EconomicsV2Purpose.ornamental => l10n.economicsV2PurposeOrnamental,
  };

  String basisLabel(AppLocalizations l10n) => switch (this) {
    EconomicsV2Purpose.postura => l10n.economicsV2BasisEggs,
    EconomicsV2Purpose.carne => l10n.economicsV2BasisAnimalsSold,
    EconomicsV2Purpose.ornamental => l10n.economicsV2BasisSpecimensSold,
  };

  String selectionLabel(AppLocalizations l10n) => switch (this) {
    EconomicsV2Purpose.postura => l10n.economicsV2SelectPurposePostura,
    EconomicsV2Purpose.carne => l10n.economicsV2SelectPurposeCarne,
    EconomicsV2Purpose.ornamental => l10n.economicsV2SelectPurposeOrnamental,
  };
}

class _EconomicsV2CycleCard extends StatelessWidget {
  const _EconomicsV2CycleCard({required this.cycle});

  final EconomicsV2Cycle cycle;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(title: Text(cycle.id), subtitle: Text(cycle.status)),
  );
}

class _EmptyCycles extends StatelessWidget {
  const _EmptyCycles();

  @override
  Widget build(BuildContext context) =>
      const Center(child: Icon(Icons.auto_graph, size: 48));
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 40),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}
