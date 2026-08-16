import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rancho/core/testing/app_widget_keys.dart';
import 'package:rancho/features/huevos/huevo_forms.dart';
import 'package:rancho/features/huevos/huevo_models.dart';

void main() {
  for (final form in ['collection', 'sale']) {
    testWidgets('$form group menu matches field width with 48dp rows', (
      tester,
    ) async {
      await _openForm(tester, sale: form == 'sale');
      final field = find.byKey(Key('$form-group-field'));
      final dropdown = find.byKey(Key('$form-group-dropdown'));
      final fieldWidth = tester.getSize(field).width;

      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      final option = find.byKey(Key('$form-group-option-group-1'));
      final menu = find
          .ancestor(of: option, matching: find.byType(Material))
          .first;
      expect(tester.getSize(menu).width, closeTo(fieldWidth, 1));
      expect(tester.getSize(option).height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('collection validates totals and submits preserved values', (
    tester,
  ) async {
    EggCollectionInput? saved;
    await _openForm(tester, onCollectionSave: (input) async => saved = input);
    await _selectGroup(tester, 'collection');
    await _enterNested(tester, const Key('collection-good-field'), '0');
    await _enterNested(tester, const Key('collection-broken-field'), '0');

    await tester.tap(_key(AppWidgetKeys.eggFormSubmit));
    await tester.pump();
    expect(
      find.text('Registra al menos un huevo recolectado.'),
      findsOneWidget,
    );

    await _enterNested(tester, const Key('collection-good-field'), '12');
    await tester.tap(_key(AppWidgetKeys.eggFormSubmit));
    await tester.pumpAndSettle();
    expect(saved?.groupId, 'group-1');
    expect(saved?.goodEggs, 12);
    expect(saved?.brokenEggs, 0);
  });

  testWidgets('collection compact controls keep matching visible heights', (
    tester,
  ) async {
    await _openForm(tester);
    final groupHeight = tester
        .getSize(find.byKey(const Key('collection-group-field')))
        .height;
    final goodHeight = tester
        .getSize(find.byKey(const Key('collection-good-field')))
        .height;
    final dateHeight = tester
        .getSize(find.byKey(const Key('egg-date-field')))
        .height;
    expect((groupHeight - goodHeight).abs(), lessThanOrEqualTo(2));
    expect((dateHeight - goodHeight).abs(), lessThanOrEqualTo(2));
  });

  testWidgets('sale recalculates total, accepts comma decimal, and saves', (
    tester,
  ) async {
    EggSaleInput? saved;
    await _openForm(
      tester,
      sale: true,
      onSaleSave: (input) async => saved = input,
    );
    await _selectGroup(tester, 'sale');
    await tester.enterText(find.byKey(const Key('sale-quantity-field')), '3');
    await tester.enterText(find.byKey(const Key('sale-price-field')), '2,50');
    await tester.pump();

    expect(find.text(r'$7.50'), findsOneWidget);
    await tester.ensureVisible(_key(AppWidgetKeys.eggFormSubmit));
    await tester.tap(_key(AppWidgetKeys.eggFormSubmit));
    await tester.pumpAndSettle();
    expect(saved?.quantity, 3);
    expect(saved?.unitPrice, 2.5);
  });

  testWidgets('edit forms preserve group, numeric, and date prefills', (
    tester,
  ) async {
    await _openForm(tester, collection: _collection);
    expect(find.textContaining(_longGroupName), findsOneWidget);
    expect(_nestedText(tester, const Key('collection-good-field')), '18');
    expect(_nestedText(tester, const Key('collection-broken-field')), '2');
    expect(find.text('20/07/2026'), findsOneWidget);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    await _openForm(tester, sale: true, saleRecord: _sale);
    expect(find.textContaining(_longGroupName), findsOneWidget);
    expect(_fieldText(tester, const Key('sale-quantity-field')), '4');
    expect(_fieldText(tester, const Key('sale-price-field')), '3.50');
    expect(find.text('21/07/2026'), findsOneWidget);
  });

  testWidgets('date control opens the existing bounded date picker', (
    tester,
  ) async {
    await _openForm(tester);
    await tester.tap(find.byKey(const Key('egg-date-field')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets('saving disables submit and compact inputs', (tester) async {
    final pending = Completer<void>();
    await _openForm(tester, onCollectionSave: (_) => pending.future);
    await _selectGroup(tester, 'collection');
    await _enterNested(tester, const Key('collection-good-field'), '1');
    await _enterNested(tester, const Key('collection-broken-field'), '0');

    await tester.tap(_key(AppWidgetKeys.eggFormSubmit));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(_key(AppWidgetKeys.eggFormSubmit)).onPressed,
      isNull,
    );
    final goodField = tester.widget<TextFormField>(
      find.descendant(
        of: find.byKey(const Key('collection-good-field')),
        matching: find.byType(TextFormField),
      ),
    );
    expect(goodField.enabled, isFalse);
    pending.complete();
    await tester.pumpAndSettle();
  });

  for (final brightness in Brightness.values) {
    testWidgets('${brightness.name} compact forms survive keyboard landscape', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(700, 380);
      tester.view.viewInsets = const FakeViewPadding(bottom: 160);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetViewInsets);

      await _openForm(tester, sale: true, brightness: brightness);
      final sheet = _key(AppWidgetKeys.eggFormSheet);
      expect(
        tester.getSize(sheet).height,
        lessThanOrEqualTo((380 - 160) * 0.92 + 1),
      );
      expect(find.byType(Scrollable), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  for (final form in ['collection', 'sale']) {
    testWidgets('$form sheet sizes to content on a tall viewport', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 1200);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await _openForm(tester, sale: form == 'sale');

      final sheetHeight = tester
          .getSize(_key(AppWidgetKeys.eggFormSheet))
          .height;
      expect(sheetHeight, lessThan(1200 * 0.75));
      expect(sheetHeight, greaterThan(0));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'form shell uses one handle, outlined surface, icon tile, and full action',
    (tester) async {
      await _openForm(tester);

      expect(_key(AppWidgetKeys.eggFormDragHandle), findsOneWidget);
      expect(find.byType(CircleAvatar), findsNothing);

      final sheet = tester.widget<Material>(_key(AppWidgetKeys.eggFormSheet));
      final shape = sheet.shape! as RoundedRectangleBorder;
      expect(shape.side.style, BorderStyle.solid);
      expect(shape.side.width, greaterThan(0));

      final iconTile = tester.widget<Container>(
        _key(AppWidgetKeys.eggFormIcon),
      );
      final decoration = iconTile.decoration! as BoxDecoration;
      expect(decoration.borderRadius, isNotNull);
      expect(decoration.shape, BoxShape.rectangle);

      final action = _key(AppWidgetKeys.eggFormSubmit);
      expect(tester.getSize(action).width, greaterThan(500));
      expect(find.text('Registrar recolección'), findsOneWidget);
    },
  );
}

const _longGroupName =
    'Ponedoras del sector norte con un nombre deliberadamente largo';

const _groups = [
  EggGroupChoice(
    id: 'group-1',
    name: _longGroupName,
    animalTypeId: 'type-1',
    animalTypeName: 'Gallinas ponedoras de producción',
  ),
];

final _collection = EggCollection(
  id: 'collection-1',
  farmId: 'farm-1',
  groupId: 'group-1',
  date: DateTime(2026, 7, 20),
  goodEggs: 18,
  brokenEggs: 2,
  createdAt: DateTime(2026, 7, 20),
  groupName: _longGroupName,
  animalTypeId: 'type-1',
  animalTypeName: 'Gallinas',
  authorName: 'Ana',
);

final _sale = EggSale(
  id: 'sale-1',
  farmId: 'farm-1',
  groupId: 'group-1',
  date: DateTime(2026, 7, 21),
  quantity: 4,
  unitPrice: 3.5,
  createdAt: DateTime(2026, 7, 21),
  groupName: _longGroupName,
  animalTypeId: 'type-1',
  animalTypeName: 'Gallinas',
  authorName: 'Ana',
);

Future<void> _openForm(
  WidgetTester tester, {
  bool sale = false,
  Brightness brightness = Brightness.light,
  EggCollection? collection,
  EggSale? saleRecord,
  Future<void> Function(EggCollectionInput input)? onCollectionSave,
  Future<void> Function(EggSaleInput input)? onSaleSave,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: brightness,
        ),
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            key: const Key('open'),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              showDragHandle: false,
              backgroundColor: Colors.transparent,
              builder: (_) => sale
                  ? EggSaleForm(
                      farmId: 'farm-1',
                      groups: _groups,
                      sale: saleRecord,
                      onSave: onSaleSave ?? (_) async {},
                    )
                  : EggCollectionForm(
                      farmId: 'farm-1',
                      groups: _groups,
                      collection: collection,
                      onSave: onCollectionSave ?? (_) async {},
                    ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
}

Future<void> _selectGroup(WidgetTester tester, String prefix) async {
  await tester.tap(find.byKey(Key('$prefix-group-dropdown')));
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining(_longGroupName).last);
  await tester.pumpAndSettle();
}

Future<void> _enterNested(WidgetTester tester, Key parentKey, String value) =>
    tester.enterText(
      find.descendant(
        of: find.byKey(parentKey),
        matching: find.byType(TextFormField),
      ),
      value,
    );

String _nestedText(WidgetTester tester, Key parentKey) => tester
    .widget<TextFormField>(
      find.descendant(
        of: find.byKey(parentKey),
        matching: find.byType(TextFormField),
      ),
    )
    .controller!
    .text;

String _fieldText(WidgetTester tester, Key key) =>
    tester.widget<TextFormField>(find.byKey(key)).controller!.text;

Finder _key(String value) => find.byKey(ValueKey(value));
