import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rancho/core/testing/app_widget_keys.dart';
import 'package:rancho/core/theme/app_layout.dart';
import 'package:rancho/core/theme/app_theme.dart';
import 'package:rancho/core/theme/finance_theme.dart';
import 'package:rancho/features/finanzas/presentation/widgets/meat_break_even_card.dart';
import 'package:rancho/l10n/app_localizations.dart';

void main() {
  testWidgets('renders the featured meat hierarchy and geometry', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await _pumpCard(tester, data: _data);

    final card = _key(AppWidgetKeys.financeMeatBreakEvenCard(_data.cycleId));
    final ring = _key(AppWidgetKeys.financeMeatBreakEvenRing(_data.cycleId));
    final chip = _key(AppWidgetKeys.financeMeatBreakEvenChip(_data.cycleId));
    final costs = _key(AppWidgetKeys.financeMeatBreakEvenCosts(_data.cycleId));
    final revenue = _key(
      AppWidgetKeys.financeMeatBreakEvenRevenue(_data.cycleId),
    );
    final metrics = _key(
      AppWidgetKeys.financeMeatBreakEvenMetrics(_data.cycleId),
    );
    final footer = _key(
      AppWidgetKeys.financeMeatBreakEvenFooter(_data.cycleId),
    );
    final decoration = _key(
      AppWidgetKeys.financeMeatBreakEvenDecoration(_data.cycleId),
    );

    expect(find.text('Engorda · Corral sur'), findsOneWidget);
    expect(
      find.text('Resultado económico acumulado del ciclo'),
      findsOneWidget,
    );
    expect(find.text('Punto de equilibrio'), findsOneWidget);
    expect(find.text(r'-$18.75'), findsOneWidget);
    expect(find.text(r'$325'), findsOneWidget);
    expect(find.text(r'$200'), findsOneWidget);
    expect(find.text(r'$125'), findsOneWidget);
    expect(find.text(r'$250'), findsOneWidget);
    expect(find.text(r'$/animal'), findsOneWidget);
    expect(find.text('Gastos totales'), findsOneWidget);
    expect(find.text('Alimento'), findsOneWidget);
    expect(find.text('Extras'), findsOneWidget);
    expect(find.text('Ingresos ventas'), findsOneWidget);
    expect(
      find.text('4 animales • 2 ventas • 10 kg de alimento'),
      findsOneWidget,
    );
    expect(find.text('20 ago 2026 → 20 sept 2026 · 32 días'), findsOneWidget);

    final cardRect = tester.getRect(card);
    final ringRect = tester.getRect(ring);
    final titleRect = tester.getRect(find.text('Engorda · Corral sur'));
    final chipRect = tester.getRect(chip);
    final subtitleRect = tester.getRect(
      find.text('Resultado económico acumulado del ciclo'),
    );
    final costsRect = tester.getRect(costs);
    final revenueRect = tester.getRect(revenue);
    final divider = find.descendant(
      of: costs,
      matching: find.byType(VerticalDivider),
    );
    final dividerRect = tester.getRect(divider);
    final totalCostRect = tester.getRect(find.text(r'$325'));
    final feedRect = tester.getRect(find.text('Alimento'));
    final revenueValueRect = tester.getRect(find.text(r'$250'));
    final revenueLabelRect = tester.getRect(find.text('Ingresos ventas'));
    final metricsRect = tester.getRect(metrics);
    final footerRect = tester.getRect(footer);
    final decorationRect = tester.getRect(decoration);

    expect(ringRect.center.dx, lessThan(titleRect.center.dx));
    expect(chipRect.top, greaterThan(subtitleRect.bottom));
    expect(costsRect.right, lessThan(revenueRect.left));
    expect(totalCostRect.right, lessThan(dividerRect.center.dx));
    expect(dividerRect.center.dx, lessThan(feedRect.left));
    expect(
      find.descendant(of: costs, matching: find.byType(Divider)),
      findsNothing,
    );
    expect(revenueValueRect.center.dx, closeTo(revenueRect.center.dx, 0.01));
    expect(revenueLabelRect.center.dx, closeTo(revenueRect.center.dx, 0.01));
    expect(
      (revenueValueRect.top + revenueLabelRect.bottom) / 2,
      closeTo(revenueRect.center.dy, 0.01),
    );
    expect(
      metricsRect.top,
      greaterThan(math.max(costsRect.bottom, revenueRect.bottom)),
    );
    expect(footerRect.left, closeTo(cardRect.left, 0.01));
    expect(footerRect.right, closeTo(cardRect.right, 0.01));
    expect(footerRect.bottom, closeTo(cardRect.bottom, 0.01));
    expect(decorationRect.top, lessThan(cardRect.top));
    expect(decorationRect.right, greaterThan(cardRect.right));

    final finance = FinanceTheme.of(tester.element(card));
    final cardWidget = tester.widget<Card>(
      find.descendant(of: card, matching: find.byType(Card)),
    );
    expect(cardWidget.color, finance.cycleSurface);
    expect(_decoration(tester, revenue).color, finance.cyclePositiveAction);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stacks only when compact and remains readable at 2x text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 1400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await _pumpCard(tester, data: _data, textScale: 2);

    final card = _key(AppWidgetKeys.financeMeatBreakEvenCard(_data.cycleId));
    final ring = _key(AppWidgetKeys.financeMeatBreakEvenRing(_data.cycleId));
    final costs = _key(AppWidgetKeys.financeMeatBreakEvenCosts(_data.cycleId));
    final revenue = _key(
      AppWidgetKeys.financeMeatBreakEvenRevenue(_data.cycleId),
    );
    final divider = find.descendant(
      of: costs,
      matching: find.byType(VerticalDivider),
    );

    expect(
      tester.getRect(ring).center.dx,
      lessThan(tester.getRect(card).center.dx),
    );
    expect(tester.getRect(costs).bottom, lessThan(tester.getRect(revenue).top));
    expect(divider, findsOneWidget);
    expect(
      tester.getRect(find.text(r'$325')).right,
      lessThan(tester.getRect(divider).center.dx),
    );
    expect(
      tester.getRect(divider).center.dx,
      lessThan(tester.getRect(find.text('Alimento')).left),
    );
    expect(tester.takeException(), isNull);
  });
}

Finder _key(String value) => find.byKey(ValueKey(value));

BoxDecoration _decoration(WidgetTester tester, Finder finder) {
  return tester.widget<DecoratedBox>(finder).decoration as BoxDecoration;
}

Future<void> _pumpCard(
  WidgetTester tester, {
  required MeatBreakEvenCardViewData data,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: MeatBreakEvenCard(data: data),
        ),
      ),
    ),
  );
  await tester.pump();
}

const _data = MeatBreakEvenCardViewData(
  cycleId: 'cycle-meat',
  title: 'Engorda · Corral sur',
  subtitle: 'Resultado económico acumulado del ciclo',
  breakEvenLabel: 'Punto de equilibrio',
  resultValue: r'-$18.75',
  resultUnit: r'$/animal',
  totalCostValue: r'$325',
  totalCostsLabel: 'Gastos totales',
  feedLabel: 'Alimento',
  feedValue: r'$200',
  extrasLabel: 'Extras',
  extrasValue: r'$125',
  revenueValue: r'$250',
  revenueLabel: 'Ingresos ventas',
  metricsText: '4 animales • 2 ventas • 10 kg de alimento',
  footerText: '20 ago 2026 → 20 sept 2026 · 32 días',
  semanticsLabel: 'Resumen accesible del ciclo de carne',
);
