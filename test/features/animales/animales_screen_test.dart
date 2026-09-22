import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rancho/features/animales/animales_provider.dart';
import 'package:rancho/features/animales/animales_repository.dart'
    show
        AltaDistribution,
        AltaGroupSegment,
        AnimalesRepository,
        ConteoGrupo,
        NoGroupOverview,
        NoGroupTypeOverview;
import 'package:rancho/features/animales/animales_screen.dart';
import 'package:rancho/features/model/altaAnimales/altaAnimales.dart';
import 'package:rancho/features/model/animal/animal.dart';
import 'package:rancho/features/model/bajaAnimal/baja_animal.dart';
import 'package:rancho/features/model/grupo/grupo.dart';
import 'package:rancho/features/model/tipoAnimal/tipoAnimal.dart';
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

    testWidgets('renders no-group type summaries and alta distribution', (
      tester,
    ) async {
      await tester.pumpWidget(
        _ScreenTestApp(repository: _ScreenFakeRepository.withNoGroupData()),
      );

      await tester.pumpAndSettle();

      expect(find.text('Sin grupo'), findsOneWidget);
      expect(find.text('Gallinas'), findsOneWidget);
      expect(find.text('3 animales sin asignar a un grupo'), findsOneWidget);
      expect(find.text('Ver altas'), findsOneWidget);

      await tester.tap(find.text('Ver altas'));
      await tester.pumpAndSettle();

      expect(find.text('3 de 3 aquí'), findsOneWidget);
      expect(find.text('2 vivos · 1 baja'), findsOneWidget);
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
  _ScreenFakeRepository({
    required this.noGroupOverview,
    this.distributions = const [],
  }) : groups = const [],
       super(_buildClient());

  factory _ScreenFakeRepository.empty() => _ScreenFakeRepository(
    noGroupOverview: const NoGroupOverview(
      activeCount: 0,
      deadCount: 0,
      latestAltas: [],
    ),
  );

  factory _ScreenFakeRepository.withNoGroupData() {
    final alta = _alta('alta-3', 3);
    return _ScreenFakeRepository(
      noGroupOverview: NoGroupOverview(
        activeCount: 2,
        inactiveCount: 1,
        latestAltas: [alta],
        typeSummaries: [
          NoGroupTypeOverview(
            tipoAnimalId: 'type-1',
            activeCount: 2,
            inactiveCount: 1,
            latestAltas: [alta],
          ),
        ],
      ),
      distributions: [
        AltaDistribution(
          alta: alta,
          segments: [
            AltaGroupSegment(
              alta: alta,
              grupoId: null,
              cantidadAqui: 3,
              vivosAqui: 2,
              inactivosAqui: 1,
              bajasAqui: 1,
              brazaletes: const [],
              isDistributed: false,
              requiresBajasDeletion: true,
            ),
          ],
        ),
      ],
    );
  }

  final NoGroupOverview noGroupOverview;
  final List<AltaDistribution> distributions;
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
  Future<List<AltaDistribution>> getAltaDistributions(String granjaId) async =>
      distributions;

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
