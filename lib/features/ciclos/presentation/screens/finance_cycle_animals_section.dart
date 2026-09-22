import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/primitive_formatting_extensions.dart';
import '../../domain/economics_v2_models.dart';
import '../providers/cycle_providers.dart';
import '../widgets/finance_cycle_animals_views.dart';

class FinanceCycleAnimalsSection extends ConsumerWidget {
  const FinanceCycleAnimalsSection({
    required this.farmId,
    required this.cycleId,
    required this.detail,
    required this.members,
    required this.canAssign,
    required this.isPending,
    this.now,
    super.key,
  });

  final String farmId;
  final String cycleId;
  final EconomicsV2CycleDetail detail;
  final EconomicsV2CycleMembers members;
  final bool canAssign;
  final bool isPending;
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workflow = ref.watch(financeCyclesWorkflowProvider(farmId));
    final notifier = ref.read(financeCyclesWorkflowProvider(farmId).notifier);
    final todayValue = now?.call() ?? DateTime.now();
    final today = DateUtils.dateOnly(todayValue);
    final cycleStart = DateUtils.dateOnly(detail.startsOn);
    final canStartAssignment = !today.isBefore(cycleStart);
    final activeCount = detail.activeAnimalCount;
    final exitedCount = detail.exitedAnimalCount;
    final candidatesById = {
      for (final candidate in members.candidates) candidate.animalId: candidate,
    };
    final selectedIds = Set<String>.unmodifiable(
      workflow.selectedAnimalIds.where(candidatesById.containsKey),
    );
    final selectedCandidates = [
      for (final animalId in selectedIds) candidatesById[animalId]!,
    ];

    ref.listen(economicsV2CycleMembersProvider(farmId, cycleId), (_, next) {
      final latest = next.value;
      if (latest == null) return;
      final availableIds = {
        for (final candidate in latest.candidates) candidate.animalId,
      };
      final selection = ref
          .read(financeCyclesWorkflowProvider(farmId))
          .selectedAnimalIds;
      if (selection.any((animalId) => !availableIds.contains(animalId))) {
        ref
            .read(financeCyclesWorkflowProvider(farmId).notifier)
            .resetAnimalAssignment();
      }
    });

    return switch ((workflow.animalsStep, workflow.joinedOn)) {
      (FinanceCycleAnimalsStep.members, _) => FinanceCycleAnimalsMembersView(
        members: members.members,
        activeCount: activeCount,
        exitedCount: exitedCount,
        canAssign: canAssign,
        canStartAssignment: canStartAssignment,
        onAdd: notifier.startAnimalSelection,
      ),
      (FinanceCycleAnimalsStep.selection, _) => FinanceCycleAnimalSelectionView(
        candidates: [
          for (final candidate in members.candidates)
            if (_matchesCandidate(candidate, workflow)) candidate,
        ],
        selectedAnimalIds: selectedIds,
        query: workflow.animalSearchQuery,
        filter: workflow.animalFilter,
        hasGroupedCandidates: members.candidates.any(_isGrouped),
        hasUngroupedCandidates: members.candidates.any(
          (candidate) => !_isGrouped(candidate),
        ),
        onQueryChanged: notifier.setAnimalSearchQuery,
        onFilterChanged: notifier.setAnimalFilter,
        onToggleAnimal: notifier.toggleAnimal,
        onClear: notifier.clearSelectedAnimals,
        onContinue: () => notifier.continueAnimalSelection(today),
      ),
      (FinanceCycleAnimalsStep.confirmation, final joinedOn?) =>
        FinanceCycleAnimalConfirmationView(
          candidates: selectedCandidates,
          joinedOn: joinedOn,
          projectedActiveCount: activeCount + selectedCandidates.length,
          isPending: isPending,
          onSelectDate: () => unawaited(
            _selectJoinedOn(
              context,
              ref,
              initialDate: joinedOn,
              firstDate: cycleStart,
              lastDate: today,
            ),
          ),
          onCancel: notifier.backAnimalAssignment,
          onConfirm: () => unawaited(
            ref
                .read(
                  financeCycleWorkspaceMutationsProvider(
                    farmId,
                    cycleId,
                  ).notifier,
                )
                .assignAnimals(
                  animalIds: workflow.selectedAnimalIds,
                  joinedOn: joinedOn,
                ),
          ),
        ),
      (FinanceCycleAnimalsStep.confirmation, null) =>
        FinanceCycleAnimalsMembersView(
          members: members.members,
          activeCount: activeCount,
          exitedCount: exitedCount,
          canAssign: canAssign,
          canStartAssignment: canStartAssignment,
          onAdd: notifier.startAnimalSelection,
        ),
    };
  }

  bool _matchesCandidate(
    EconomicsV2AnimalCandidate candidate,
    FinanceCyclesWorkflowState workflow,
  ) {
    final grouped = _isGrouped(candidate);
    final matchesFilter = switch (workflow.animalFilter) {
      FinanceCycleAnimalFilter.all => true,
      FinanceCycleAnimalFilter.grouped => grouped,
      FinanceCycleAnimalFilter.ungrouped => !grouped,
    };
    if (!matchesFilter) return false;
    final query = workflow.animalSearchQuery.normalizedForSearch();
    if (query.isEmpty) return true;
    final searchable = '${candidate.label} ${candidate.groupName ?? ''}'
        .normalizedForSearch();
    return searchable.contains(query);
  }

  bool _isGrouped(EconomicsV2AnimalCandidate candidate) =>
      candidate.groupName?.trim().isNotEmpty ?? false;

  Future<void> _selectJoinedOn(
    BuildContext context,
    WidgetRef ref, {
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
  }) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      routeSettings: const RouteSettings(name: 'cycle-animal-joined-on'),
    );
    if (!context.mounted || selected == null) return;
    ref
        .read(financeCyclesWorkflowProvider(farmId).notifier)
        .setAnimalJoinedOn(selected);
  }
}
