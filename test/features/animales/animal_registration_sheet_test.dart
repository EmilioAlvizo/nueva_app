import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rancho/features/animales/animales_provider.dart';
import 'package:rancho/features/animales/animales_repository.dart'
    show AnimalesRepository;
import 'package:rancho/features/model/altaAnimales/altaAnimales.dart';
import 'package:rancho/features/model/altaAnimales/animal_registration_sheet.dart';
import 'package:rancho/features/model/catalogoItem/catalogo_item.dart';
import 'package:rancho/features/model/grupo/grupo.dart';
import 'package:rancho/features/model/tipoAnimal/tipoAnimal.dart';
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
      final autoAssignButton = find.widgetWithText(TextButton, 'Auto-asignar');
      await tester.ensureVisible(autoAssignButton);
      tester.widget<TextButton>(autoAssignButton).onPressed!.call();
      await tester.pumpAndSettle();

      expect(find.text('3/3 brazaletes asignados'), findsOneWidget);
      expect(find.text('Pendientes: 0'), findsOneWidget);
      expect(find.text('#7'), findsOneWidget);
      expect(find.text('#8'), findsOneWidget);
      expect(find.text('#9'), findsOneWidget);
    });
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        animalesRepositoryProvider.overrideWithValue(_FakeAnimalesRepository()),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
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
