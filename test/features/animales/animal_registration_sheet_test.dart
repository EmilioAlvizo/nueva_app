import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nueva_app/features/animales/animales_provider.dart';
import 'package:nueva_app/features/animales/animales_repository.dart'
    show AnimalesRepository;
import 'package:nueva_app/features/model/altaAnimales/altaAnimales.dart';
import 'package:nueva_app/features/model/altaAnimales/animal_registration_sheet.dart';
import 'package:nueva_app/features/model/catalogoItem/catalogo_item.dart';
import 'package:nueva_app/features/model/grupo/grupo.dart';
import 'package:nueva_app/features/model/tipoAnimal/tipoAnimal.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('AnimalRegistrationSheet', () {
    testWidgets('single mode shows the optional bracelet toggle', (
      tester,
    ) async {
      await tester.pumpWidget(
        _TestApp(
          child: AnimalRegistrationSheet(
            granjaId: 'farm-1',
            isDark: true,
            initialQuantity: 1,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Asignar brazalete'), findsOneWidget);
      expect(find.text('Auto-asignar'), findsNothing);
      await tester.ensureVisible(find.byType(Switch).last);
      await tester.tap(find.byType(Switch).last);
      await tester.pump();
      expect(
        find.byKey(const Key('animal-single-bracelet-field')),
        findsOneWidget,
      );
    });

    testWidgets('multi mode shows chips, counts, summary, and auto assign', (
      tester,
    ) async {
      await tester.pumpWidget(
        _TestApp(
          child: AnimalRegistrationSheet(
            granjaId: 'farm-1',
            isDark: true,
            initialQuantity: 3,
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Asignar brazaletes (opcional)'));
      await tester.tap(find.byType(Switch).last);
      await tester.pumpAndSettle();
      final autoAssignButton = find.widgetWithText(TextButton, 'Auto-asignar');
      await tester.ensureVisible(autoAssignButton);
      tester.widget<TextButton>(autoAssignButton).onPressed!.call();
      await tester.pumpAndSettle();

      expect(find.text('3/3 asignados'), findsOneWidget);
      expect(find.text('Seleccionados: 3 / 3'), findsOneWidget);
      expect(find.text('#7'), findsOneWidget);
      expect(find.text('#8'), findsOneWidget);
      expect(find.text('#9'), findsOneWidget);
    });

    testWidgets('auto-selects one type and retains nullable Sin grupo', (
      tester,
    ) async {
      await tester.pumpWidget(
        _TestApp(
          child: AnimalRegistrationSheet(
            granjaId: 'farm-1',
            isDark: false,
            initialQuantity: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gallinas'), findsOneWidget);
      expect(find.text('Sin grupo'), findsOneWidget);
      final groupField = find.byKey(const Key('animal-group-field'));
      await tester.ensureVisible(groupField);
      await tester.tap(find.byKey(const Key('animal-group-dropdown')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('animal-group-option-none')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('all editable dropdown menus match their field width', (
      tester,
    ) async {
      await tester.pumpWidget(
        _TestApp(
          child: AnimalRegistrationSheet(
            granjaId: 'farm-1',
            isDark: false,
            initialQuantity: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final name in ['type', 'group', 'purpose', 'acquisition']) {
        final field = find.byKey(Key('animal-$name-field'));
        final dropdown = find.byKey(Key('animal-$name-dropdown'));
        await tester.ensureVisible(field);
        final width = tester.getSize(field).width;
        await tester.tap(dropdown);
        await tester.pumpAndSettle();

        final optionKey = switch (name) {
          'type' => const Key('animal-type-option-type-1'),
          'group' => const Key('animal-group-option-none'),
          'purpose' => const Key('animal-purpose-option-purpose-1'),
          _ => const Key('animal-acquisition-option-acquisition-1'),
        };
        final option = find.byKey(optionKey);
        final menu = find
            .ancestor(of: option, matching: find.byType(Material))
            .first;
        expect(tester.getSize(menu).width, closeTo(width, 1));
        expect(tester.getSize(option).height, greaterThanOrEqualTo(48));
        final label = switch (name) {
          'type' => 'Gallinas',
          'group' => 'Sin grupo',
          'purpose' => 'Postura',
          _ => 'Compra',
        };
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
      }
    });

    testWidgets('required purpose and acquisition validation is preserved', (
      tester,
    ) async {
      await tester.pumpWidget(
        _TestApp(
          child: AnimalRegistrationSheet(
            granjaId: 'farm-1',
            isDark: false,
            initialQuantity: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final submit = find.widgetWithText(FilledButton, 'Registrar alta');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pump();
      expect(find.text('Selecciona un propósito'), findsWidgets);
      expect(find.text('Selecciona una adquisición'), findsWidgets);
    });

    testWidgets('edit mode keeps type, group, and quantity locked', (
      tester,
    ) async {
      await tester.pumpWidget(
        _TestApp(
          child: AnimalRegistrationSheet(
            granjaId: 'farm-1',
            isDark: false,
            initialAlta: _existingAlta,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Editar alta'), findsOneWidget);
      expect(find.byKey(const Key('animal-type-dropdown')), findsNothing);
      expect(find.byKey(const Key('animal-group-dropdown')), findsNothing);
      expect(
        find.textContaining('La cantidad no se puede editar aquí'),
        findsOneWidget,
      );
      expect(find.text('Proveedor histórico'), findsOneWidget);
    });

    testWidgets('short single mode shrink-wraps below its height cap', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 1400);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        _TestApp(
          child: AnimalRegistrationSheet(
            granjaId: 'farm-1',
            isDark: false,
            initialQuantity: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .getSize(find.byKey(const Key('animal-registration-sheet')))
            .height,
        lessThan(1400 * 0.92),
      );
    });

    for (final isDark in [false, true]) {
      testWidgets(
        '${isDark ? 'dark' : 'light'} compact sheet handles keyboard landscape',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(700, 380);
          tester.view.viewInsets = const FakeViewPadding(bottom: 160);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetViewInsets);

          await tester.pumpWidget(
            _TestApp(
              theme: isDark ? ThemeData.dark(useMaterial3: true) : null,
              child: AnimalRegistrationSheet(
                granjaId: 'farm-1',
                isDark: isDark,
                initialQuantity: 1,
              ),
            ),
          );
          await tester.pumpAndSettle();

          final sheet = find.byKey(const Key('animal-registration-sheet'));
          expect(
            tester.getSize(sheet).height,
            lessThanOrEqualTo(380 - 160 + 1),
          );
          expect(
            find.byKey(const Key('animal-registration-scroll-view')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}

final _existingAlta = AltaAnimales(
  id: 'alta-1',
  granjaId: 'farm-1',
  tipoAnimalId: 'type-1',
  grupoId: 'group-1',
  propositoId: 'purpose-1',
  tipoAdquisicionId: 'acquisition-1',
  proveedor: 'Proveedor histórico',
  fechaAlta: DateTime(2026, 7, 1),
  cantidadAnimales: 3,
  createdBy: 'user-1',
  createdAt: DateTime(2026, 7, 1),
);

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child, this.theme});

  final Widget child;
  final ThemeData? theme;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        animalesRepositoryProvider.overrideWithValue(_FakeAnimalesRepository()),
      ],
      child: MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Align(alignment: Alignment.bottomCenter, child: child),
        ),
      ),
    );
  }
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
  Future<List<Grupo>> getGrupos(String granjaId) async => const [
    Grupo(
      id: 'group-1',
      granjaId: 'farm-1',
      tipoAnimalId: 'type-1',
      nombre: 'Corral Norte',
    ),
  ];

  @override
  Future<List<CatalogoItem>> getPropositos(String granjaId) async => const [
    CatalogoItem(id: 'purpose-1', nombre: 'Postura'),
  ];

  @override
  Future<List<CatalogoItem>> getTiposAdquisicion(String granjaId) async =>
      const [CatalogoItem(id: 'acquisition-1', nombre: 'Compra')];

  @override
  Future<List<int>> getAvailableBracelets(
    String granjaId,
    String tipoAnimalId,
  ) async => const [7, 8, 9, 10];

  @override
  Future<AltaAnimales> registrarAltaAnimales(dynamic input) {
    throw UnimplementedError();
  }
}

SupabaseClient _buildClient() {
  final client = SupabaseClient('https://example.supabase.co', 'anon-key');
  client.auth.stopAutoRefresh();
  return client;
}
