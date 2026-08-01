import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rancho/core/testing/app_widget_keys.dart';
import 'package:rancho/core/theme/app_layout.dart';
import 'package:rancho/core/theme/app_theme.dart';
import 'package:rancho/core/theme/finance_theme.dart';
import 'package:rancho/features/finanzas/presentation/widgets/break_even_card.dart';
import 'package:rancho/l10n/app_localizations.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final testCase in [
      (role: FinanceMarginRole.positive, margin: 'Margen +20.00 %'),
      (role: FinanceMarginRole.negative, margin: 'Margen -39.37 %'),
    ]) {
      testWidgets(
        '${brightness.name} ${testCase.role.name} uses the semantic card palette',
        (tester) async {
          await _pumpCard(
            tester,
            role: testCase.role,
            margin: testCase.margin,
            brightness: brightness,
          );

          final theme = FinanceTheme.of(
            tester.element(
              find.byKey(ValueKey(AppWidgetKeys.financeMarginChip(_mixtureId))),
            ),
          );
          final palette = theme.marginPalette(testCase.role);

          final card = tester.widget<Card>(find.byType(Card));
          expect(card.color, theme.breakEvenCardSurface(testCase.role));

          final ring = tester.widget<DecoratedBox>(
            find.byKey(
              ValueKey(
                AppWidgetKeys.financeBreakEvenPriceIndicator(_mixtureId),
              ),
            ),
          );
          final ringDecoration = ring.decoration as BoxDecoration;
          expect(ringDecoration.border!.top.color, palette.accent);
          expect(
            ringDecoration.border!.top.width,
            AppSizes.financePriceRingStroke,
          );

          final chip = tester.widget<DecoratedBox>(
            find.byKey(ValueKey(AppWidgetKeys.financeMarginChip(_mixtureId))),
          );
          expect((chip.decoration as BoxDecoration).color, palette.accent);
          expect(
            tester.widget<Text>(find.text(testCase.margin)).style!.color,
            palette.onAccent,
          );

          final decoration = tester.widget<DecoratedBox>(
            find.byKey(
              ValueKey(AppWidgetKeys.financeBreakEvenDecoration(_mixtureId)),
            ),
          );
          final decorationColor =
              (decoration.decoration as BoxDecoration).color;
          expect(decorationColor, theme.breakEvenDecoration(testCase.role));
          expect(decorationColor, isNot(palette.accent));

          final neutralSurface = theme.neutralMetricSurface;
          final costTile = _tileDecoration(tester, FinanceMetricRole.cost);
          final eggsTile = _tileDecoration(tester, FinanceMetricRole.eggs);
          final consumptionTile = _tileDecoration(
            tester,
            FinanceMetricRole.consumption,
          );
          expect(costTile.color, neutralSurface);
          expect(eggsTile.color, neutralSurface);
          expect(consumptionTile.color, theme.consumptionMetricSurface);
          expect(consumptionTile.color, isNot(palette.accent));

          final period = tester.widget<DecoratedBox>(
            find.byKey(
              ValueKey(AppWidgetKeys.financeBreakEvenPeriod(_mixtureId)),
            ),
          );
          expect(
            (period.decoration as BoxDecoration).color,
            theme.periodSurface,
          );
          const periodText = '13 ene 2026 – 28 abr 2026 · 105 días';
          expect(find.text(periodText), findsOneWidget);
          expect(
            tester.widget<Text>(find.text(periodText)).style!.color,
            theme.onPeriodSurface,
          );
          expect(find.text('Duración'), findsNothing);
          expect(find.byIcon(Icons.calendar_month_outlined), findsNothing);

          final semantics = tester.getSemantics(
            find.byKey(
              ValueKey(AppWidgetKeys.financeBreakEvenCard(_mixtureId)),
            ),
          );
          expect(semantics.label, contains('Gallinero'));
          expect(semantics.label, contains(testCase.margin));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('keeps the reference typography hierarchy and dimensions', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 1200);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await _pumpCard(
      tester,
      role: FinanceMarginRole.positive,
      margin: 'Margen +20.00 %',
    );

    expect(
      tester.getSize(
        find.byKey(
          ValueKey(AppWidgetKeys.financeBreakEvenPriceIndicator(_mixtureId)),
        ),
      ),
      const Size.square(AppSizes.financePriceRing),
    );
    final card = tester.widget<Card>(find.byType(Card));
    final cardShape = card.shape! as RoundedRectangleBorder;
    expect(
      cardShape.borderRadius,
      BorderRadius.circular(AppSizes.financeCardRadius),
    );
    final periodFinder = find.byKey(
      ValueKey(AppWidgetKeys.financeBreakEvenPeriod(_mixtureId)),
    );
    expect(
      tester.getSize(periodFinder).height,
      AppSizes.financePeriodMinHeight,
    );
    expect(
      tester.getSize(periodFinder).width,
      tester.getSize(find.byType(Card)).width,
    );
    final metricTops = FinanceMetricRole.values
        .map(
          (role) => tester
              .getTopLeft(
                find.byKey(
                  ValueKey(
                    AppWidgetKeys.financeBreakEvenMetric(_mixtureId, role.name),
                  ),
                ),
              )
              .dy,
        )
        .toSet();
    expect(metricTops, hasLength(1));
    expect(
      _textStyle(tester, r'$8.25').fontSize,
      AppSizes.financeRingValueFont,
    );
    expect(
      _textStyle(tester, r'$/huevo').fontSize,
      AppSizes.financeRingLabelFont,
    );
    expect(_textStyle(tester, 'Gallinero').fontSize, AppSizes.financeTitleFont);
    expect(
      _textStyle(
        tester,
        'Precio mínimo por huevo bueno para cubrir costos.',
      ).fontSize,
      AppSizes.financeSubtitleFont,
    );
    expect(
      _textStyle(tester, 'Margen +20.00 %').fontSize,
      AppSizes.financeMarginFont,
    );
    expect(
      _textStyle(tester, r'$800.00').fontSize,
      AppSizes.financeMetricValueFont,
    );
    expect(
      _textStyle(tester, 'Costo total').fontSize,
      AppSizes.financeMetricLabelFont,
    );
    expect(
      _textStyle(
        tester,
        '15.00 aves • 0.24 huevo/(día·ave) • 0.21 kg/(día·ave)',
      ).fontSize,
      AppSizes.financeCompactLineFont,
    );
    expect(
      _textStyle(tester, '13 ene 2026 – 28 abr 2026 · 105 días').fontSize,
      AppSizes.financePeriodFont,
    );
  });

  testWidgets('uses an honest unavailable price and neutral treatment', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      role: FinanceMarginRole.unavailable,
      margin: 'Margen no disponible',
      price: 'No disponible',
    );

    final theme = FinanceTheme.of(
      tester.element(
        find.byKey(ValueKey(AppWidgetKeys.financeMarginChip(_mixtureId))),
      ),
    );
    final card = tester.widget<Card>(find.byType(Card));
    expect(
      card.color,
      theme.breakEvenCardSurface(FinanceMarginRole.unavailable),
    );
    expect(find.text('No disponible'), findsOneWidget);
    expect(find.text('Margen no disponible'), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'has no overflow at 288dp and 1.5 text scale in ${brightness.name}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(288, 1500);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);

        await _pumpCard(
          tester,
          role: FinanceMarginRole.negative,
          margin: 'Margen -39.37 %',
          brightness: brightness,
          textScale: 1.5,
        );

        expect(tester.takeException(), isNull);
      },
    );
  }
}

