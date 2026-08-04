import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nueva_app/shared/widgets/compact_form_controls.dart';

void main() {
  testWidgets('text, date, and dropdown controls have compact height parity', (
    tester,
  ) async {
    await _pumpControls(tester);

    final textHeight = tester.getSize(find.byKey(const Key('text'))).height;
    final dateHeight = tester
        .getSize(
          find.descendant(
            of: find.byKey(const Key('date')),
            matching: find.byType(InputDecorator),
          ),
        )
        .height;
    final dropdownHeight = tester
        .getSize(
          find.descendant(
            of: find.byKey(const Key('dropdown')),
            matching: find.byType(InputDecorator),
          ),
        )
        .height;

    expect(textHeight, inInclusiveRange(48, 52));
    expect((dateHeight - textHeight).abs(), lessThanOrEqualTo(2));
    expect((dropdownHeight - textHeight).abs(), lessThanOrEqualTo(2));
  });

  testWidgets('dropdown popup matches field width and uses accessible rows', (
    tester,
  ) async {
    await _pumpControls(tester, itemCount: 12);
    final fieldWidth = tester.getSize(find.byKey(const Key('dropdown'))).width;

    await tester.tap(find.byKey(const Key('raw-dropdown')));
    await tester.pumpAndSettle();

    final option = find.byKey(const Key('option-0'));
    final menu = find
        .ancestor(of: option, matching: find.byType(Material))
        .first;
    expect(tester.getSize(menu).width, closeTo(fieldWidth, 1));
    expect(tester.getSize(option).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(menu).height, lessThanOrEqualTo(320));
  });

  testWidgets('long labels and values ellipsize without overflow', (
    tester,
  ) async {
    await _pumpControls(tester, width: 240, longText: true);
    await tester.tap(find.byKey(const Key('raw-dropdown')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('validation and focus are reflected by InputDecorator', (
    tester,
  ) async {
    await _pumpControls(tester, includeFormButton: true);

    await tester.tap(find.byKey(const Key('validate')));
    await tester.pump();
    expect(find.text('Required'), findsOneWidget);

    await tester.tap(find.byKey(const Key('raw-dropdown')));
    await tester.pump();
    final decorator = tester.widget<InputDecorator>(
      find.descendant(
        of: find.byKey(const Key('dropdown')),
        matching: find.byType(InputDecorator),
      ),
    );
    expect(decorator.isFocused, isTrue);
  });

  testWidgets('disabled dropdown exposes disabled decoration semantics', (
    tester,
  ) async {
    await _pumpControls(tester, enabled: false);

    final dropdown = tester.widget<DropdownButton<String>>(
      find.byKey(const Key('raw-dropdown')),
    );
    final decorator = tester.widget<InputDecorator>(
      find.descendant(
        of: find.byKey(const Key('dropdown')),
        matching: find.byType(InputDecorator),
      ),
    );
    expect(dropdown.onChanged, isNull);
    expect(decorator.decoration.enabled, isFalse);
  });

  for (final brightness in Brightness.values) {
    testWidgets('${brightness.name} theme uses its semantic surface colors', (
      tester,
    ) async {
      await _pumpControls(tester, brightness: brightness);
      final context = tester.element(find.byKey(const Key('dropdown')));
      final decoration = tester.widget<InputDecorator>(
        find.descendant(
          of: find.byKey(const Key('dropdown')),
          matching: find.byType(InputDecorator),
        ),
      );

      expect(
        decoration.decoration.fillColor,
        Theme.of(context).inputDecorationTheme.fillColor ??
            Theme.of(context).colorScheme.surfaceContainerHighest,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('external value changes synchronize without resetting errors', (
    tester,
  ) async {
    final key = GlobalKey<_ValueHostState>();
    await tester.pumpWidget(_ValueHost(key: key));

    await tester.tap(find.byKey(const Key('validate')));
    await tester.pump();
    expect(find.text('Required'), findsOneWidget);

    key.currentState!.setValue('second');
    await tester.pump();
    await tester.pump();
    expect(find.text('Second'), findsOneWidget);
    expect(find.text('Required'), findsNothing);
  });

  testWidgets('a matching null item is a valid visible selection', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: CompactDropdownFormField<String?>(
              key: const Key('nullable-dropdown'),
              label: 'Group',
              value: null,
              items: const [null, 'group-1'],
              itemLabelBuilder: (value) => value ?? 'No group',
              onChanged: (_) {},
              validator: (value) => value == null ? null : null,
            ),
          ),
        ),
      ),
    );

    expect(find.text('No group'), findsOneWidget);
    expect(formKey.currentState!.validate(), isTrue);
  });
}

Future<void> _pumpControls(
  WidgetTester tester, {
  int itemCount = 2,
  double width = 360,
  bool longText = false,
  bool enabled = true,
  bool includeFormButton = false,
  Brightness brightness = Brightness.light,
}) async {
  final formKey = GlobalKey<FormState>();
  final items = List.generate(
    itemCount,
    (index) => longText
        ? 'A deliberately long option label that must ellipsize $index'
        : 'Option $index',
  );
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
        body: Center(
          child: SizedBox(
            width: width,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Builder(
                    builder: (context) => CompactLabeledField(
                      label: longText
                          ? 'A deliberately long external label that must remain bounded'
                          : 'Text',
                      child: TextFormField(
                        key: const Key('text'),
                        decoration: compactInputDecoration(
                          context,
                          hintText: 'Value',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CompactDateField(
                    key: const Key('date'),
                    label: 'Date',
                    value: DateTime(2026, 7, 24),
                    onTap: enabled ? () {} : null,
                    enabled: enabled,
                  ),
                  const SizedBox(height: 12),
                  CompactDropdownFormField<String>(
                    key: const Key('dropdown'),
                    dropdownKey: const Key('raw-dropdown'),
                    label: 'Dropdown',
                    value: null,
                    items: items,
                    itemLabelBuilder: (item) => item,
                    itemKeyBuilder: (item) =>
                        Key('option-${items.indexOf(item)}'),
                    onChanged: enabled ? (_) {} : null,
                    validator: (value) => value == null ? 'Required' : null,
                  ),
                  if (includeFormButton)
                    FilledButton(
                      key: const Key('validate'),
                      onPressed: () => formKey.currentState!.validate(),
                      child: const Text('Validate'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _ValueHost extends StatefulWidget {
  const _ValueHost({super.key});

  @override
  State<_ValueHost> createState() => _ValueHostState();
}

class _ValueHostState extends State<_ValueHost> {
  final formKey = GlobalKey<FormState>();
  String? value;

  void setValue(String nextValue) => setState(() => value = nextValue);

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Form(
        key: formKey,
        child: Column(
          children: [
            CompactDropdownFormField<String>(
              label: 'Value',
              value: value,
              items: const ['first', 'second'],
              itemLabelBuilder: (item) => switch (item) {
                'first' => 'First',
                _ => 'Second',
              },
              onChanged: (nextValue) => setState(() => value = nextValue),
              validator: (nextValue) => nextValue == null ? 'Required' : null,
            ),
            FilledButton(
              key: const Key('validate'),
              onPressed: () => formKey.currentState!.validate(),
              child: const Text('Validate'),
            ),
          ],
        ),
      ),
    ),
  );
}
