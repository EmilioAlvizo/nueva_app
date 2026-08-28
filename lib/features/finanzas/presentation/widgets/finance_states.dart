import 'package:flutter/material.dart';

import '../../../../core/theme/app_layout.dart';

class FinanceMessageState extends StatelessWidget {
  const FinanceMessageState({
    required this.title,
    required this.message,
    required this.asset,
    this.note,
    this.actionKey,
    this.actionLabel,
    this.onAction,
    this.actionIcon = Icons.refresh_rounded,
    super.key,
  });

  final String title;
  final String message;
  final String asset;
  final String? note;
  final String? actionKey;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData actionIcon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSizes.mediumBreakpoint,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: AppSizes.stateImage,
                height: AppSizes.stateImage,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: colors.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Image.asset(asset, excludeFromSemantics: true),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
              ),
              if (note case final noteValue?) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  noteValue,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
              if (actionLabel case final label?) ...[
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  key: actionKey == null ? null : ValueKey<String>(actionKey!),
                  onPressed: onAction,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(
                      AppSizes.minTapTarget,
                      AppSizes.minTapTarget,
                    ),
                  ),
                  icon: Icon(actionIcon),
                  label: Text(label),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