BoxDecoration _tileDecoration(WidgetTester tester, FinanceMetricRole role) {
  final tile = tester.widget<DecoratedBox>(
    find.byKey(
      ValueKey(AppWidgetKeys.financeBreakEvenMetric(_mixtureId, role.name)),
    ),
  );
  return tile.decoration as BoxDecoration;
}

TextStyle _textStyle(WidgetTester tester, String text) {
  return tester.widget<Text>(find.text(text)).style!;
}

const _mixtureId = '416e648e-1dd2-4a2f-8246-e42bcc6f36cb';

Future<void> _pumpCard(
  WidgetTester tester, {
  required FinanceMarginRole role,
  required String margin,
  String price = r'$8.25',
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: BreakEvenCard(
            data: BreakEvenCardViewData(
              mixtureId: _mixtureId,
              groupName: 'Gallinero',
              description: 'Precio mínimo por huevo bueno para cubrir costos.',
              priceLabel: r'$/huevo',
              priceValue: price,
              marginLabel: margin,
              marginRole: role,
              primaryMetrics: const [
                FinanceMetricViewData(
                  role: FinanceMetricRole.cost,
                  label: 'Costo total',
                  value: r'$800.00',
                  icon: Icons.payments_outlined,
                ),
                FinanceMetricViewData(
                  role: FinanceMetricRole.eggs,
                  label: 'Huevos buenos',
                  value: '97',
                  icon: Icons.egg_alt_outlined,
                ),
                FinanceMetricViewData(
                  role: FinanceMetricRole.consumption,
                  label: 'Consumo total',
                  value: '80 kg',
                  icon: Icons.grass_outlined,
                ),
              ],
              secondaryMetricsText:
                  '15.00 aves • 0.24 huevo/(día·ave) • 0.21 kg/(día·ave)',
              durationValue: '105 días',
              periodValue: '13 ene 2026 – 28 abr 2026',
              semanticsLabel:
                  'Gallinero. Precio de equilibrio por huevo: $price. $margin.',
            ),
          ),
        ),
      ),
    ),
  );
}
