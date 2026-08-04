import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rancho/features/animales/animales_provider.dart';
import 'package:rancho/features/animales/animales_repository.dart'
    show AnimalesRepository;
import 'package:rancho/features/animales/registrar_baja_sheet.dart';
import 'package:rancho/features/model/animal/animal.dart';
import 'package:rancho/features/model/bajaAnimal/registrar_baja_animales_input.dart';
import 'package:rancho/features/model/catalogoItem/catalogo_item.dart';
import 'package:rancho/features/model/tipoAnimal/tipoAnimal.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('compact controls and type popup preserve accessible geometry', (
    tester,
  ) async {
    await _pumpSheet(tester);
    final field = find.byKey(const Key('baja-animal-type-field'));
    final width = tester.getSize(field).width;

    await tester.tap(find.byKey(const Key('baja-animal-type-dropdown')));
    await tester.pumpAndSettle();
    final option = find.byKey(const Key('baja-animal-type-option-type-1'));
    final menu = find
        .ancestor(of: option, matching: find.byType(Material))
        .first;
    expect(tester.getSize(menu).width, closeTo(width, 1));
    expect(tester.getSize(option).height, greaterThanOrEqualTo(48));
    await tester.tap(find.text('Gallinas').last);
    await tester.pumpAndSettle();

    final dateHeight = _decoratorHeight(tester, const Key('baja-date-field'));
    final amountHeight = tester
        .getSize(find.byKey(const Key('baja-amount-field')))
        .height;
    final searchHeight = tester
        .getSize(find.byKey(const Key('baja-search-field')))
        .height;
    expect((dateHeight - amountHeight).abs(), lessThanOrEqualTo(2));
    expect((searchHeight - amountHeight).abs(), lessThanOrEqualTo(2));
  });

  testWidgets('required reason and animal validation remain sequential', (
    tester,
  ) async {
    await _pumpSheet(tester);
    final submit = find.widgetWithText(FilledButton, 'Registrar baja');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(find.text('Selecciona una razón de baja.'), findsOneWidget);

    await tester.ensureVisible(find.text('Muerte'));
    await tester.tap(find.text('Muerte'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(find.text('Selecciona al menos un animal.'), findsOneWidget);
  });

  testWidgets('search cannot expose a temporally ineligible animal', (
    tester,
  ) async {
    await _pumpSheet(tester);
    await tester.ensureVisible(find.byKey(const Key('baja-search-field')));
    await tester.enterText(find.byKey(const Key('baja-search-field')), '13');
    await tester.pump();

    expect(find.text('#13 · Gallinas'), findsNothing);
    expect(
      find.text('No hay animales que coincidan con la búsqueda.'),
      findsOneWidget,
    );
  });

  for (final isDark in [false, true]) {
    testWidgets(
      '${isDark ? 'dark' : 'light'} draggable shell stays usable with keyboard',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(700, 500);
        tester.view.viewInsets = const FakeViewPadding(bottom: 180);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetViewInsets);

        await _pumpSheet(tester, isDark: isDark, configureView: false);
        expect(
          tester.getSize(find.byKey(const Key('registrar-baja-sheet'))).height,
          lessThanOrEqualTo((500 - 180) * 0.96 + 1),
        );
        expect(
          find.byKey(const Key('registrar-baja-scroll-view')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}

double _decoratorHeight(WidgetTester tester, Key parentKey) => tester
    .getSize(
      find.descendant(
        of: find.byKey(parentKey),
        matching: find.byType(InputDecorator),
      ),
    )
    .height;

Future<void> _pumpSheet(
  WidgetTester tester, {
  bool isDark = false,
  bool configureView = true,
}) async {
  if (configureView) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
  }
  final repository = _FakeAnimalesRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [animalesRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        theme: isDark ? ThemeData.dark(useMaterial3: true) : null,
        home: Scaffold(
          body: RegistrarBajaSheet(
            granjaId: 'farm-1',
            isDark: isDark,
            tipoAnimalIdInicial: 'type-1',
            initialBajaDate: DateTime(2024, 1, 23),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeAnimalesRepository extends AnimalesRepository {
  _FakeAnimalesRepository() : super(_buildClient());

  @override
  Future<List<TipoAnimal>> getTipos(String granjaId) async => const [
    TipoAnimal(
      id: 'type-1',
      granjaId: 'farm-1',
      nombre: 'Gallinas',
      createdBy: 'user-1',
    ),
  ];

  @override
  Future<List<CatalogoItem>> getRazonesBaja(String granjaId) async => const [
    CatalogoItem(id: 'reason-1', nombre: 'Muerte'),
  ];

  @override
  Future<List<Animal>> getAnimales(String granjaId) async => [
    _animal(id: 'eligible', bracelet: 22, date: DateTime(2024, 1, 22)),
    _animal(id: 'future', bracelet: 13, date: DateTime(2025, 1, 13)),
  ];

  @override
  Future<void> registrarBajaAnimales(RegistrarBajaAnimalesInput input) async {}
}

Animal _animal({
  required String id,
  required int bracelet,
  required DateTime date,
}) => Animal(
  id: id,
  granjaId: 'farm-1',
  tipoAnimalId: 'type-1',
  brazalete: bracelet,
  fechaAdquisicion: date,
  activo: true,
  tipoNombre: 'Gallinas',
  grupoNombre: 'Ponedoras',
);

SupabaseClient _buildClient() {
  final client = SupabaseClient('https://example.supabase.co', 'anon-key');
  client.auth.stopAutoRefresh();
  return client;
}
