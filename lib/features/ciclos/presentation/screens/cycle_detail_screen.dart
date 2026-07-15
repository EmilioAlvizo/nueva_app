import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/cycle_models.dart';
import '../providers/cycle_providers.dart';

class CycleDetailScreen extends ConsumerWidget {
  const CycleDetailScreen({super.key, required this.cycleId});

  final String cycleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(cycleDetailProvider(cycleId));
    return Scaffold(
      appBar: AppBar(title: const Text('Cycle details')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Could not load cycle: $error')),
        data: (value) => _CycleDetailBody(detail: value),
      ),
    );
  }
}

class _CycleDetailBody extends ConsumerWidget {
  const _CycleDetailBody({required this.detail});

  final CycleDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final economics = ref.watch(cycleEconomicsProvider(detail.cycle.id));
    final timeline = ref.watch(cycleTimelineProvider(detail.cycle.id));
    final access = ref.watch(cycleAccessProvider(detail.cycle.farmId));
    final cycle = detail.cycle;
    final activeMembers = detail.members
        .where((member) => member.isActive)
        .toList();

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(cycleDetailProvider(cycle.id));
              ref.invalidate(cycleEconomicsProvider(cycle.id));
              ref.invalidate(cycleTimelineProvider(cycle.id));
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _CycleHeader(cycle: cycle),
                const SizedBox(height: 16),
                _AccessNotice(access: access, isActive: cycle.isActive),
                const SizedBox(height: 16),
                Text(
                  'Economics',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                economics.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => Text('Economics unavailable: $error'),
                  data: (value) => value == null
                      ? const Text('Economics are unavailable for this cycle.')
                      : _EconomicsCard(economics: value),
                ),
                const SizedBox(height: 24),
                Text(
                  'Explicit members (${activeMembers.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (detail.members.isEmpty)
                  const Text('No members were found.')
                else
                  ...detail.members.map(
                    (member) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        member.isActive
                            ? Icons.pets_outlined
                            : Icons.person_remove_outlined,
                      ),
                      title: Text(member.label),
                      subtitle: Text(member.groupName ?? 'No current group'),
                      trailing: Text(member.isActive ? 'Active' : 'Removed'),
                    ),
                  ),
                const SizedBox(height: 24),
                Text('Timeline', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                timeline.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => Text('Timeline unavailable: $error'),
                  data: (items) => items.isEmpty
                      ? const Text('No timeline items yet.')
                      : Column(
                          children: [
                            for (final item in items) _TimelineItem(item: item),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CycleHeader extends StatelessWidget {
  const _CycleHeader({required this.cycle});

  final Cycle cycle;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  cycle.displayName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              Chip(label: Text(cycle.isActive ? 'Active' : 'Closed')),
            ],
          ),
          Text('${cycle.productName} · ${cycle.animalTypeName}'),
          const SizedBox(height: 8),
          Text('Started ${DateFormat.yMMMd().format(cycle.startedAt)}'),
          if (cycle.endedAt != null)
            Text('Closed ${DateFormat.yMMMd().format(cycle.endedAt!)}'),
          if (cycle.notes?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(cycle.notes!),
          ],
        ],
      ),
    ),
  );
}

class _AccessNotice extends StatelessWidget {
  const _AccessNotice({required this.access, required this.isActive});

  final AsyncValue<CycleAccess> access;
  final bool isActive;

  @override
  Widget build(BuildContext context) => access.when(
    loading: () => const SizedBox.shrink(),
    error: (_, _) => const Text('Action availability could not be determined.'),
    data: (value) {
      final message = !isActive
          ? 'This cycle is closed. Its history is read-only.'
          : !value.canEdit
          ? 'You have Viewer access. Cycle actions are unavailable.'
          : 'You have ${value.role.label} access. Mutation forms arrive in the next cycle phase.';
      return Card(
        color: !isActive || !value.canEdit
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Theme.of(context).colorScheme.primaryContainer,
        child: Padding(padding: const EdgeInsets.all(12), child: Text(message)),
      );
    },
  );
}

class _EconomicsCard extends StatelessWidget {
  const _EconomicsCard({required this.economics});

  final CycleEconomics economics;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 24,
        runSpacing: 16,
        children: [
          _EconomicValue(label: 'Cost', value: economics.totalCost),
          _EconomicValue(label: 'Revenue', value: economics.totalRevenue),
          _EconomicValue(label: 'Profit', value: economics.profit),
          _EconomicValue(
            label: 'ROI',
            value: economics.roiPercent,
            suffix: '%',
          ),
          _EconomicValue(label: 'Unit cost', value: economics.unitCost),
        ],
      ),
    ),
  );
}

class _EconomicValue extends StatelessWidget {
  const _EconomicValue({
    required this.label,
    required this.value,
    this.suffix = '',
  });

  final String label;
  final double? value;
  final String suffix;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 110,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        Text(
          value == null ? 'Unavailable' : '${value!.toStringAsFixed(2)}$suffix',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    ),
  );
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.item});

  final CycleTimelineItem item;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(switch (item.kind) {
      CycleTimelineKind.started => Icons.play_circle_outline,
      CycleTimelineKind.memberJoined => Icons.person_add_outlined,
      CycleTimelineKind.memberLeft => Icons.person_remove_outlined,
      CycleTimelineKind.production => Icons.inventory_2_outlined,
    }),
    title: Text(item.title),
    subtitle: Text(
      [DateFormat.yMMMd().format(item.occurredAt), ?item.detail].join('\n'),
    ),
  );
}
