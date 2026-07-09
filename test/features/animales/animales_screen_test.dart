import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nueva_app/features/animales/animales_provider.dart';
import 'package:nueva_app/features/animales/animales_repository.dart'
    show AnimalesRepository, ConteoGrupo, NoGroupOverview;
import 'package:nueva_app/features/animales/animales_screen.dart';
import 'package:nueva_app/features/model/altaAnimales/altaAnimales.dart';
import 'package:nueva_app/features/model/animal/animal.dart';
import 'package:nueva_app/features/model/bajaAnimal/baja_animal.dart';
import 'package:nueva_app/features/model/grupo/grupo.dart';
import 'package:nueva_app/features/model/tipoAnimal/tipoAnimal.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('AnimalesScreen', () {
    testWidgets('shows the exact redesigned tab order', (tester) async {
      await tester.pumpWidget(
        _ScreenTestApp(repository: _ScreenFakeRepository.empty()),
      );

      await tester.pumpAndSettle();

      final labels = ['Grupos', 'Animales', 'Altas', 'Bajas', 'Tipos'];
      for (final label in labels) {
        expect(find.text(label), findsWidgets);
      }
      expect(find.text('Ejemplares'), findsNothing);
      expect(find.text('Lotes'), findsNothing);

      final positions = labels
          .map((label) => tester.getTopLeft(find.text(label).first).dx)
          .toList();
      expect(positions, orderedEquals([...positions]..sort()));
    });

    testWidgets('renders the Sin grupo card with counts and latest altas', (
      tester,
    ) async {
      await tester.pumpWidget(
        _ScreenTestApp(repository: _ScreenFakeRepository.withNoGroupData()),
      );

      await tester.pumpAndSettle();

      expect(find.text('Sin grupo'), findsOneWidget);
      expect(find.text('2 activos'), findsOneWidget);
      expect(find.text('1 bajas'), findsOneWidget);
      expect(find.text('3 animales'), findsOneWidget);
      expect(find.text('2 animales'), findsOneWidget);
      expect(find.text('1 animal'), findsOneWidget);
    });
  });
}

class _ScreenTestApp extends StatelessWidget {
  const _ScreenTestApp({required this.repository});

  final AnimalesRepository repository;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [animalesRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: AnimalesScreen(granjaId: 'farm-1')),
    );
  }
}

class _ScreenFakeRepository extends AnimalesRepository {
  _ScreenFakeRepository({required this.noGroupOverview})
    : groups = const [], super(_buildClient());

  factory _ScreenFakeRepository.empty() => _ScreenFakeRepository(
    noGroupOverview: const NoGroupOverview(
      activeCount: 0,
      deadCount: 0,
      latestAltas: [],
    ),
  );

  factory _ScreenFakeRepository.withNoGroupData() => _ScreenFakeRepository(
    noGroupOverview: NoGroupOverview(
      activeCount: 2,
      deadCount: 1,
      latestAltas: [_alta('alta-3', 3), _alta('alta-2', 2), _alta('alta-1', 1)],
    ),
  );

  final NoGroupOverview noGroupOverview;
  final List<Grupo> groups;

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
  Future<List<Grupo>> getGrupos(String granjaId) async => groups;

  @override
  Future<Map<String, ConteoGrupo>> getConteosGrupos(String granjaId) async =>
      {};

  @override
  Future<NoGroupOverview> getNoGroupOverview(String granjaId) async =>
      noGroupOverview;

  @override
  Future<List<AltaAnimales>> vistaAltasAnimales(String grupoId) async =>
      const [];

  @override
  Future<List<Animal>> getAnimales(String granjaId) async => const [];

  @override
  Future<List<BajaAnimal>> getBajasAnimales(String granjaId) async => const [];
}

AltaAnimales _alta(String id, int count) => AltaAnimales(
  id: id,
  granjaId: 'farm-1',
  tipoAnimalId: 'type-1',
  fechaAlta: DateTime.utc(2026, 7, 8),
  cantidadAnimales: count,
  createdBy: 'user-1',
  createdAt: DateTime.utc(2026, 7, 8, 12),
);

SupabaseClient _buildClient() {
  final client = SupabaseClient('https://example.supabase.co', 'anon-key');
  client.auth.stopAutoRefresh();
  return client;
}
