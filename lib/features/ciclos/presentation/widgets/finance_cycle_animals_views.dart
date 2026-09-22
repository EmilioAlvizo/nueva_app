import 'package:flutter/material.dart';

import '../../../../core/extensions/localization_extension.dart';
import '../../../../core/extensions/primitive_formatting_extensions.dart';
import '../../../../core/testing/app_widget_keys.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/finance_theme.dart';
import '../../domain/economics_v2_models.dart';
import '../providers/cycle_providers.dart';
import 'finance_cycle_visuals.dart';

class FinanceCycleAnimalsMembersView extends StatelessWidget {
  const FinanceCycleAnimalsMembersView({
    required this.members,
    required this.activeCount,
    required this.exitedCount,
    required this.canAssign,
    required this.canStartAssignment,
    required this.onAdd,
    super.key,
  });

  final List<EconomicsV2CycleMember> members;
  final int activeCount;
  final int exitedCount;
  final bool canAssign;
  final bool canStartAssignment;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FinanceCycleSectionHeader(
          title: l10n.financeCycleAnimalsTitle,
          subtitle: l10n.financeCycleAnimalsSubtitle,
        ),
        const SizedBox(height: AppSpacing.md),
        FinanceCycleSurfaceCard(
          key: const ValueKey(AppWidgetKeys.financeCycleAnimalsSummary),
          child: FinanceCycleMetricGroup(
            metrics: [
              FinanceCycleMetricTile(
                label: l10n.financeCycleAnimalsActiveMetric,
                value: activeCount.formatInteger(l10n),
                icon: Icons.pets_outlined,
              ),
              FinanceCycleMetricTile(
                label: l10n.financeCycleAnimalsExitedMetric,
                value: exitedCount.formatInteger(l10n),
                icon: Icons.logout_rounded,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        FinanceCycleContentSection(
          key: const ValueKey(AppWidgetKeys.financeCycleAnimalsAssigned),
          title: l10n.financeCycleAnimalsAssignedTitle,
          subtitle: l10n.financeCycleAnimalsAssignedCount(members.length),
          children: [
            if (members.isEmpty)
              FinanceCyclePanel(
                message: l10n.financeCycleAnimalsAssignedEmpty,
                variant: FinanceCyclePanelVariant.info,
              ),
            for (final member in members)
              FinanceCycleRecordTile(
                icon: Icons.pets_outlined,
                title: member.label,
                details: [
                  l10n.financeCycleMemberSince(
                    member.joinedOn.formatShortDate(l10n),
                  ),
                  ?member.groupNameSnapshot,
                ],
                badge: FinanceCycleStatusPill(
                  label: member.isActive
                      ? l10n.financeCycleAssignmentActive
                      : l10n.financeCycleAssignmentFinished,
                  isActive: member.isActive,
                ),
              ),
          ],
        ),
        if (canAssign) ...[
          const SizedBox(height: AppSpacing.md),
          if (!canStartAssignment) ...[
            FinanceCyclePanel(
              message: l10n.financeCycleAnimalsFutureStart,
              variant: FinanceCyclePanelVariant.info,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          FinanceCycleAnimalFooter(
            children: [
              FinanceCycleActionButton(
                keyValue: AppWidgetKeys.financeCycleAnimalsAdd,
                label: l10n.financeCycleAnimalsAdd,
                variant: FinanceCycleActionVariant.positive,
                onPressed: canStartAssignment ? onAdd : null,
                icon: Icons.add_rounded,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class FinanceCycleAnimalSelectionView extends StatelessWidget {
  const FinanceCycleAnimalSelectionView({
    required this.candidates,
    required this.selectedAnimalIds,
    required this.query,
    required this.filter,
    required this.hasGroupedCandidates,
    required this.hasUngroupedCandidates,
    required this.onQueryChanged,
    required this.onFilterChanged,
    required this.onToggleAnimal,
    required this.onClear,
    required this.onContinue,
    super.key,
  });

  final List<EconomicsV2AnimalCandidate> candidates;
  final Set<String> selectedAnimalIds;
  final String query;
  final FinanceCycleAnimalFilter filter;
  final bool hasGroupedCandidates;
  final bool hasUngroupedCandidates;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<FinanceCycleAnimalFilter> onFilterChanged;
  final ValueChanged<String> onToggleAnimal;
  final VoidCallback onClear;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final finance = FinanceTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FinanceCycleSectionHeader(
          title: l10n.financeCycleAnimalsSelectionTitle,
          subtitle: l10n.financeCycleAnimalsSelectionSubtitle,
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          key: const ValueKey(AppWidgetKeys.financeCycleAnimalSearch),
          initialValue: query,
          decoration: InputDecoration(
            labelText: l10n.financeCycleAnimalsSearchLabel,
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: finance.cycleInputSurface,
          ),
          onChanged: onQueryChanged,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            FinanceCycleAnimalFilterChip(
              keyValue: AppWidgetKeys.financeCycleAnimalFilterAll,
              label: l10n.financeCycleAnimalsFilterAll,
              selected: filter == FinanceCycleAnimalFilter.all,
              onSelected: () => onFilterChanged(FinanceCycleAnimalFilter.all),
            ),
            if (hasGroupedCandidates)
              FinanceCycleAnimalFilterChip(
                keyValue: AppWidgetKeys.financeCycleAnimalFilterGrouped,
                label: l10n.financeCycleAnimalsFilterGrouped,
                selected: filter == FinanceCycleAnimalFilter.grouped,
                onSelected: () =>
                    onFilterChanged(FinanceCycleAnimalFilter.grouped),
              ),
            if (hasUngroupedCandidates)
              FinanceCycleAnimalFilterChip(
                keyValue: AppWidgetKeys.financeCycleAnimalFilterUngrouped,
                label: l10n.financeCycleAnimalsFilterUngrouped,
                selected: filter == FinanceCycleAnimalFilter.ungrouped,
                onSelected: () =>
                    onFilterChanged(FinanceCycleAnimalFilter.ungrouped),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          liveRegion: true,
          child: Text(
            l10n.financeCycleAnimalsAvailableCount(candidates.length),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: finance.cycleOnSurfaceMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (candidates.isEmpty)
          FinanceCyclePanel(
            message: l10n.financeCycleAnimalsNoResults,
            variant: FinanceCyclePanelVariant.info,
          )
        else
          for (final candidate in candidates) ...[
            FinanceCycleAnimalCandidateTile(
              candidate: candidate,
              selected: selectedAnimalIds.contains(candidate.animalId),
              onPressed: () => onToggleAnimal(candidate.animalId),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
        const SizedBox(height: AppSpacing.sm),
        FinanceCycleAnimalFooter(
          children: [
            Semantics(
              key: const ValueKey(
                AppWidgetKeys.financeCycleAnimalsSelectionStatus,
              ),
              container: true,
              liveRegion: true,
              label: l10n.financeCycleAnimalsSelectedCount(
                selectedAnimalIds.length,
              ),
              child: Text(
                l10n.financeCycleAnimalsSelectedCount(selectedAnimalIds.length),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: finance.cycleOnSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            FinanceCycleActionButton(
              keyValue: AppWidgetKeys.financeCycleAnimalsContinue,
              label: l10n.financeCycleAnimalsContinue(selectedAnimalIds.length),
              variant: FinanceCycleActionVariant.positive,
              onPressed: selectedAnimalIds.isEmpty ? null : onContinue,
              icon: Icons.arrow_forward_rounded,
            ),
            const SizedBox(height: AppSpacing.xs),
            FinanceCycleActionButton(
              keyValue: AppWidgetKeys.financeCycleAnimalsClear,
              label: l10n.financeCycleAnimalsClear,
              variant: FinanceCycleActionVariant.secondary,
              onPressed: selectedAnimalIds.isEmpty ? null : onClear,
            ),
          ],
        ),
      ],
    );
  }
}

class FinanceCycleAnimalConfirmationView extends StatelessWidget {
  const FinanceCycleAnimalConfirmationView({
    required this.candidates,
    required this.joinedOn,
    required this.projectedActiveCount,
    required this.isPending,
    required this.onSelectDate,
    required this.onCancel,
    required this.onConfirm,
    super.key,
  });

  final List<EconomicsV2AnimalCandidate> candidates;
  final DateTime joinedOn;
  final int projectedActiveCount;
  final bool isPending;
  final VoidCallback onSelectDate;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final finance = FinanceTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FinanceCycleSectionHeader(
          title: l10n.financeCycleAnimalsConfirmationTitle,
          subtitle: l10n.financeCycleAnimalsConfirmationSubtitle,
        ),
        const SizedBox(height: AppSpacing.md),
        FinanceCyclePanel(
          message: l10n.financeCycleAnimalsProjectedActive(
            projectedActiveCount,
          ),
          variant: FinanceCyclePanelVariant.result,
        ),
        const SizedBox(height: AppSpacing.sm),
        FinanceCycleContentSection(
          title: l10n.financeCycleAnimalsSelectedTitle,
          subtitle: l10n.financeCycleAnimalsSelectedCount(candidates.length),
          children: [
            for (final candidate in candidates)
              FinanceCycleRecordTile(
                icon: Icons.pets_outlined,
                title: candidate.label,
                details: [
                  candidate.groupName ?? l10n.financeCycleAnimalsWithoutGroup,
                ],
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        FinanceCycleFieldSurface(
          keyValue: AppWidgetKeys.financeCycleAnimalsJoinedOn,
          label: l10n.financeCycleAnimalsJoinedOnLabel,
          value: joinedOn.formatShortDate(l10n),
          icon: Icons.event_available_outlined,
          onPressed: isPending ? null : onSelectDate,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.financeCycleAnimalsJoinedOnConstraint,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: finance.cycleOnSurfaceMuted),
        ),
        const SizedBox(height: AppSpacing.md),
        FinanceCycleAnimalFooter(
          children: [
            FinanceCycleActionButton(
              keyValue: AppWidgetKeys.financeCycleAnimalsConfirm,
              label: l10n.financeCycleAnimalsConfirm(candidates.length),
              semanticLabel: isPending
                  ? l10n.financeCycleAnimalsConfirmPending
                  : null,
              variant: FinanceCycleActionVariant.positive,
              onPressed: isPending ? null : onConfirm,
              child: isPending
                  ? Semantics(
                      key: const ValueKey(
                        AppWidgetKeys.financeCycleAnimalsPending,
                      ),
                      label: l10n.financeCycleAnimalsConfirmPending,
                      child: const SizedBox.square(
                        dimension: AppSizes.smallIcon,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: AppSpacing.xs),
            FinanceCycleActionButton(
              keyValue: AppWidgetKeys.financeCycleAnimalsCancel,
              label: l10n.financeCycleAnimalsCancel,
              variant: FinanceCycleActionVariant.secondary,
              onPressed: isPending ? null : onCancel,
            ),
          ],
        ),
      ],
    );
  }
}

class FinanceCycleAnimalCandidateTile extends StatelessWidget {
  const FinanceCycleAnimalCandidateTile({
    required this.candidate,
    required this.selected,
    required this.onPressed,
    super.key,
  });

  final EconomicsV2AnimalCandidate candidate;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final finance = FinanceTheme.of(context);
    return Semantics(
      key: ValueKey(
        AppWidgetKeys.financeCycleAnimalCandidate(candidate.animalId),
      ),
      container: true,
      button: true,
      enabled: true,
      selected: selected,
      label: l10n.financeCycleAnimalsSelectAnimal(candidate.label),
      onTap: onPressed,
      child: ExcludeSemantics(
        child: Material(
          color: selected ? finance.cycleSurfaceElevated : finance.cycleSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.medium),
            side: BorderSide(
              color: selected
                  ? finance.cyclePositiveAction
                  : finance.cycleOutline,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSizes.minTapTarget,
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  children: [
                    Checkbox(value: selected, onChanged: (_) => onPressed()),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            candidate.label,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: finance.cycleOnSurface,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            candidate.groupName ??
                                l10n.financeCycleAnimalsWithoutGroup,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: finance.cycleOnSurfaceMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FinanceCycleAnimalFilterChip extends StatelessWidget {
  const FinanceCycleAnimalFilterChip({
    required this.keyValue,
    required this.label,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final String keyValue;
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
    child: FilterChip(
      key: ValueKey(keyValue),
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    ),
  );
}

class FinanceCycleAnimalFooter extends StatelessWidget {
  const FinanceCycleAnimalFooter({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    minimum: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}
