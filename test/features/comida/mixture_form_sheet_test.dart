import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nueva_app/core/theme/app_theme.dart';
import 'package:nueva_app/features/comida/comida_models.dart';
import 'package:nueva_app/features/comida/forms/mixture_form_sheet.dart';
import 'package:nueva_app/features/settings/presentation/providers/theme_provider.dart';

void main() {
  testWidgets('step zero shrink-wraps well below the sheet height cap', (
    tester,
  ) async {
    const viewport = Size(390, 844);
    await _openSheet(tester, viewport: viewport);

    final sheetHeight = tester
        .getSize(find.byKey(const ValueKey('mixture-form-sheet')))
        .height;

    expect(sheetHeight, lessThan(viewport.height * 0.8));
    expect(sheetHeight, lessThan(viewport.height * 0.92));
  });

  testWidgets(
    'short landscape viewport keeps the sheet bounded and scrollable',
    (tester) async {
      const viewport = Size(640, 360);
      await _openSheet(tester, viewport: viewport);

      final sheetHeight = tester
          .getSize(find.byKey(const ValueKey('mixture-form-sheet')))
          .height;
      final maxScrollExtent = _maxScrollExtent(tester);

      expect(sheetHeight, lessThanOrEqualTo(viewport.height * 0.92 + 1));
      expect(maxScrollExtent, greaterThan(0));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'keyboard inset keeps the sheet above the keyboard and scrollable',
    (tester) async {
      const viewport = Size(390, 640);
      const keyboardInset = 240.0;
      await _openSheet(
        tester,
        viewport: viewport,
        keyboardInset: keyboardInset,
      );

      final sheetRect = tester.getRect(
        find.byKey(const ValueKey('mixture-form-sheet')),
      );
      final maxScrollExtent = _maxScrollExtent(tester);

      expect(
        sheetRect.height,
        lessThanOrEqualTo((640 - keyboardInset) * 0.92 + 1),
      );
      expect(
        sheetRect.bottom,
        lessThanOrEqualTo(viewport.height - keyboardInset + 1),
      );
      expect(maxScrollExtent, greaterThan(0));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('metadata controls have matching visible heights', (
    tester,
  ) async {
    await _openSheet(tester);

    final dateHeight = _height(tester, 'mixture-start-date-field');
    final groupHeight = _height(tester, 'mixture-group-field');
    final countHeight = _height(tester, 'mixture-ingredient-count-field');

    expect((dateHeight - countHeight).abs(), lessThanOrEqualTo(4));
    expect((groupHeight - countHeight).abs(), lessThanOrEqualTo(4));
  });

  testWidgets('group menu matches field width and keeps 48dp rows', (
    tester,
  ) async {
    await _openSheet(tester);
    final fieldWidth = tester
        .getSize(find.byKey(const ValueKey('mixture-group-field')))
        .width;

    await tester.tap(find.byKey(const ValueKey('mixture-group-dropdown')));
    await tester.pumpAndSettle();

    final option = find.byKey(const ValueKey('mixture-group-option-group-2'));
    final menuMaterial = find
        .ancestor(of: option, matching: find.byType(Material))
        .first;

    expect(option, findsOneWidget);
    expect(
      tester.getSize(menuMaterial).width,
      lessThanOrEqualTo(fieldWidth + 1),
    );
    expect(tester.getSize(option).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('validation blocks Continue until metadata is valid', (
    tester,
  ) async {
    await _openSheet(tester);

    await tester.tap(find.text('Continuar'));
    await tester.pump();

    expect(find.text('Selecciona un grupo.'), findsOneWidget);
    expect(
      find.text('La cantidad de ingredientes debe ser mayor que 0.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('mixture-group-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ponedoras').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('mixture-ingredient-count-field')),
        matching: find.byType(TextFormField),
      ),
      '2',
    );
    await tester.pump();
    await tester.ensureVisible(find.text('Continuar'));
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Ingrediente 1 de 2'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('ingredient popup and numeric controls share compact geometry', (
    tester,
  ) async {
    await _openSheet(tester);
    await _goToIngredient(tester, count: 2);
    final categoryField = find.byKey(const ValueKey('category-0-null'));
    final categoryWidth = tester.getSize(categoryField).width;

    await tester.tap(find.byKey(const ValueKey('category-dropdown-0')));
    await tester.pumpAndSettle();
    final longOption = find.byKey(const ValueKey('category-option-cat-3'));
    final menu = find
        .ancestor(of: longOption, matching: find.byType(Material))
        .first;
    expect(tester.getSize(menu).width, closeTo(categoryWidth, 1));
    expect(find.text(_longCategoryName), findsOneWidget);
    await tester.tap(find.text('Maíz').last);
    await tester.pumpAndSettle();

    final quantityHeight = _height(tester, 'mixture-quantity-field');
    final priceHeight = _height(tester, 'mixture-price-field');
    expect((quantityHeight - priceHeight).abs(), lessThanOrEqualTo(2));
    expect(quantityHeight, inInclusiveRange(48, 52));
    expect(find.text('kg'), findsOneWidget);
  });

  testWidgets('step state excludes a category already used by another step', (
    tester,
  ) async {
    await _openSheet(tester);
    await _goToIngredient(tester, count: 2);
    await tester.tap(find.byKey(const ValueKey('category-dropdown-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maíz').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('mixture-quantity-field')),
      '12,5',
    );
    await tester.enterText(
      find.byKey(const ValueKey('mixture-price-field')),
      '30',
    );
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();

    expect(find.text('Ingrediente 2 de 2'), findsOneWidget);
    expect(find.text('Ingredientes acumulados'), findsOneWidget);
    expect(find.textContaining('12.50 kg'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('category-dropdown-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('category-option-cat-1')), findsNothing);
    expect(find.byKey(const ValueKey('category-option-cat-2')), findsOneWidget);
  });

  testWidgets('edit mode retains an assigned inactive category', (
    tester,
  ) async {
    await _openSheet(tester, mixture: _inactiveMixture);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('Archived mineral supplement (inactiva)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('category-dropdown-0')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('category-option-cat-inactive')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets('${brightness.name} theme renders without overflow', (
      tester,
    ) async {
      await _openSheet(tester, brightness: brightness);
      await _goToIngredient(tester, count: 1);
      await tester.tap(find.byKey(const ValueKey('category-dropdown-0')));
      await tester.pumpAndSettle();

      expect(find.text(_longCategoryName), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

const _longGroupName =
    'Grupo de producción con un nombre deliberadamente largo para el menú';
const _longCategoryName =
    'Categoría activa con un nombre deliberadamente largo para el menú';

const _categories = [
  FoodCategory(id: 'cat-1', name: 'Maíz', isActive: true),
  FoodCategory(id: 'cat-2', name: 'Soya', isActive: true),
  FoodCategory(id: 'cat-3', name: _longCategoryName, isActive: true),
];

const _groups = [
  FoodGroup(id: 'group-1', name: 'Ponedoras'),
  FoodGroup(id: 'group-2', name: _longGroupName),
];

final _inactiveMixture = FoodMixture(
  id: 'mixture-1',
  farmId: 'farm-1',
  groupId: 'group-1',
  groupName: 'Ponedoras',
  startDate: DateTime(2026, 7, 1),
  updatedAt: DateTime(2026, 7, 20),
  ingredients: const [
    MixtureIngredient(
      id: 'ingredient-1',
      foodId: 'food-1',
      categoryId: 'cat-inactive',
      categoryName: 'Archived mineral supplement',
      categoryIsActive: false,
      quantityKg: 5,
      totalCost: 8,
    ),
  ],
);

Future<void> _openSheet(
  WidgetTester tester, {
  Size viewport = const Size(390, 844),
  double keyboardInset = 0,
  Brightness brightness = Brightness.dark,
  FoodMixture? mixture,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = viewport;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboardInset);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetViewInsets);

  await tester.pumpWidget(_TestApp(brightness: brightness, mixture: mixture));
  await tester.tap(find.byKey(const ValueKey('open-mixture-sheet')));
  await tester.pumpAndSettle();
}

Future<void> _goToIngredient(WidgetTester tester, {required int count}) async {
  await tester.tap(find.byKey(const ValueKey('mixture-group-dropdown')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ponedoras').last);
  await tester.pumpAndSettle();
  await tester.enterText(
    find.descendant(
      of: find.byKey(const ValueKey('mixture-ingredient-count-field')),
      matching: find.byType(TextFormField),
    ),
    '$count',
  );
  await tester.tap(find.text('Continuar'));
  await tester.pumpAndSettle();
}

double _height(WidgetTester tester, String key) =>
    tester.getSize(find.byKey(ValueKey(key))).height;

double _maxScrollExtent(WidgetTester tester) => tester
    .stateList<ScrollableState>(
      find.descendant(
        of: find.byKey(const ValueKey('mixture-form-scroll-view')),
        matching: find.byType(Scrollable),
      ),
    )
    .fold(
      0,
      (maximum, state) => state.position.maxScrollExtent > maximum
          ? state.position.maxScrollExtent
          : maximum,
    );

class _TestApp extends StatelessWidget {
  const _TestApp({required this.brightness, required this.mixture});

  final Brightness brightness;
  final FoodMixture? mixture;

  @override
  Widget build(BuildContext context) {
    final mode = brightness == Brightness.dark
        ? AppThemeMode.dark
        : AppThemeMode.light;
    return ProviderScope(
      overrides: [themeProvider.overrideWith(() => _TestThemeNotifier(mode))],
      child: MaterialApp(
        theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
        home: _SheetHost(mixture: mixture),
      ),
    );
  }
}

class _SheetHost extends StatelessWidget {
  const _SheetHost({required this.mixture});

  final FoodMixture? mixture;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: FilledButton(
        key: const ValueKey('open-mixture-sheet'),
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          builder: (_) => MixtureFormSheet(
            farmId: 'farm-1',
            categories: _categories,
            groups: _groups,
            mixture: mixture,
          ),
        ),
        child: const Text('Open'),
      ),
    ),
  );
}

class _TestThemeNotifier extends ThemeNotifier {
  _TestThemeNotifier(this.mode);

  final AppThemeMode mode;

  @override
  AppThemeMode build() => mode;
}
