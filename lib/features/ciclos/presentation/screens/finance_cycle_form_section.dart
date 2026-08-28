import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/localization_extension.dart';
import '../../../../core/extensions/primitive_formatting_extensions.dart';
import '../../../../core/testing/app_widget_keys.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../animales/animales_provider.dart';
import '../providers/cycle_providers.dart';
import '../widgets/finance_cycle_visuals.dart';

class FinanceCycleFormSection extends ConsumerStatefulWidget {
  const FinanceCycleFormSection({required this.farmId, this.now, super.key});

  final String farmId;
  final DateTime Function()? now;

  @override
  ConsumerState<FinanceCycleFormSection> createState() =>
      _FinanceCycleFormSectionState();
}

class _FinanceCycleFormSectionState
    extends ConsumerState<FinanceCycleFormSection> {
  String? _purposeId;
  DateTime? _startsOn;
  DateTime? _endsOn;
  var _showValidation = false;

  DateTime _today() {
    final value = widget.now?.call() ?? DateTime.now();
    return DateTime(value.year, value.month, value.day);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final purposes = ref.watch(propositosProvider(widget.farmId));
    final creation = ref.watch(financeCycleCreationProvider(widget.farmId));
    final isPending = creation.isLoading;

    return FinanceCycleCanvas(
      maxWidth: AppSizes.financeFormMaxWidth,
      child: SingleChildScrollView(
        key: const ValueKey(AppWidgetKeys.financeCycleForm),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FinanceCycleSectionHeader(
              title: l10n.financeCycleCreateTitle,
              subtitle: l10n.financeCycleCreateSubtitle,
            ),
            const SizedBox(height: AppSpacing.md),
            switch (purposes) {
              AsyncData(:final value) => FinanceCycleDropdownSurface<String>(
                keyValue: AppWidgetKeys.financeCyclePurpose,
                label: l10n.financeCyclePurposeLabel,
                value: _purposeId,
                items: [
                  for (final purpose in value)
                    DropdownMenuItem(
                      value: purpose.id,
                      child: Text(purpose.nombre),
                    ),
                ],
                onChanged: isPending
                    ? null
                    : (value) => setState(() => _purposeId = value),
              ),
              AsyncError() => FinanceCyclePanel(
                message: l10n.financeCyclesErrorMessage,
                variant: FinanceCyclePanelVariant.warning,
              ),
              AsyncLoading() => Semantics(
                label: l10n.financeCyclesLoadingLabel,
                child: const LinearProgressIndicator(),
              ),
            },
            const SizedBox(height: AppSpacing.sm),
            FinanceCycleFieldSurface(
              keyValue: AppWidgetKeys.financeCycleStartDate,
              label: l10n.financeCycleStartDateLabel,
              value:
                  _startsOn?.formatShortDate(l10n) ??
                  l10n.financeCycleStartDateLabel,
              icon: Icons.event_outlined,
              onPressed: isPending ? null : () => _selectStartDate(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            FinanceCycleFieldSurface(
              keyValue: AppWidgetKeys.financeCycleEndDate,
              label: l10n.financeCycleEndDateLabel,
              value:
                  _endsOn?.formatShortDate(l10n) ??
                  l10n.financeCycleEndDateLabel,
              icon: Icons.event_available_outlined,
              onPressed: isPending ? null : () => _selectEndDate(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            FinanceCyclePanel(
              key: const ValueKey(AppWidgetKeys.financeCycleInitialInfo),
              message: l10n.financeCycleInitialOpenInfo,
              variant: FinanceCyclePanelVariant.info,
            ),
            if (_showValidation) ...[
              const SizedBox(height: AppSpacing.sm),
              FinanceCyclePanel(
                key: const ValueKey(AppWidgetKeys.financeCycleValidation),
                message: l10n.financeCycleValidation,
                variant: FinanceCyclePanelVariant.warning,
              ),
            ],
            if (creation case AsyncError()) ...[
              const SizedBox(height: AppSpacing.sm),
              FinanceCyclePanel(
                message: l10n.financeCycleCreateError,
                variant: FinanceCyclePanelVariant.warning,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            FinanceCycleActionButton(
              keyValue: AppWidgetKeys.financeCycleCreate,
              label: l10n.financeCycleCreate,
              variant: FinanceCycleActionVariant.primary,
              onPressed: isPending ? null : _submit,
              child: isPending
                  ? Semantics(
                      label: l10n.financeCyclesLoadingLabel,
                      child: const SizedBox.square(
                        key: ValueKey(AppWidgetKeys.financeCyclePending),
                        dimension: AppSizes.smallIcon,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            FinanceCycleActionButton(
              keyValue: AppWidgetKeys.financeCycleCancel,
              label: l10n.financeCycleCancel,
              variant: FinanceCycleActionVariant.secondary,
              onPressed: isPending
                  ? null
                  : () => ref
                        .read(
                          financeCyclesWorkflowProvider(widget.farmId).notifier,
                        )
                        .showList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _startsOn ?? _today(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (!context.mounted || selected == null) return;
    setState(() {
      _startsOn = selected;
      if (_endsOn case final end? when end.isBefore(selected)) _endsOn = null;
    });
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final start = _startsOn ?? _today();
    final selected = await showDatePicker(
      context: context,
      initialDate: _endsOn ?? start,
      firstDate: start,
      lastDate: DateTime(2100),
    );
    if (!context.mounted || selected == null) return;
    setState(() => _endsOn = selected);
  }

  void _submit() {
    final purposeId = _purposeId;
    final startsOn = _startsOn;
    if (purposeId == null ||
        startsOn == null ||
        (_endsOn?.isBefore(startsOn) ?? false)) {
      setState(() => _showValidation = true);
      return;
    }
    setState(() => _showValidation = false);
    unawaited(
      ref
          .read(financeCycleCreationProvider(widget.farmId).notifier)
          .create(purposeId: purposeId, startsOn: startsOn, endsOn: _endsOn),
    );
  }
}
