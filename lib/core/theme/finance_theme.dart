import 'package:flutter/material.dart';

enum FinanceTabRole { balance, income, expenses, charts }

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
    required this.positive,
    required this.negative,
    required this.neutral,
    required this.cardSurface,
    required this.onCard,
    required this.onCardMuted,
    required this.metricSurface,
    required this.dateStrip,
    required this.decoration,
  });

  static const light = FinanceTheme(
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
    positive: FinanceAccentPalette(
      accent: Color(0xFF248F4A),
      onAccent: Color(0xFFFFFFFF),
      container: Color(0xFFD5F5DE),
      onContainer: Color(0xFF0A4B24),
    ),
    negative: FinanceAccentPalette(
      accent: Color(0xFFE87521),
      onAccent: Color(0xFF321300),
      container: Color(0xFFFFE0C8),
      onContainer: Color(0xFF5A2100),
    ),
    neutral: FinanceAccentPalette(
      accent: Color(0xFF8B735E),
      onAccent: Color(0xFFFFFFFF),
      container: Color(0xFFF3E4D8),
      onContainer: Color(0xFF443225),
    ),
    cardSurface: Color(0xFFF3F2E8),
    onCard: Color(0xFF22251D),
    onCardMuted: Color(0xFF5A6051),
    metricSurface: Color(0xFFFFFDF5),
    dateStrip: Color(0xFFE4E4D2),
    decoration: Color(0xFF9DA66F),
  );

  static const dark = FinanceTheme(
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
    positive: FinanceAccentPalette(
      accent: Color(0xFF63DA86),
      onAccent: Color(0xFF062A14),
      container: Color(0xFF174B2A),
      onContainer: Color(0xFFCFF7D9),
    ),
    negative: FinanceAccentPalette(
      accent: Color(0xFFFFAB70),
      onAccent: Color(0xFF3A1800),
      container: Color(0xFF63310F),
      onContainer: Color(0xFFFFE1CC),
    ),
    neutral: FinanceAccentPalette(
      accent: Color(0xFFD5A777),
      onAccent: Color(0xFF382513),
      container: Color(0xFF4C3828),
      onContainer: Color(0xFFF9E5D0),
    ),
    cardSurface: Color(0xFF292D23),
    onCard: Color(0xFFF2F4E9),
    onCardMuted: Color(0xFFBBC1AE),
    metricSurface: Color(0xFF373C30),
    dateStrip: Color(0xFF1F231C),
    decoration: Color(0xFF85905D),
  );

  final FinanceAccentPalette balance;
  final FinanceAccentPalette income;
  final FinanceAccentPalette expenses;
  final FinanceAccentPalette charts;
  final FinanceAccentPalette positive;
  final FinanceAccentPalette negative;
  final FinanceAccentPalette neutral;
  final Color cardSurface;
  final Color onCard;
  final Color onCardMuted;
  final Color metricSurface;
  final Color dateStrip;
  final Color decoration;

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
  };

  FinanceAccentPalette marginPalette(FinanceMarginRole role) => switch (role) {
    FinanceMarginRole.positive => positive,
    FinanceMarginRole.negative => negative,
    FinanceMarginRole.unavailable => neutral,
  };

  @override
  FinanceTheme copyWith({
    FinanceAccentPalette? balance,
    FinanceAccentPalette? income,
    FinanceAccentPalette? expenses,
    FinanceAccentPalette? charts,
    FinanceAccentPalette? positive,
    FinanceAccentPalette? negative,
    FinanceAccentPalette? neutral,
    Color? cardSurface,
    Color? onCard,
    Color? onCardMuted,
    Color? metricSurface,
    Color? dateStrip,
    Color? decoration,
  }) {
    return FinanceTheme(
      balance: balance ?? this.balance,
      income: income ?? this.income,
      expenses: expenses ?? this.expenses,
      charts: charts ?? this.charts,
      positive: positive ?? this.positive,
      negative: negative ?? this.negative,
      neutral: neutral ?? this.neutral,
      cardSurface: cardSurface ?? this.cardSurface,
      onCard: onCard ?? this.onCard,
      onCardMuted: onCardMuted ?? this.onCardMuted,
      metricSurface: metricSurface ?? this.metricSurface,
      dateStrip: dateStrip ?? this.dateStrip,
      decoration: decoration ?? this.decoration,
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
      positive: FinanceAccentPalette.lerp(positive, other.positive, t),
      negative: FinanceAccentPalette.lerp(negative, other.negative, t),
      neutral: FinanceAccentPalette.lerp(neutral, other.neutral, t),
      cardSurface: Color.lerp(cardSurface, other.cardSurface, t) ?? cardSurface,
      onCard: Color.lerp(onCard, other.onCard, t) ?? onCard,
      onCardMuted: Color.lerp(onCardMuted, other.onCardMuted, t) ?? onCardMuted,
      metricSurface:
          Color.lerp(metricSurface, other.metricSurface, t) ?? metricSurface,
      dateStrip: Color.lerp(dateStrip, other.dateStrip, t) ?? dateStrip,
      decoration: Color.lerp(decoration, other.decoration, t) ?? decoration,
    );
  }
}
