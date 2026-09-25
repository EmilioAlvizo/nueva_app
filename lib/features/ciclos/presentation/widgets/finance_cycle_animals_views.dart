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
    this.canSell = false,
    this.onSell,
    super.key,
  });

  final List<EconomicsV2CycleMember> members;
  final int activeCount;
  final int exitedCount;
  final bool canAssign;
  final bool canStartAssignment;
  final VoidCallback onAdd;
  final bool canSell;
  final VoidCallback? onSell;

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
        FinanceCycleAnimalsSummaryCard(
          key: const ValueKey(AppWidgetKeys.financeCycleAnimalsSummary),
          activeCount: activeCount,
          exitedCount: exitedCount,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (members.isEmpty)
          FinanceCycleAnimalsEmptyCard(
            key: const ValueKey(AppWidgetKeys.financeCycleAnimalsEmpty),
            message: l10n.financeCycleAnimalsAssignedEmpty,
          )
        else
          for (final (index, member) in members.indexed) ...[
            FinanceCycleAnimalMemberCard(
              key: ValueKey(
                AppWidgetKeys.financeCycleAnimalMember(member.animalId),
              ),
              member: member,
            ),
            if (index < members.length - 1)
              const SizedBox(height: AppSpacing.sm),
          ],
        if (canAssign) ...[
          const SizedBox(height: AppSpacing.lg),
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
              if (canSell) ...[
                const SizedBox(height: AppSpacing.xs),
                FinanceCycleActionButton(
                  keyValue: AppWidgetKeys.financeCycleAnimalsSell,
                  label: l10n.financeCycleAnimalsSell,
                  variant: FinanceCycleActionVariant.primary,
                  onPressed: onSell,
                  icon: Icons.sell_outlined,
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class FinanceCycleMeatSaleSelectionView extends StatelessWidget {
  const FinanceCycleMeatSaleSelectionView({
    required this.members,
    required this.selectedAnimalIds,
    required this.onToggleAnimal,
    required this.onSelectAll,
    required this.onClear,
    required this.onCancel,
    required this.onContinue,
    super.key,
  });

  final List<EconomicsV2CycleMember> members;
  final Set<String> selectedAnimalIds;
  final ValueChanged<String> onToggleAnimal;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;
  final VoidCallback onCancel;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selectedAll =
        members.isNotEmpty && selectedAnimalIds.length == members.length;
    return Column(
      key: const ValueKey(AppWidgetKeys.financeCycleAnimalsSaleSelection),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FinanceCycleSectionHeader(
          title: l10n.financeCycleAnimalsSaleTitle,
          subtitle: l10n.financeCycleAnimalsSaleSubtitle,
        ),
        const SizedBox(height: AppSpacing.md),
        for (final member in members) ...[
          Semantics(
            container: true,
            button: true,
            selected: selectedAnimalIds.contains(member.animalId),
            label: l10n.financeCycleAnimalsSelectAnimal(member.label),
            child: CheckboxListTile(
              value: selectedAnimalIds.contains(member.animalId),
              title: Text(member.label),
              subtitle: Text(
                l10n.financeCycleMemberJoinedOn(
                  member.joinedOn.formatShortDate(l10n),
                ),
              ),
              onChanged: (_) => onToggleAnimal(member.animalId),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        FinanceCycleAnimalFooter(
          children: [
            FinanceCycleActionButton(
              keyValue: AppWidgetKeys.financeCycleAnimalsSaleSelectAll,
              label: selectedAll
                  ? l10n.financeCycleAnimalsClear
                  : l10n.financeCycleAnimalsSaleSelectAll,
              variant: FinanceCycleActionVariant.secondary,
              onPressed: selectedAll ? onClear : onSelectAll,
            ),
            const SizedBox(height: AppSpacing.xs),
            FinanceCycleActionButton(
              keyValue: AppWidgetKeys.financeCycleAnimalsSaleContinue,
              label: selectedAll
                  ? l10n.financeCycleAnimalsSaleAll(members.length)
                  : l10n.financeCycleAnimalsSaleSelected(
                      selectedAnimalIds.length,
                    ),
              variant: FinanceCycleActionVariant.primary,
              onPressed: selectedAnimalIds.isEmpty ? null : onContinue,
              icon: Icons.sell_outlined,
            ),
            const SizedBox(height: AppSpacing.xs),
            FinanceCycleActionButton(
              keyValue: AppWidgetKeys.financeCycleAnimalsCancel,
              label: l10n.financeCycleCancel,
              variant: FinanceCycleActionVariant.secondary,
              onPressed: onCancel,
            ),
          ],
        ),
      ],
    );
  }
}

class FinanceCycleAnimalsSummaryCard extends StatelessWidget {
  const FinanceCycleAnimalsSummaryCard({
    required this.activeCount,
    required this.exitedCount,
    super.key,
  });

  final int activeCount;
  final int exitedCount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final finance = FinanceTheme.of(context);
    final textTheme = Theme.of(context).textTheme;
    final activeSummary = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          activeCount.formatInteger(l10n),
          style: textTheme.displaySmall?.copyWith(
            color: finance.cycleOnSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          l10n.financeCycleAnimalsActiveMetric,
          style: textTheme.bodySmall?.copyWith(
            color: finance.cycleOnSurfaceMuted,
          ),
        ),
      ],
    );
    final exitedPill = FinanceCycleAnimalsExitedPill(count: exitedCount);

    return FinanceCycleSurfaceCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          final usesInlineLayout =
              constraints.maxWidth / textScale >=
              AppSizes.financeHeaderBreakpoint;
          if (!usesInlineLayout) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                activeSummary,
                const SizedBox(height: AppSpacing.sm),
                exitedPill,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: activeSummary),
              const SizedBox(width: AppSpacing.sm),
              exitedPill,
            ],
          );
        },
      ),
    );
  }
}

