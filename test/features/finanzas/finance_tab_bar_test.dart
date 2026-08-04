import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rancho/core/theme/app_theme.dart';
import 'package:rancho/core/theme/finance_theme.dart';
import 'package:rancho/features/finanzas/presentation/widgets/finance_tab_bar.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'uses distinct selected accents and preserves icons in ${brightness.name}',
      (tester) async {
        final selectedColors = <Color>{};

        for (final item in _items) {
          await tester.pumpWidget(
            MaterialApp(
              theme: brightness == Brightness.light
                  ? AppTheme.light
                  : AppTheme.dark,
              home: Scaffold(
                body: FinanceTabBar(
                  items: _items,
                  selected: item.tab,
                  onSelected: (_) {},
                ),
              ),
            ),
          );

          final button = tester.widget<TextButton>(
            find.byKey(ValueKey(item.keyValue)),
          );
          final selectedColor = button.style!.backgroundColor!.resolve({});
          final theme = FinanceTheme.of(
            tester.element(find.byKey(ValueKey(item.keyValue))),
          );
          expect(selectedColor, theme.tabPalette(item.role).accent);
          selectedColors.add(selectedColor!);

          final image = tester.widget<Image>(
            find.descendant(
              of: find.byKey(ValueKey(item.keyValue)),
              matching: find.byType(Image),
            ),
          );
          final expectedAsset = item.tab == FinanceTab.charts
              ? 'assets/chart_filled.png'
              : item.asset;
          expect((image.image as AssetImage).assetName, expectedAsset);
        }

        expect(selectedColors, hasLength(4));

        await tester.pumpWidget(
          MaterialApp(
            theme: brightness == Brightness.light
                ? AppTheme.light
                : AppTheme.dark,
            home: Scaffold(
              body: FinanceTabBar(
                items: _items,
                selected: FinanceTab.balance,
                onSelected: (_) {},
              ),
            ),
          ),
        );
        final chartImage = tester.widget<Image>(
          find.descendant(
            of: find.byKey(const ValueKey('charts')),
            matching: find.byType(Image),
          ),
        );
        expect((chartImage.image as AssetImage).assetName, 'assets/chart.png');
      },
    );
  }
}

const _items = [
  FinanceTabItem(
    tab: FinanceTab.balance,
    role: FinanceTabRole.balance,
    label: 'Balance',
    asset: 'assets/goal.png',
    keyValue: 'balance',
  ),
  FinanceTabItem(
    tab: FinanceTab.income,
    role: FinanceTabRole.income,
    label: 'Income',
    asset: 'assets/income.png',
    keyValue: 'income',
  ),
  FinanceTabItem(
    tab: FinanceTab.expenses,
    role: FinanceTabRole.expenses,
    label: 'Expenses',
    asset: 'assets/outcome.png',
    keyValue: 'expenses',
  ),
  FinanceTabItem(
    tab: FinanceTab.charts,
    role: FinanceTabRole.charts,
    label: 'Charts',
    asset: 'assets/chart.png',
    keyValue: 'charts',
  ),
];
