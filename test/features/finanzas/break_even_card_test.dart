import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nueva_app/core/testing/app_widget_keys.dart';
import 'package:nueva_app/core/theme/app_theme.dart';
import 'package:nueva_app/core/theme/finance_theme.dart';
import 'package:nueva_app/features/finanzas/presentation/widgets/break_even_card.dart';
import 'package:nueva_app/l10n/app_localizations.dart';

void main() {
  for (final testCase in [
    (role: FinanceMarginRole.positive, margin: 'Margen +20.00 %'),
    (role: FinanceMarginRole.negative, margin: 'Margen -39.37 %'),
    (role: FinanceMarginRole.unavailable, margin: 'Margen no disponible'),
  ]) {
    testWidgets('renders ${testCase.role.name} margin card', (tester) async {
      await _pumpCard(tester, role: testCase.role, margin: testCase.margin);

      expect(find.text(r'$8.25'), findsOneWidget);
      expect(find.text(testCase.margin), findsOneWidget);
      expect(find.text('Costo total'), findsOneWidget);
      expect(find.text(r'$800.00'), findsOneWidget);
      expect(find.text('Huevos buenos'), findsOneWidget);
      expect(find.text('97'), findsOneWidget);
      expect(find.text('Consumo total'), findsOneWidget);
      expect(find.text('80 kg'), findsOneWidget);
      expect(
        find.text('15.00 aves • 0.24 huevo/(día·ave) • 0.21 kg/(día·ave)'),
        findsOneWidget,
      );
      expect(find.text('Aves promedio ponderado'), findsNothing);
      expect(find.text('Huevos por día'), findsNothing);
      expect(find.text('Huevos por día por ave'), findsNothing);
      expect(find.text('Consumo por día'), findsNothing);
      expect(find.text('Consumo por día por ave'), findsNothing);
      expect(find.text('Precio promedio de venta'), findsNothing);
      expect(find.text('3.73'), findsNothing);
      expect(find.text('3.08 kg'), findsNothing);
      expect(find.text(r'$5.00'), findsNothing);
      expect(find.text('Duración'), findsOneWidget);
      expect(find.text('26 días'), findsOneWidget);
      expect(find.text('1 jul 2026 - 26 jul 2026'), findsOneWidget);

      final theme = FinanceTheme.of(
        tester.element(
          find.byKey(ValueKey(AppWidgetKeys.financeMarginChip(_mixtureId))),
        ),
      );
      final palette = theme.marginPalette(testCase.role);
      final ring = tester.widget<DecoratedBox>(
        find.byKey(
          ValueKey(AppWidgetKeys.financeBreakEvenPriceIndicator(_mixtureId)),
        ),
      );
      final ringDecoration = ring.decoration as BoxDecoration;
      expect(ringDecoration.border!.top.color, palette.accent);

      final chip = tester.widget<DecoratedBox>(
        find.byKey(ValueKey(AppWidgetKeys.financeMarginChip(_mixtureId))),
      );
      expect((chip.decoration as BoxDecoration).color, palette.container);

      final semantics = tester.getSemantics(
        find.byKey(ValueKey(AppWidgetKeys.financeBreakEvenCard(_mixtureId))),
      );
      expect(semantics.label, contains('Gallinero'));
      expect(semantics.label, contains(testCase.margin));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('uses an honest unavailable price and neutral treatment', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      role: FinanceMarginRole.unavailable,
      margin: 'Margen no disponible',
      price: 'No disponible',
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
              priceLabel: 'Precio de equilibrio por huevo',
              priceValue: price,
              marginLabel: margin,
              marginRole: role,
              primaryMetrics: const [
                FinanceMetricViewData(
                  label: 'Costo total',
                  value: r'$800.00',
                  icon: Icons.payments_outlined,
                ),
                FinanceMetricViewData(
                  label: 'Huevos buenos',
                  value: '97',
                  icon: Icons.egg_alt_outlined,
                ),
                FinanceMetricViewData(
                  label: 'Consumo total',
                  value: '80 kg',
                  icon: Icons.grass_outlined,
                ),
              ],
              secondaryMetricsText:
                  '15.00 aves • 0.24 huevo/(día·ave) • 0.21 kg/(día·ave)',
              durationLabel: 'Duración',
              durationValue: '26 días',
              periodValue: '1 jul 2026 - 26 jul 2026',
              semanticsLabel:
                  'Gallinero. Precio de equilibrio por huevo: $price. $margin.',
            ),
          ),
        ),
      ),
    ),
  );
}