class FinanceCycleAnimalsExitedPill extends StatelessWidget {
  const FinanceCycleAnimalsExitedPill({required this.count, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    final finance = FinanceTheme.of(context);
    return DecoratedBox(
      key: const ValueKey(AppWidgetKeys.financeCycleAnimalsExitedPill),
      decoration: BoxDecoration(
        color: finance.cycleSurfaceElevated,
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Text(
          context.l10n.financeCycleAnimalsExitedPill(count),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: finance.cycleOnSurfaceMuted,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class FinanceCycleAnimalMemberCard extends StatelessWidget {
  const FinanceCycleAnimalMemberCard({required this.member, super.key});

  final EconomicsV2CycleMember member;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final finance = FinanceTheme.of(context);
    final textTheme = Theme.of(context).textTheme;
    final memberDetails = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          member.label,
          style: textTheme.titleMedium?.copyWith(
            color: finance.cycleOnSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          l10n.financeCycleMemberJoinedOn(
            member.joinedOn.formatShortDate(l10n),
          ),
          style: textTheme.bodySmall?.copyWith(
            color: finance.cycleOnSurfaceMuted,
          ),
        ),
      ],
    );
    final status = FinanceCycleAnimalStatusPill(
      animalId: member.animalId,
      label: member.isActive
          ? l10n.financeCycleAssignmentActive
          : l10n.financeCycleAssignmentFinished,
      isActive: member.isActive,
    );

    return FinanceCycleSurfaceCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          final usesInlineLayout =
              constraints.maxWidth / textScale >=
              AppSizes.financeHeaderBreakpoint;
          if (!usesInlineLayout) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                memberDetails,
                const SizedBox(height: AppSpacing.sm),
                status,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: memberDetails),
              const SizedBox(width: AppSpacing.sm),
              status,
            ],
          );
        },
      ),
    );
  }
}

class FinanceCycleAnimalStatusPill extends StatelessWidget {
  const FinanceCycleAnimalStatusPill({
    required this.animalId,
    required this.label,
    required this.isActive,
    super.key,
  });

  final String animalId;
  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final finance = FinanceTheme.of(context);
    return DecoratedBox(
      key: ValueKey(AppWidgetKeys.financeCycleAnimalMemberStatus(animalId)),
      decoration: BoxDecoration(
        color: isActive
            ? finance.cyclePositiveAction
            : finance.cycleSurfaceElevated,
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: isActive
                ? finance.cycleOnPositiveAction
                : finance.cycleOnSurfaceMuted,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class FinanceCycleAnimalsEmptyCard extends StatelessWidget {
  const FinanceCycleAnimalsEmptyCard({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final finance = FinanceTheme.of(context);
    return FinanceCycleSurfaceCard(
      child: Text(
        message,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: finance.cycleOnSurfaceMuted),
      ),
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

final class FinanceCycleSaleDraft {
  const FinanceCycleSaleDraft({
    required this.totalAmount,
    required this.totalWeightKg,
    this.note,
  });

  final double totalAmount;
  final double totalWeightKg;
  final String? note;
}

Future<FinanceCycleSaleDraft?> showFinanceCycleSaleDialog(
  BuildContext context, {
  required int selectedCount,
}) => showDialog<FinanceCycleSaleDraft>(
  context: context,
  routeSettings: const RouteSettings(name: 'cycle-meat-sale'),
  builder: (_) => FinanceCycleSaleDialog(selectedCount: selectedCount),
);

class FinanceCycleSaleDialog extends StatefulWidget {
  const FinanceCycleSaleDialog({required this.selectedCount, super.key});

  final int selectedCount;

  @override
  State<FinanceCycleSaleDialog> createState() => _FinanceCycleSaleDialogState();
}

class _FinanceCycleSaleDialogState extends State<FinanceCycleSaleDialog> {
  final _amount = TextEditingController();
  final _weight = TextEditingController();
  final _note = TextEditingController();
  var _showValidation = false;

  @override
  void dispose() {
    _amount.dispose();
    _weight.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      scrollable: true,
      title: Text(
        l10n.financeCycleAnimalsSaleDialogTitle(widget.selectedCount),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey(AppWidgetKeys.financeCycleAnimalsSaleAmount),
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l10n.financeCycleAnimalsSaleAmountLabel,
            ),
          ),
          TextField(
            key: const ValueKey(AppWidgetKeys.financeCycleAnimalsSaleWeight),
            controller: _weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l10n.financeCycleAnimalsSaleWeightLabel,
            ),
          ),
          TextField(
            key: const ValueKey(AppWidgetKeys.financeCycleAnimalsSaleNote),
            controller: _note,
            decoration: InputDecoration(labelText: l10n.financeCycleNoteLabel),
          ),
          if (_showValidation)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                l10n.financeCycleInvalidForm,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.financeCycleCancel),
        ),
        FilledButton(
          key: const ValueKey(AppWidgetKeys.financeCycleAnimalsSaleConfirm),
          onPressed: _submit,
          child: Text(l10n.financeCycleAnimalsSaleConfirm),
        ),
      ],
    );
  }

  void _submit() {
    final amount = double.tryParse(_amount.text.trim());
    final weight = double.tryParse(_weight.text.trim());
    if (amount == null ||
        !amount.isFinite ||
        amount < 0 ||
        weight == null ||
        !weight.isFinite ||
        weight <= 0) {
      setState(() => _showValidation = true);
      return;
    }
    final note = _note.text.trim();
    Navigator.of(context).pop(
      FinanceCycleSaleDraft(
        totalAmount: amount,
        totalWeightKg: weight,
        note: note.isEmpty ? null : note,
      ),
    );
  }
}
