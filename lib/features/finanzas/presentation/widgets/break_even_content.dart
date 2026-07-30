import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_layout.dart';
import 'break_even_card.dart';

class BreakEvenContent extends StatelessWidget {
  const BreakEvenContent({
    required this.title,
    required this.subtitle,
    required this.cards,
    required this.onRefresh,
    super.key,
  });

  final String title;
  final String subtitle;
  final List<BreakEvenCardViewData> cards;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(constraints.maxWidth, AppSizes.maxContentWidth);
        final columns = width >= AppSizes.expandedBreakpoint
            ? 3
            : width >= AppSizes.mediumBreakpoint
            ? 2
            : 1;
        final cardWidth = (width - (columns - 1) * AppSpacing.md) / columns;

        return RefreshIndicator(
          onRefresh: onRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            child: Center(
              child: SizedBox(
                width: width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.md,
                      children: [
                        for (final card in cards)
                          SizedBox(
                            width: cardWidth,
                            child: BreakEvenCard(data: card),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
