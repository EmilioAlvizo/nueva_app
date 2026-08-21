import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rancho/core/testing/app_widget_keys.dart';
import 'package:rancho/features/ciclos/domain/cycle_models.dart';
import 'package:rancho/features/ciclos/domain/cycle_repository.dart';
import 'package:rancho/features/ciclos/domain/economics_v2_models.dart';
import 'package:rancho/features/ciclos/domain/economics_v2_repository.dart';
import 'package:rancho/features/ciclos/presentation/providers/cycle_providers.dart';
import 'package:rancho/features/ciclos/presentation/screens/cycles_list_screen.dart';
import 'package:rancho/l10n/app_localizations.dart';

void main() {
  testWidgets('purpose controls present public V2 rows and returned results', (
    tester,
  ) async {
    final container = ProviderContainer.test(
      overrides: [
        cycleRepositoryProvider.overrideWithValue(_CycleRepository()),
        economicsV2RepositoryProvider.overrideWithValue(
          _EconomicsV2Repository(),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CyclesListScreen(farmId: 'farm-1'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Legacy cycle'), findsNothing);
    expect(find.text('public-v2-cycle'), findsOneWidget);
    expect(find.text('open'), findsOneWidget);
    expect(find.text('Postura'), findsOneWidget);
    expect(find.text('Carne'), findsOneWidget);
    expect(find.text('Ornamental'), findsOneWidget);
    expect(find.text('Costo atribuible'), findsOneWidget);
    expect(find.text('Ingreso canónico'), findsOneWidget);
    expect(find.text('Punto de equilibrio'), findsOneWidget);

    expect(find.text('75.00'), findsOneWidget);
    expect(find.text('100.00'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey(AppWidgetKeys.economicsV2PurposeCarne)),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('30.00'), findsOneWidget);
    expect(find.text('150.00'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey(AppWidgetKeys.economicsV2PurposeOrnamental)),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('45.00'), findsOneWidget);
    expect(find.text('180.00'), findsOneWidget);
  });

  testWidgets('V2 purpose controls expose stable selectors and semantics', (
    tester,
  ) async {
    final container = ProviderContainer.test(
      overrides: [
        cycleRepositoryProvider.overrideWithValue(_CycleRepository()),
        economicsV2RepositoryProvider.overrideWithValue(
          _EconomicsV2Repository(),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CyclesListScreen(farmId: 'farm-1'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey(AppWidgetKeys.economicsV2PurposePostura)),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey(AppWidgetKeys.economicsV2PurposeCarne)),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey(AppWidgetKeys.economicsV2PurposeOrnamental)),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Seleccionar propósito: postura'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Seleccionar propósito: carne'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Seleccionar propósito: ornamental'),
      findsOneWidget,
    );
  });

  test(
    'projection exposes its returned public result through the mutation provider',
    () async {
      final container = ProviderContainer.test(
        overrides: [
          economicsV2RepositoryProvider.overrideWithValue(
            _EconomicsV2Repository(),
          ),
        ],
      );

      final result = await container
          .read(economicsV2MutationsProvider.notifier)
          .project(
            farmId: 'farm-1',
            cycleId: 'public-v2-cycle',
            input: const EconomicsV2ProjectionInput(
              expectedUnits: 12,
              unitPrice: 8,
            ),
          );

      expect(result.projectedRevenue, 96);
      expect(container.read(economicsV2MutationsProvider).value, result);
    },
  );
}

final class _CycleRepository implements CycleRepository {
  @override
  Future<CycleAccess> getAccess(String farmId) async =>
      const CycleAccess(CycleRole.owner);

  @override
  Future<CycleCatalogs> getCatalogs() async =>
      const CycleCatalogs(products: [], metrics: []);

  @override
  Future<CycleDetail> getCycleDetail(String cycleId) async =>
      CycleDetail(cycle: _cycle, members: const []);

  @override
  Future<CycleEconomics?> getEconomics(String cycleId) async => null;

  @override
  Future<List<CycleGroup>> getGroups(String farmId) async => const [];

  @override
  Future<List<CycleMemberCandidate>> getMemberCandidates(String farmId) async =>
      const [];

  @override
  Future<List<Cycle>> getCycles(String farmId) async => [_cycle];

  @override
  Future<List<CycleTimelineItem>> getTimeline(String cycleId) async => const [];

  @override
  Future<Cycle> createCycle(CycleCreationInput input) async => _cycle;
}

final class _EconomicsV2Repository implements EconomicsV2Repository {
  var _calculationIndex = 0;

  static const _calculations = [
    EconomicsV2Calculation(
      cycleId: 'public-v2-cycle',
      purpose: EconomicsV2Purpose.postura,
      productionBasis: 'eggs',
      totalCost: 75,
      revenue: 100,
      margin: 25,
      breakEven: 1.5,
    ),
    EconomicsV2Calculation(
      cycleId: 'public-v2-cycle',
      purpose: EconomicsV2Purpose.carne,
      productionBasis: 'animals_sold',
      totalCost: 120,
      revenue: 150,
      margin: 30,
      breakEven: 2.5,
    ),
    EconomicsV2Calculation(
      cycleId: 'public-v2-cycle',
      purpose: EconomicsV2Purpose.ornamental,
      productionBasis: 'specimens_sold',
      totalCost: 135,
      revenue: 180,
      margin: 45,
      breakEven: 3.5,
    ),
  ];

  @override
  Future<EconomicsV2Calculation> calculate({
    required String farmId,
    required String cycleId,
  }) async {
    final result = _calculations[_calculationIndex];
    _calculationIndex = (_calculationIndex + 1) % _calculations.length;
    return result;
  }

  @override
  Future<List<EconomicsV2Cycle>> getCycles(String farmId) async => const [
    EconomicsV2Cycle(id: 'public-v2-cycle', farmId: 'farm-1', status: 'open'),
  ];

  @override
  Future<EconomicsV2Projection> project({
    required String farmId,
    required String cycleId,
    required EconomicsV2ProjectionInput input,
  }) async => EconomicsV2Projection(
    cycleId: cycleId,
    purpose: EconomicsV2Purpose.postura,
    productionBasis: 'eggs',
    projectedRevenue: input.expectedUnits * input.unitPrice,
    projectedTotalCost: 75,
    projectedMargin: (input.expectedUnits * input.unitPrice) - 75,
  );

  @override
  Future<void> finalize({
    required String farmId,
    required String cycleId,
  }) async {}
}

final _cycle = Cycle(
  id: 'cycle-1',
  farmId: 'farm-1',
  animalTypeId: 'type-1',
  productId: 'product-1',
  productCode: 'huevo',
  productName: 'Eggs',
  animalTypeName: 'Hen',
  startedAt: DateTime(2026),
  isActive: true,
  version: 1,
  name: 'Legacy cycle',
);
