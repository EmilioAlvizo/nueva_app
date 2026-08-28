import 'package:flutter/material.dart';

enum FinanceTabRole { balance, income, expenses, charts, cycles }

enum FinanceMarginRole { positive, negative, unavailable }

@immutable
final class FinanceAccentPalette {
  const FinanceAccentPalette({
    required this.accent,
    required this.onAccent,
    required this.container,
    required this.onContainer,
  });

  final Color accent;
  final Color onAccent;
  final Color container;
  final Color onContainer;

  static FinanceAccentPalette lerp(
    FinanceAccentPalette a,
    FinanceAccentPalette b,
    double t,
  ) {
    return FinanceAccentPalette(
      accent: Color.lerp(a.accent, b.accent, t) ?? b.accent,
      onAccent: Color.lerp(a.onAccent, b.onAccent, t) ?? b.onAccent,
      container: Color.lerp(a.container, b.container, t) ?? b.container,
      onContainer: Color.lerp(a.onContainer, b.onContainer, t) ?? b.onContainer,
    );
  }
}

@immutable
final class FinanceTheme extends ThemeExtension<FinanceTheme> {
  const FinanceTheme({
    required this.balance,
    required this.income,
    required this.expenses,
    required this.charts,
    required this.cycles,
    required this.positive,
    required this.negative,
    required this.neutral,
    required this.positiveCardSurface,
    required this.negativeCardSurface,
    required this.unavailableCardSurface,
    required this.onCard,
    required this.onCardMuted,
    required this.neutralMetricSurface,
    required this.onNeutralMetricSurface,
    required this.consumptionMetricSurface,
    required this.onConsumptionMetricSurface,
    required this.periodSurface,
    required this.onPeriodSurface,
    required this.positiveDecoration,
    required this.negativeDecoration,
    required this.unavailableDecoration,
    required this.cycleCanvas,
    required this.cycleSurface,
    required this.cycleSurfaceElevated,
    required this.cycleInputSurface,
    required this.cyclePrimaryAction,
    required this.cycleAbierto,
    required this.cycleOnAbierto,
    required this.cycleOnPrimaryAction,
    required this.cycleDestructiveAction,
    required this.cycleOnDestructiveAction,
    required this.cyclePositiveAction,
    required this.cycleOnPositiveAction,
    required this.cycleOnSurface,
    required this.cycleOnSurfaceMuted,
    required this.cycleOutline,
  });

  static var light = FinanceTheme(
    balance: FinanceAccentPalette(
      accent: Color(0xFFFF974D),
      onAccent: Color(0xFF351600),
      container: Color(0xFFFFE3CE),
      onContainer: Color(0xFF512200),
    ),
    income: FinanceAccentPalette(
      accent: Color(0xFF4DCE75),
      onAccent: Color(0xFF082814),
      container: Color(0xFFD8F6E1),
      onContainer: Color(0xFF0D4622),
    ),
    expenses: FinanceAccentPalette(
      accent: Color(0xFFFF3038),
      onAccent: Color(0xFF330004),
      container: Color(0xFFFFDADC),
      onContainer: Color(0xFF61000A),
    ),
    charts: FinanceAccentPalette(
      accent: Color(0xFF50D8C9),
      onAccent: Color(0xFF062C28),
      container: Color(0xFFD1F5F0),
      onContainer: Color(0xFF084B44),
    ),
    cycles: FinanceAccentPalette(
      accent: Color(0xFFFF994A),
      onAccent: Color(0xFF2E1604),
      container: Color(0xFF4C321D),
      onContainer: Color(0xFFFFE9D6),
    ),
    positive: FinanceAccentPalette(
      accent: Color(0xFF20CBA5),
      onAccent: Color(0xFF062A22),
      container: Color(0xFFCDEFE5),
      onContainer: Color(0xFF12483B),
    ),
    negative: FinanceAccentPalette(
      accent: Color(0xFFFF9850),
      onAccent: Color(0xFF381700),
      container: Color(0xFFFFDFC8),
      onContainer: Color(0xFF5B2600),
    ),
    neutral: FinanceAccentPalette(
      accent: Color(0xFF68645A),
      onAccent: Color(0xFFFFFFFF),
      container: Color(0xFFE4E1D7),
      onContainer: Color(0xFF34322D),
    ),
    positiveCardSurface: Color(0xFFF0F2E6),
    negativeCardSurface: Color(0xFFF4EEE2),
    unavailableCardSurface: Color(0xFFF1F0E8),
    onCard: Color(0xFF26271F),
    onCardMuted: Color(0xFF6D685C),
    neutralMetricSurface: Color(0xFFDFE2D3),
    onNeutralMetricSurface: Color(0xFF292D24),
    consumptionMetricSurface: Color(0xFFDFA477),
    onConsumptionMetricSurface: Color(0xFF3B1C0A),
    periodSurface: Color(0xFFCDD5C5),
    onPeriodSurface: Color(0xFF253024),
    positiveDecoration: Color(0xD9C8E8D8),
    negativeDecoration: Color(0xD9E8D2B8),
    unavailableDecoration: Color(0xD9D9D7C8),
    cycleCanvas: Color(0xFF0D1117),
    cycleSurface: Color(0xFF242921),
    cycleSurfaceElevated: Color(0xFF30362B),
    cycleInputSurface: Color(0xFF30362B),
    cyclePrimaryAction: Color(0xFFFF994A),
    cycleAbierto: Color(0xFFFF994A),
    cycleOnAbierto: Color(0xFF0FC78C),
    cycleOnPrimaryAction: Color(0xFF2E1604),
    cycleDestructiveAction: Color(0xFFC76733),
    cycleOnDestructiveAction: Color(0xFFFFF1E8),
    cyclePositiveAction: Color(0xFF32C7AC),
    cycleOnPositiveAction: Color(0xFF062D26),
    cycleOnSurface: Color(0xFFF6F0E4),
    cycleOnSurfaceMuted: Color(0xFFC2B8A4),
    cycleOutline: Color.fromARGB(0, 98, 104, 78),
  );

