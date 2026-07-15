import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/cycle_models.dart';
import '../providers/cycle_providers.dart';

class CyclesListScreen extends ConsumerStatefulWidget {
  const CyclesListScreen({super.key, required this.farmId});

  final String farmId;

  @override
  ConsumerState<CyclesListScreen> createState() => _CyclesListScreenState();
}

class _CyclesListScreenState extends ConsumerState<CyclesListScreen> {
  var _showClosed = false;

  @override
  Widget build(BuildContext context) {
    final cycles = ref.watch(cyclesProvider(widget.farmId));
    final access = ref.watch(cycleAccessProvider(widget.farmId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ciclos'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Activos'),
                  selected: !_showClosed,
                  onSelected: (_) => setState(() => _showClosed = false),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Cerrados'),
                  selected: _showClosed,
                  onSelected: (_) => setState(() => _showClosed = true),
                ),
              ],
            ),
          ),
        ),
      ),
      body: cycles.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _LoadError(
          message: '$error',
          onRetry: () => ref.invalidate(cyclesProvider(widget.farmId)),
        ),
        data: (items) {
          final filtered = items
              .where((cycle) => _showClosed ? !cycle.isActive : cycle.isActive)
              .toList();
          if (filtered.isEmpty) {
            return _EmptyCycles(showClosed: _showClosed);
          }
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(cyclesProvider(widget.farmId)),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _CycleCard(
                cycle: filtered[index],
                onTap: () => context.push('/ciclos/${filtered[index].id}'),
              ),
            ),
          );
        },
      ),
      floatingActionButton: access.when(
        loading: () => null,
        error: (_, _) => null,
        data: (value) => value.canEdit
            ? FloatingActionButton.extended(
                onPressed: () => context.push('/ciclos/nuevo'),
                icon: const Icon(Icons.add),
                label: const Text('Nuevo ciclo'),
              )
            : null,
      ),
    );
  }
}

class _CycleCard extends StatelessWidget {
  const _CycleCard({required this.cycle, required this.onTap});

  final Cycle cycle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: cycle.isActive
                    ? colors.primaryContainer
                    : colors.surfaceContainerHighest,
                child: Icon(
                  cycle.productCode == 'huevo'
                      ? Icons.egg_outlined
                      : Icons.restaurant_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cycle.displayName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text('${cycle.productName} · ${cycle.animalTypeName}'),
                    const SizedBox(height: 4),
                    Text(
                      'Iniciado el ${DateFormat.yMMMd().format(cycle.startedAt)}',
                    ),
                  ],
                ),
              ),
              _StatusBadge(isActive: cycle.isActive),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) => Chip(
    label: Text(isActive ? 'Activo' : 'Cerrado'),
    visualDensity: VisualDensity.compact,
  );
}

class _EmptyCycles extends StatelessWidget {
  const _EmptyCycles({required this.showClosed});

  final bool showClosed;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            showClosed ? Icons.inventory_2_outlined : Icons.auto_graph,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            showClosed
                ? 'Aún no hay ciclos cerrados.'
                : 'Aún no hay ciclos activos.',
          ),
        ],
      ),
    ),
  );
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
          OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    ),
  );
}
