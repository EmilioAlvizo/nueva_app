import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rancho/core/theme/finance_theme.dart';

void main() {
  test('light and dark themes expose intentional semantic colors', () {
    expect(FinanceTheme.dark.positive.accent, const Color(0xFF20CBA5));
    expect(FinanceTheme.dark.negative.accent, const Color(0xFFFF9850));
    expect(FinanceTheme.dark.positiveCardSurface, const Color(0xFF20271F));
    expect(FinanceTheme.dark.negativeCardSurface, const Color(0xFF26231B));
    expect(FinanceTheme.dark.neutralMetricSurface, const Color(0xFF30362B));
    expect(FinanceTheme.dark.consumptionMetricSurface, const Color(0xFFA75A28));
    expect(FinanceTheme.dark.periodSurface, const Color(0xFF687361));
    expect(FinanceTheme.dark.positiveDecoration, const Color(0xD9174B38));
    expect(FinanceTheme.dark.negativeDecoration, const Color(0xD959442E));

    expect(FinanceTheme.light.positive.accent, const Color(0xFF20CBA5));
    expect(FinanceTheme.light.negative.accent, const Color(0xFFFF9850));
    expect(
      FinanceTheme.light.positiveCardSurface,
      isNot(FinanceTheme.dark.positiveCardSurface),
    );
    expect(
      FinanceTheme.light.consumptionMetricSurface,
      isNot(FinanceTheme.dark.consumptionMetricSurface),
    );
    expect(
      FinanceTheme.light.periodSurface,
      isNot(FinanceTheme.dark.periodSurface),
    );
    expect(
      FinanceTheme.light.positiveDecoration,
      isNot(FinanceTheme.light.positive.accent),
    );
    expect(
      FinanceTheme.light.negativeDecoration,
      isNot(FinanceTheme.light.negative.accent),
    );

    for (final theme in [FinanceTheme.light, FinanceTheme.dark]) {
      expect(
        _contrastRatio(theme.positive.accent, theme.positive.onAccent),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(theme.negative.accent, theme.negative.onAccent),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(
          theme.neutralMetricSurface,
          theme.onNeutralMetricSurface,
        ),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(
          theme.consumptionMetricSurface,
          theme.onConsumptionMetricSurface,
        ),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(theme.periodSurface, theme.onPeriodSurface),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  test('copyWith and lerp include every break-even semantic field', () {
    const replacement = Color(0xFF010203);
    final copied = FinanceTheme.light.copyWith(
      positiveCardSurface: replacement,
      negativeCardSurface: replacement,
      unavailableCardSurface: replacement,
      onCard: replacement,
      onCardMuted: replacement,
      neutralMetricSurface: replacement,
      onNeutralMetricSurface: replacement,
      consumptionMetricSurface: replacement,
      onConsumptionMetricSurface: replacement,
      periodSurface: replacement,
      onPeriodSurface: replacement,
      positiveDecoration: replacement,
      negativeDecoration: replacement,
      unavailableDecoration: replacement,
    );

    expect(copied.positiveCardSurface, replacement);
    expect(copied.negativeCardSurface, replacement);
    expect(copied.unavailableCardSurface, replacement);
    expect(copied.onCard, replacement);
    expect(copied.onCardMuted, replacement);
    expect(copied.neutralMetricSurface, replacement);
    expect(copied.onNeutralMetricSurface, replacement);
    expect(copied.consumptionMetricSurface, replacement);
    expect(copied.onConsumptionMetricSurface, replacement);
    expect(copied.periodSurface, replacement);
    expect(copied.onPeriodSurface, replacement);
    expect(copied.positiveDecoration, replacement);
    expect(copied.negativeDecoration, replacement);
    expect(copied.unavailableDecoration, replacement);

    final midpoint = FinanceTheme.light.lerp(FinanceTheme.dark, 0.5);
    expect(
      midpoint.positiveCardSurface,
      Color.lerp(
        FinanceTheme.light.positiveCardSurface,
        FinanceTheme.dark.positiveCardSurface,
        0.5,
      ),
    );
    expect(
      midpoint.consumptionMetricSurface,
      Color.lerp(
        FinanceTheme.light.consumptionMetricSurface,
        FinanceTheme.dark.consumptionMetricSurface,
        0.5,
      ),
    );
    expect(
      midpoint.negativeDecoration,
      Color.lerp(
        FinanceTheme.light.negativeDecoration,
        FinanceTheme.dark.negativeDecoration,
        0.5,
      ),
    );
    expect(
      midpoint.onPeriodSurface,
      Color.lerp(
        FinanceTheme.light.onPeriodSurface,
        FinanceTheme.dark.onPeriodSurface,
        0.5,
      ),
    );
  });
}

double _contrastRatio(Color first, Color second) {
  final lighter = first.computeLuminance() > second.computeLuminance()
      ? first.computeLuminance()
      : second.computeLuminance();
  final darker = first.computeLuminance() > second.computeLuminance()
      ? second.computeLuminance()
      : first.computeLuminance();
  return (lighter + 0.05) / (darker + 0.05);
}