  static var dark = FinanceTheme(
    balance: FinanceAccentPalette(
      accent: Color(0xFFFFAD70),
      onAccent: Color(0xFF3B1900),
      container: Color(0xFF673711),
      onContainer: Color(0xFFFFE1CB),
    ),
    income: FinanceAccentPalette(
      accent: Color(0xFF69DB8C),
      onAccent: Color(0xFF062A14),
      container: Color(0xFF174B2A),
      onContainer: Color(0xFFCFF7D9),
    ),
    expenses: FinanceAccentPalette(
      accent: Color(0xFFFF666C),
      onAccent: Color(0xFF3B0005),
      container: Color(0xFF6B171C),
      onContainer: Color(0xFFFFDADB),
    ),
    charts: FinanceAccentPalette(
      accent: Color(0xFF70E3D6),
      onAccent: Color(0xFF003732),
      container: Color(0xFF15504A),
      onContainer: Color(0xFFCCF8F2),
    ),
    cycles: FinanceAccentPalette(
      accent: Color(0xFFFF994A),
      onAccent: Color(0xFF2E1604),
      container: Color(0xFF4C321D),
      onContainer: Color(0xFFFFE9D6),
    ),
    positive: FinanceAccentPalette(
      accent: Color(0xFF20CBA5),
      onAccent: Color(0xFF062A22),
      container: Color(0xFF174B38),
      onContainer: Color(0xFFD6F7EC),
    ),
    negative: FinanceAccentPalette(
      accent: Color(0xFFFF9850),
      onAccent: Color(0xFF381700),
      container: Color(0xFF59442E),
      onContainer: Color(0xFFFFE7D5),
    ),
    neutral: FinanceAccentPalette(
      accent: Color(0xFF9A9B8D),
      onAccent: Color(0xFF20211C),
      container: Color(0xFF45483F),
      onContainer: Color(0xFFF0EFE5),
    ),
    positiveCardSurface: Color(0xFF20271F),
    negativeCardSurface: Color(0xFF26231B),
    unavailableCardSurface: Color(0xFF25251F),
    onCard: Color(0xFFF5F1E8),
    onCardMuted: Color(0xFFBEB5A6),
    neutralMetricSurface: Color(0xFF30362B),
    onNeutralMetricSurface: Color(0xFFF4F1E7),
    consumptionMetricSurface: Color(0xFFA75A28),
    onConsumptionMetricSurface: Color(0xFFFFF3E8),
    periodSurface: Color(0xFF687361),
    onPeriodSurface: Color(0xFFFFFCF3),
    positiveDecoration: Color(0xD9174B38),
    negativeDecoration: Color(0xD959442E),
    unavailableDecoration: Color(0xD945483F),
    cycleCanvas: Color(0xFF0D1117),
    cycleSurface: Color(0xFF242921),
    cycleSurfaceElevated: Color(0xFF30362B),
    cycleInputSurface: Color(0xFF30362B),
    cyclePrimaryAction: Color(0xFFFF994A),
    cycleAbierto: Color(0xFF124F3D),
    cycleOnAbierto: Color(0xFF0FC78C),
    cycleOnPrimaryAction: Color(0xFF2E1604),
    cycleDestructiveAction: Color(0xFFC76733),
    cycleOnDestructiveAction: Color(0xFFFFF1E8),
    cyclePositiveAction: Color(0xFF32C7AC),
    cycleOnPositiveAction: Color(0xFF062D26),
    cycleOnSurface: Color(0xFFF6F0E4),
    cycleOnSurfaceMuted: Color(0xFFC2B8A4),
    cycleOutline: Color.fromARGB(0, 98, 104, 78),
  );

