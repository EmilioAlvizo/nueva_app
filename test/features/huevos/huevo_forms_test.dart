import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nueva_app/features/huevos/huevo_forms.dart';
import 'package:nueva_app/features/huevos/huevo_models.dart';

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

    await tester.tap(find.byKey(const Key('egg-form-submit')));
    await tester.pump();
    expect(
      find.text('Registra al menos un huevo recolectado.'),
      findsOneWidget,
    );

    await _enterNested(tester, const Key('collection-good-field'), '12');
    await tester.tap(find.byKey(const Key('egg-form-submit')));
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
    await tester.ensureVisible(find.byKey(const Key('egg-form-submit')));
    await tester.tap(find.byKey(const Key('egg-form-submit')));
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

    await tester.tap(find.byKey(const Key('egg-form-submit')));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('egg-form-submit')))
          .onPressed,
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
      final sheet = find.byKey(const Key('egg-form-sheet'));
      expect(
        tester.getSize(sheet).height,
        lessThanOrEqualTo((380 - 160) * 0.92 + 1),
      );
      expect(find.byType(Scrollable), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
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
