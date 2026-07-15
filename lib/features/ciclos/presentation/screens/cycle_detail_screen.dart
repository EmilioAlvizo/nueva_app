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
      appBar: AppBar(title: const Text('Detalles del ciclo')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('No se pudo cargar el ciclo: $error')),
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
                Text('Economía', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                economics.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => Text('Economía no disponible: $error'),
                  data: (value) => value == null
                      ? const Text(
                          'La información económica no está disponible para este ciclo.',
                        )
                      : _EconomicsCard(economics: value),
                ),
                const SizedBox(height: 24),
                Text(
                  'Integrantes explícitos (${activeMembers.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (detail.members.isEmpty)
                  const Text('No se encontraron integrantes.')
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
                      subtitle: Text(member.groupName ?? 'Sin grupo actual'),
                      trailing: Text(member.isActive ? 'Activo' : 'Retirado'),
                    ),
                  ),
                access.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (value) => cycle.isActive && value.canEdit
                      ? Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: () => showDialog<void>(
                                context: context,
                                builder: (_) => _MembershipEditor(
                                  cycle: cycle,
                                  activeMembers: activeMembers,
                                ),
                              ),
                              icon: const Icon(Icons.group_outlined),
                              label: const Text('Editar integrantes'),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 24),
                Text(
                  'Cronología',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                timeline.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => Text('Cronología no disponible: $error'),
                  data: (items) => items.isEmpty
                      ? const Text('Aún no hay elementos en la cronología.')
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

class _MembershipEditor extends ConsumerStatefulWidget {
  const _MembershipEditor({required this.cycle, required this.activeMembers});

  final Cycle cycle;
  final List<CycleMember> activeMembers;

  @override
  ConsumerState<_MembershipEditor> createState() => _MembershipEditorState();
}

class _MembershipEditorState extends ConsumerState<_MembershipEditor> {
  late final Set<String> _initialMemberIds;
  late final Set<String> _selectedMemberIds;
  String? _error;
  var _submitting = false;

  @override
  void initState() {
    super.initState();
    _initialMemberIds = {
      for (final member in widget.activeMembers) member.animalId,
    };
    _selectedMemberIds = {..._initialMemberIds};
  }

  Future<void> _submit() async {
    final additions = _selectedMemberIds
        .where((id) => !_initialMemberIds.contains(id))
        .toList(growable: false);
    final removals = _initialMemberIds
        .where((id) => !_selectedMemberIds.contains(id))
        .toList(growable: false);
    if (additions.isEmpty && removals.isEmpty) {
      setState(() => _error = 'Selecciona al menos un cambio de integrantes.');
      return;
    }

    setState(() {
      _error = null;
      _submitting = true;
    });
    try {
      await ref
          .read(cycleMutationsProvider.notifier)
          .editMembers(
            CycleMembershipEditInput(
              cycleId: widget.cycle.id,
              version: widget.cycle.version,
              additions: additions,
              removals: removals,
            ),
          );
      ref.invalidate(cyclesProvider(widget.cycle.farmId));
      ref.invalidate(cycleDetailProvider(widget.cycle.id));
      ref.invalidate(cycleEconomicsProvider(widget.cycle.id));
      ref.invalidate(cycleTimelineProvider(widget.cycle.id));
      ref.invalidate(eligibleCycleMembersProvider(widget.cycle.farmId));
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final candidates = ref.watch(
      eligibleCycleMembersProvider(widget.cycle.farmId),
    );
    final eligibleCandidates = switch (candidates) {
      AsyncData(:final value) =>
        value
            .where(
              (candidate) =>
                  candidate.animalTypeId == widget.cycle.animalTypeId,
            )
            .toList(),
      _ => const <CycleMemberCandidate>[],
    };
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                'Editar integrantes explícitos',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Los cambios usan la versión mostrada del ciclo. Actualiza si otra persona editó este ciclo.',
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    Text(
                      'Integrantes actuales',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    for (final member in widget.activeMembers)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _selectedMemberIds.contains(member.animalId),
                        title: Text(member.label),
                        subtitle: Text(member.groupName ?? 'Sin grupo actual'),
                        onChanged: _submitting
                            ? null
                            : (selected) => setState(() {
                                if (selected ?? false) {
                                  _selectedMemberIds.add(member.animalId);
                                } else {
                                  _selectedMemberIds.remove(member.animalId);
                                }
                              }),
                      ),
                    const Divider(),
                    Text(
                      'Animales disponibles',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (candidates.isLoading)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (candidates.hasError)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No se pudieron cargar los animales disponibles: ${candidates.error}',
                        ),
                      )
                    else if (eligibleCandidates.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('No hay animales sin asignar disponibles.'),
                      )
                    else
                      for (final candidate in eligibleCandidates)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _selectedMemberIds.contains(candidate.id),
                          title: Text(candidate.label),
                          subtitle: Text(candidate.groupName ?? 'Sin grupo'),
                          onChanged: _submitting
                              ? null
                              : (selected) => setState(() {
                                  if (selected ?? false) {
                                    _selectedMemberIds.add(candidate.id);
                                  } else {
                                    _selectedMemberIds.remove(candidate.id);
                                  }
                                }),
                        ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Guardar integrantes'),
                  ),
                ],
              ),
            ],
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
              Chip(label: Text(cycle.isActive ? 'Activo' : 'Cerrado')),
            ],
          ),
          Text('${cycle.productName} · ${cycle.animalTypeName}'),
          const SizedBox(height: 8),
          Text('Iniciado el ${DateFormat.yMMMd().format(cycle.startedAt)}'),
          if (cycle.endedAt != null)
            Text('Cerrado el ${DateFormat.yMMMd().format(cycle.endedAt!)}'),
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
    error: (_, _) =>
        const Text('No se pudo determinar la disponibilidad de acciones.'),
    data: (value) {
      final message = !isActive
          ? 'Este ciclo está cerrado. Su historial es de solo lectura.'
          : !value.canEdit
          ? 'Tienes acceso de visualización. Las acciones del ciclo no están disponibles.'
          : 'Tienes acceso de ${value.role.label}. Los formularios de cambios llegarán en la siguiente fase del ciclo.';
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
          _EconomicValue(label: 'Costo', value: economics.totalCost),
          _EconomicValue(label: 'Ingresos', value: economics.totalRevenue),
          _EconomicValue(label: 'Ganancia', value: economics.profit),
          _EconomicValue(
            label: 'ROI',
            value: economics.roiPercent,
            suffix: '%',
          ),
          _EconomicValue(label: 'Costo unitario', value: economics.unitCost),
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
          value == null
              ? 'No disponible'
              : '${value!.toStringAsFixed(2)}$suffix',
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