  final FinanceAccentPalette balance;
  final FinanceAccentPalette income;
  final FinanceAccentPalette expenses;
  final FinanceAccentPalette charts;
  final FinanceAccentPalette cycles;
  final FinanceAccentPalette positive;
  final FinanceAccentPalette negative;
  final FinanceAccentPalette neutral;
  final Color positiveCardSurface;
  final Color negativeCardSurface;
  final Color unavailableCardSurface;
  final Color onCard;
  final Color onCardMuted;
  final Color neutralMetricSurface;
  final Color onNeutralMetricSurface;
  final Color consumptionMetricSurface;
  final Color onConsumptionMetricSurface;
  final Color periodSurface;
  final Color onPeriodSurface;
  final Color positiveDecoration;
  final Color negativeDecoration;
  final Color unavailableDecoration;
  final Color cycleCanvas;
  final Color cycleSurface;
  final Color cycleSurfaceElevated;
  final Color cycleInputSurface;
  final Color cyclePrimaryAction;
  final Color cycleAbierto;
  final Color cycleOnAbierto;
  final Color cycleOnPrimaryAction;
  final Color cycleDestructiveAction;
  final Color cycleOnDestructiveAction;
  final Color cyclePositiveAction;
  final Color cycleOnPositiveAction;
  final Color cycleOnSurface;
  final Color cycleOnSurfaceMuted;
  final Color cycleOutline;

  static FinanceTheme of(BuildContext context) {
    return switch (Theme.of(context).extension<FinanceTheme>()) {
      final theme? => theme,
      null => Theme.of(context).brightness == Brightness.dark ? dark : light,
    };
  }

  FinanceAccentPalette tabPalette(FinanceTabRole role) => switch (role) {
    FinanceTabRole.balance => balance,
    FinanceTabRole.income => income,
    FinanceTabRole.expenses => expenses,
    FinanceTabRole.charts => charts,
    FinanceTabRole.cycles => cycles,
  };

  FinanceAccentPalette marginPalette(FinanceMarginRole role) => switch (role) {
    FinanceMarginRole.positive => positive,
    FinanceMarginRole.negative => negative,
    FinanceMarginRole.unavailable => neutral,
  };

  Color breakEvenCardSurface(FinanceMarginRole role) => switch (role) {
    FinanceMarginRole.positive => positiveCardSurface,
    FinanceMarginRole.negative => negativeCardSurface,
    FinanceMarginRole.unavailable => unavailableCardSurface,
  };

  Color breakEvenDecoration(FinanceMarginRole role) => switch (role) {
    FinanceMarginRole.positive => positiveDecoration,
    FinanceMarginRole.negative => negativeDecoration,
    FinanceMarginRole.unavailable => unavailableDecoration,
  };

