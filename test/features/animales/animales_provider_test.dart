import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rancho/features/animales/animales_provider.dart';
import 'package:rancho/features/animales/animales_repository.dart'
    show AnimalesRepository, NoGroupOverview;
import 'package:rancho/features/model/altaAnimales/altaAnimales.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('Animales providers', () {
    test(
      'altasByFarmProvider delegates to the repository with the group filter',
      () async {
        final repository = _ProviderFakeRepository();
        final container = ProviderContainer(
          overrides: [animalesRepositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(container.dispose);

        final result = await container.read(
          altasByFarmProvider(
            const AltasQuery(granjaId: 'farm-1', grupoId: 'group-1'),
          ).future,
        );

        expect(result.map((alta) => alta.id).toList(), ['alta-1']);
        expect(
          repository.lastAltasQuery,
          const AltasQuery(granjaId: 'farm-1', grupoId: 'group-1'),
        );
      },
    );

    test('noGroupOverviewProvider returns the repository overview', () async {
      final repository = _ProviderFakeRepository();
      final container = ProviderContainer(
        overrides: [animalesRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final overview = await container.read(
        noGroupOverviewProvider('farm-1').future,
      );

      expect(overview.activeCount, 2);
      expect(overview.deadCount, 1);
      expect(overview.latestAltas.map((alta) => alta.id).toList(), ['alta-1']);
    });

    test(
      'availableBraceletsProvider returns available bracelets for the selected type',
      () async {
        final repository = _ProviderFakeRepository();
        final container = ProviderContainer(
          overrides: [animalesRepositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(container.dispose);

        final bracelets = await container.read(
          availableBraceletsProvider(
            const BraceletAvailabilityQuery(
              granjaId: 'farm-1',
              tipoAnimalId: 'type-1',
            ),
          ).future,
        );

        expect(bracelets, [7, 8, 9]);
        expect(
          repository.lastBraceletQuery,
          const BraceletAvailabilityQuery(
            granjaId: 'farm-1',
            tipoAnimalId: 'type-1',
          ),
        );
      },
    );
  });
}

class _ProviderFakeRepository extends AnimalesRepository {
  _ProviderFakeRepository() : super(_buildClient());

  AltasQuery? lastAltasQuery;
  BraceletAvailabilityQuery? lastBraceletQuery;

  @override
  Future<List<AltaAnimales>> getAltas(
    String granjaId, {
    String? grupoId,
  }) async {
    lastAltasQuery = AltasQuery(granjaId: granjaId, grupoId: grupoId);
    return [_alta()];
  }

  @override
  Future<NoGroupOverview> getNoGroupOverview(String granjaId) async =>
      NoGroupOverview(activeCount: 2, deadCount: 1, latestAltas: [_alta()]);

  @override
  Future<List<int>> getAvailableBracelets(
    String granjaId,
    String tipoAnimalId,
  ) async {
    lastBraceletQuery = BraceletAvailabilityQuery(
      granjaId: granjaId,
      tipoAnimalId: tipoAnimalId,
    );
    return [7, 8, 9];
  }

  static AltaAnimales _alta() => AltaAnimales(
    id: 'alta-1',
    granjaId: 'farm-1',
    tipoAnimalId: 'type-1',
    fechaAlta: DateTime.utc(2026, 7, 8),
    cantidadAnimales: 3,
    createdBy: 'user-1',
    createdAt: DateTime.utc(2026, 7, 8, 12),
  );
}

SupabaseClient _buildClient() {
  final client = SupabaseClient('https://example.supabase.co', 'anon-key');
  client.auth.stopAutoRefresh();
  return client;
}
