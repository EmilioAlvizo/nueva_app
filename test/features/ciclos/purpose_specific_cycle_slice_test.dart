import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
import 'package:rancho/core/testing/app_widget_keys.dart';
import 'package:rancho/core/theme/app_theme.dart';
import 'package:rancho/features/ciclos/data/economics_v2_supabase_repository.dart';
import 'package:rancho/features/ciclos/domain/economics_v2_lifecycle_models.dart';
import 'package:rancho/features/ciclos/domain/economics_v2_models.dart';
import 'package:rancho/features/ciclos/presentation/providers/cycle_providers.dart';
import 'package:rancho/features/ciclos/presentation/screens/finance_cycle_animals_section.dart';
import 'package:rancho/features/ciclos/presentation/screens/finance_cycle_workspace_section.dart';
import 'package:rancho/features/ciclos/presentation/widgets/finance_cycle_animals_views.dart';
import 'package:rancho/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('uses cycle-scoped sale and immutable final-result RPC contracts', () async {
    final client = _RecordingHttpClient([
      (200, _saleJson),
      (200, _finalResultJson),
    ]);
    final repository = EconomicsV2SupabaseRepository(
      SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: client,
      ),
    );

    final sale = await repository.recordCycleAnimalSale(
      EconomicsV2CycleSaleRequest(
        farmId: 'farm-1',
        cycleId: 'cycle-1',
        animalIds: const ['animal-1', 'animal-2'],
        soldOn: DateTime(2026, 9, 23),
        totalAmount: 100,
        totalWeightKg: 20,
        note: 'Sell all',
      ),
    );
    final finalResult = await repository.getFinalResult(
      farmId: 'farm-1',
      cycleId: 'cycle-1',
    );

    expect(sale.soldCount, 2);
    expect(sale.status, EconomicsV2CycleStatus.productionClosed);
    expect(finalResult.result.margin, 75);
    expect(client.identities, [
      'registrar_venta_animales_ciclo_v2:{"p_granja_id":"farm-1","p_cycle_id":"cycle-1","p_animal_ids":["animal-1","animal-2"],"p_fecha_venta":"2026-09-23","p_total_amount":100.0,"p_peso":20.0,"p_notas":"Sell all"}',
      'obtener_resultado_final_ciclo_v2:{"p_granja_id":"farm-1","p_cycle_id":"cycle-1"}',
    ]);
  });

  test('parses the current posture feed-exhaustion projection contract', () {
    final projection = EconomicsV2SavedProjection.fromJson(_projectionJson);

    expect(projection.input.feedRateKgPerBirdDay, 0.1);
    expect(projection.input.horizonDays, isNull);
    expect(projection.result.availableFeedKg, 12);
    expect(projection.result.historicalBirdDays, 15);
    expect(projection.result.remainingDays, 105);
    expect(projection.result.projectedHorizonDays, 115);
    expect(projection.result.expectedEndExclusive, DateTime(2027, 1, 6));
    expect(projection.result.weightedAverageBirds, 1.5);
  });

  testWidgets('meat overview hides generic projections', (tester) async {
    await _pump(
      tester,
      FinanceCycleOverviewView(
        detail: _detail(EconomicsV2CycleStatus.open),
        isCompatibilityMode: false,
        onSelectView: (_) {},
      ),
    );

    expect(
      find.byKey(const ValueKey(AppWidgetKeys.financeCycleProjectionsTab)),
      findsNothing,
    );
    expect(find.text('Resultado provisional'), findsWidgets);
  });

  testWidgets('meat members expose selected-or-all sale entry', (tester) async {
    await _pump(
      tester,
      FinanceCycleAnimalsMembersView(
        members: _activeMembers,
        activeCount: 2,
        exitedCount: 0,
        canAssign: true,
        canStartAssignment: true,
        canSell: true,
        onAdd: () {},
        onSell: () {},
      ),
    );

    expect(
      find.byKey(const ValueKey(AppWidgetKeys.financeCycleAnimalsSell)),
      findsOneWidget,
    );
    expect(find.text('Registrar venta'), findsOneWidget);
  });

  testWidgets('meat sale selection accepts active members safely', (
    tester,
  ) async {
    final members = EconomicsV2CycleMembers(
      members: _activeMembers,
      candidates: const [],
    );
    await _pump(
      tester,
      ProviderScope(
        child: FinanceCycleAnimalsSection(
          farmId: 'farm-1',
          cycleId: 'cycle-1',
          detail: _detail(EconomicsV2CycleStatus.open),
          members: members,
          canAssign: true,
          isPending: false,
          now: () => DateTime(2026, 9, 23),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(FinanceCycleAnimalsSection)),
    );
    final workflow = container.read(
      financeCyclesWorkflowProvider('farm-1').notifier,
    );
    workflow.openCycle('cycle-1');
    workflow.showCycleView(FinanceCyclesView.animals);
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey(AppWidgetKeys.financeCycleAnimalsSell)),
    );
    await tester.pump();
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      container.read(financeCyclesWorkflowProvider('farm-1')).selectedAnimalIds,
      ['animal-1'],
    );
  });

  testWidgets('settled card renders immutable snapshot values', (tester) async {
    await _pump(
      tester,
      FinanceCycleCloseView(
        detail: _detail(EconomicsV2CycleStatus.settled),
        readiness: _readiness,
        finalResult: EconomicsV2FinalResult.fromJson(_finalResultJson),
        isPending: false,
        onCloseProduction: () {},
        onFinalize: () {},
      ),
    );

    expect(find.text('Resultado final liquidado'), findsOneWidget);
    expect(find.text('\$100.00'), findsOneWidget);
    expect(find.text('\$75.00'), findsOneWidget);
    expect(find.text('\$999,00'), findsNothing);
  });

  testWidgets('posture projection form derives horizon from kg per bird day', (
    tester,
  ) async {
    await _pump(tester, const FinanceCycleProjectionDialog());

    expect(
      find.byKey(
        const ValueKey(AppWidgetKeys.financeCycleProjectionFeedRateKg),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey(AppWidgetKeys.financeCycleProjectionHorizonDays),
      ),
      findsNothing,
    );
  });
}

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    locale: const Locale('es'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.light,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

EconomicsV2CycleDetail _detail(EconomicsV2CycleStatus status) =>
    EconomicsV2CycleDetail(
      cycleId: 'cycle-1',
      farmId: 'farm-1',
      name: 'Meat cycle',
      status: status,
      startsOn: DateTime(2026, 9, 1),
      settledOn: status == EconomicsV2CycleStatus.settled
          ? DateTime(2026, 9, 23)
          : null,
      purposeId: 'meat-purpose',
      purposeName: 'Carne',
      purpose: EconomicsV2Purpose.carne,
      activeAnimalCount: 2,
      exitedAnimalCount: 0,
      feedCost: 50,
      directExpenseTotal: 10,
      revenue: 999,
      totalCost: 999,
      profit: 999,
      updatedAt: DateTime(2026, 9, 23),
    );

final _readiness = EconomicsV2CycleReadiness(
  cycleId: 'cycle-1',
  status: EconomicsV2CycleStatus.settled,
  canCloseProduction: false,
  canSettle: false,
  hasMembers: true,
  hasFeed: true,
  hasSaleableOutput: true,
  salesWithinOutput: true,
  openFeedCount: 0,
  reasons: const [],
);

final _activeMembers = [
  EconomicsV2CycleMember(
    animalId: 'animal-1',
    label: 'Bird #1',
    joinedOn: DateTime(2026, 9, 1),
    isActive: true,
  ),
  EconomicsV2CycleMember(
    animalId: 'animal-2',
    label: 'Bird #2',
    joinedOn: DateTime(2026, 9, 1),
    isActive: true,
  ),
];

const _saleJson = <String, dynamic>{
  'sale_id': 'sale-1',
  'cycle_id': 'cycle-1',
  'sold_count': 2,
  'status': 'production_closed',
};

const _finalResultJson = <String, dynamic>{
  'cycle_id': 'cycle-1',
  'calculation_version': 'v2',
  'settled_on': '2026-09-23',
  'result': {
    'cycle_id': 'cycle-1',
    'purpose_code': 'carne',
    'production_basis': 'saleable_kg',
    'total_cost': 25,
    'revenue': 100,
    'profit': 75,
    'margin': 75,
    'break_even': 5,
  },
};

const _projectionJson = <String, dynamic>{
  'projection_id': 'projection-1',
  'created_at': '2026-09-23T12:00:00Z',
  'calculation_version': 'v3',
  'assumptions': {
    'expected_unit_price': 3,
    'production_per_day': 4,
    'feed_rate_kg_per_bird_day': 0.1,
    'other_costs': 10,
  },
  'result': {
    'available_feed_kg': 12,
    'historical_bird_days': 15,
    'consumed_kg': 1.5,
    'remaining_kg': 10.5,
    'current_active_birds': 1,
    'remaining_days': 105,
    'projected_horizon_days': 115,
    'expected_end_exclusive': '2027-01-06',
    'weighted_average_birds': 1.5,
    'expected_units': 460,
    'projected_revenue': 1380,
    'projected_total_cost': 110,
    'projected_balance': 1270,
  },
};

final class _RecordingHttpClient extends http.BaseClient {
  _RecordingHttpClient(this._responses);

  final List<(int, Object?)> _responses;
  final List<String> identities = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body =
        jsonDecode(await request.finalize().bytesToString())
            as Map<String, dynamic>;
    final (statusCode, response) = _responses.removeAt(0);
    identities.add('${request.url.pathSegments.last}:${jsonEncode(body)}');
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(jsonEncode(response))),
      statusCode,
      headers: const {'content-type': 'application/json'},
      request: request,
    );
  }
}