  @override
  FinanceTheme copyWith({
    FinanceAccentPalette? balance,
    FinanceAccentPalette? income,
    FinanceAccentPalette? expenses,
    FinanceAccentPalette? charts,
    FinanceAccentPalette? cycles,
    FinanceAccentPalette? positive,
    FinanceAccentPalette? negative,
    FinanceAccentPalette? neutral,
    Color? positiveCardSurface,
    Color? negativeCardSurface,
    Color? unavailableCardSurface,
    Color? onCard,
    Color? onCardMuted,
    Color? neutralMetricSurface,
    Color? onNeutralMetricSurface,
    Color? consumptionMetricSurface,
    Color? onConsumptionMetricSurface,
    Color? periodSurface,
    Color? onPeriodSurface,
    Color? positiveDecoration,
    Color? negativeDecoration,
    Color? unavailableDecoration,
    Color? cycleCanvas,
    Color? cycleSurface,
    Color? cycleSurfaceElevated,
    Color? cycleInputSurface,
    Color? cyclePrimaryAction,
    Color? cycleOnPrimaryAction,
    Color? cycleDestructiveAction,
    Color? cycleOnDestructiveAction,
    Color? cyclePositiveAction,
    Color? cycleOnPositiveAction,
    Color? cycleOnSurface,
    Color? cycleOnSurfaceMuted,
    Color? cycleOutline,
  }) {
    return FinanceTheme(
      balance: balance ?? this.balance,
      income: income ?? this.income,
      expenses: expenses ?? this.expenses,
      charts: charts ?? this.charts,
      cycles: cycles ?? this.cycles,
      positive: positive ?? this.positive,
      negative: negative ?? this.negative,
      neutral: neutral ?? this.neutral,
      positiveCardSurface: positiveCardSurface ?? this.positiveCardSurface,
      negativeCardSurface: negativeCardSurface ?? this.negativeCardSurface,
      unavailableCardSurface:
          unavailableCardSurface ?? this.unavailableCardSurface,
      onCard: onCard ?? this.onCard,
      onCardMuted: onCardMuted ?? this.onCardMuted,
      neutralMetricSurface: neutralMetricSurface ?? this.neutralMetricSurface,
      onNeutralMetricSurface:
          onNeutralMetricSurface ?? this.onNeutralMetricSurface,
      consumptionMetricSurface:
          consumptionMetricSurface ?? this.consumptionMetricSurface,
      onConsumptionMetricSurface:
          onConsumptionMetricSurface ?? this.onConsumptionMetricSurface,
      periodSurface: periodSurface ?? this.periodSurface,
      onPeriodSurface: onPeriodSurface ?? this.onPeriodSurface,
      positiveDecoration: positiveDecoration ?? this.positiveDecoration,
      negativeDecoration: negativeDecoration ?? this.negativeDecoration,
      unavailableDecoration:
          unavailableDecoration ?? this.unavailableDecoration,
      cycleCanvas: cycleCanvas ?? this.cycleCanvas,
      cycleSurface: cycleSurface ?? this.cycleSurface,
      cycleSurfaceElevated: cycleSurfaceElevated ?? this.cycleSurfaceElevated,
      cycleInputSurface: cycleInputSurface ?? this.cycleInputSurface,
      cyclePrimaryAction: cyclePrimaryAction ?? this.cyclePrimaryAction,
      cycleAbierto: cycleAbierto ?? this.cycleAbierto,
      cycleOnAbierto: cycleOnAbierto ?? this.cycleOnAbierto,
      cycleOnPrimaryAction: cycleOnPrimaryAction ?? this.cycleOnPrimaryAction,
      cycleDestructiveAction:
          cycleDestructiveAction ?? this.cycleDestructiveAction,
      cycleOnDestructiveAction:
          cycleOnDestructiveAction ?? this.cycleOnDestructiveAction,
      cyclePositiveAction: cyclePositiveAction ?? this.cyclePositiveAction,
      cycleOnPositiveAction:
          cycleOnPositiveAction ?? this.cycleOnPositiveAction,
      cycleOnSurface: cycleOnSurface ?? this.cycleOnSurface,
      cycleOnSurfaceMuted: cycleOnSurfaceMuted ?? this.cycleOnSurfaceMuted,
      cycleOutline: cycleOutline ?? this.cycleOutline,
    );
  }

  @override
  FinanceTheme lerp(covariant FinanceTheme? other, double t) {
    if (other == null) return this;
    return FinanceTheme(
      balance: FinanceAccentPalette.lerp(balance, other.balance, t),
      income: FinanceAccentPalette.lerp(income, other.income, t),
      expenses: FinanceAccentPalette.lerp(expenses, other.expenses, t),
      charts: FinanceAccentPalette.lerp(charts, other.charts, t),
      cycles: FinanceAccentPalette.lerp(cycles, other.cycles, t),
      positive: FinanceAccentPalette.lerp(positive, other.positive, t),
      negative: FinanceAccentPalette.lerp(negative, other.negative, t),
      neutral: FinanceAccentPalette.lerp(neutral, other.neutral, t),
      positiveCardSurface:
          Color.lerp(positiveCardSurface, other.positiveCardSurface, t) ??
          positiveCardSurface,
      negativeCardSurface:
          Color.lerp(negativeCardSurface, other.negativeCardSurface, t) ??
          negativeCardSurface,
      unavailableCardSurface:
          Color.lerp(unavailableCardSurface, other.unavailableCardSurface, t) ??
          unavailableCardSurface,
      onCard: Color.lerp(onCard, other.onCard, t) ?? onCard,
      onCardMuted: Color.lerp(onCardMuted, other.onCardMuted, t) ?? onCardMuted,
      neutralMetricSurface:
          Color.lerp(neutralMetricSurface, other.neutralMetricSurface, t) ??
          neutralMetricSurface,
      onNeutralMetricSurface:
          Color.lerp(onNeutralMetricSurface, other.onNeutralMetricSurface, t) ??
          onNeutralMetricSurface,
      consumptionMetricSurface:
          Color.lerp(
            consumptionMetricSurface,
            other.consumptionMetricSurface,
            t,
          ) ??
          consumptionMetricSurface,
      onConsumptionMetricSurface:
          Color.lerp(
            onConsumptionMetricSurface,
            other.onConsumptionMetricSurface,
            t,
          ) ??
          onConsumptionMetricSurface,
      periodSurface:
          Color.lerp(periodSurface, other.periodSurface, t) ?? periodSurface,
      onPeriodSurface:
          Color.lerp(onPeriodSurface, other.onPeriodSurface, t) ??
          onPeriodSurface,
      positiveDecoration:
          Color.lerp(positiveDecoration, other.positiveDecoration, t) ??
          positiveDecoration,
      negativeDecoration:
          Color.lerp(negativeDecoration, other.negativeDecoration, t) ??
          negativeDecoration,
      unavailableDecoration:
          Color.lerp(unavailableDecoration, other.unavailableDecoration, t) ??
          unavailableDecoration,
      cycleCanvas: Color.lerp(cycleCanvas, other.cycleCanvas, t) ?? cycleCanvas,
      cycleSurface:
          Color.lerp(cycleSurface, other.cycleSurface, t) ?? cycleSurface,
      cycleSurfaceElevated:
          Color.lerp(cycleSurfaceElevated, other.cycleSurfaceElevated, t) ??
          cycleSurfaceElevated,
      cycleInputSurface:
          Color.lerp(cycleInputSurface, other.cycleInputSurface, t) ??
          cycleInputSurface,
      cyclePrimaryAction:
          Color.lerp(cyclePrimaryAction, other.cyclePrimaryAction, t) ??
          cyclePrimaryAction,
      cycleAbierto:
          Color.lerp(cycleAbierto, other.cycleAbierto, t) ??
          cycleAbierto,
      cycleOnAbierto:
          Color.lerp(cycleOnAbierto, other.cycleOnAbierto, t) ??
          cycleOnAbierto,
      cycleOnPrimaryAction:
          Color.lerp(cycleOnPrimaryAction, other.cycleOnPrimaryAction, t) ??
          cycleOnPrimaryAction,
      cycleDestructiveAction:
          Color.lerp(cycleDestructiveAction, other.cycleDestructiveAction, t) ??
          cycleDestructiveAction,
      cycleOnDestructiveAction:
          Color.lerp(
            cycleOnDestructiveAction,
            other.cycleOnDestructiveAction,
            t,
          ) ??
          cycleOnDestructiveAction,
      cyclePositiveAction:
          Color.lerp(cyclePositiveAction, other.cyclePositiveAction, t) ??
          cyclePositiveAction,
      cycleOnPositiveAction:
          Color.lerp(cycleOnPositiveAction, other.cycleOnPositiveAction, t) ??
          cycleOnPositiveAction,
      cycleOnSurface:
          Color.lerp(cycleOnSurface, other.cycleOnSurface, t) ?? cycleOnSurface,
      cycleOnSurfaceMuted:
          Color.lerp(cycleOnSurfaceMuted, other.cycleOnSurfaceMuted, t) ??
          cycleOnSurfaceMuted,
      cycleOutline:
          Color.lerp(cycleOutline, other.cycleOutline, t) ?? cycleOutline,
    );
  }
}
