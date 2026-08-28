import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
import 'package:rancho/features/ciclos/data/economics_v2_supabase_repository.dart';
import 'package:rancho/features/ciclos/domain/economics_v2_lifecycle_models.dart';
import 'package:rancho/features/ciclos/domain/economics_v2_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('cycle detail compatibility', () {
    test(
      'falls back to the exact legacy summary and calculation contracts only '
      'when the detail RPC is missing',
      () async {
        final client = _RecordingHttpClient([
          (404, _missingDetailFunctionJson),
          (200, _legacySummariesJson),
          (200, _legacyCalculationJson),
        ]);
        final repository = _repository(client);

        final detail = await repository.getCycleDetail(
          farmId: 'farm-1',
          cycleId: 'cycle-1',
        );

        expect(detail.cycleId, 'cycle-1');
        expect(detail.farmId, 'farm-1');
        expect(detail.status, EconomicsV2CycleStatus.productionClosed);
        expect(detail.productionClosedOn, DateTime(2026, 8, 23));
        expect(detail.isCompatibilityMode, isTrue);
        expect(detail.totalCost, 30);
        expect(detail.profit, 30);
        expect(_identities(client), [
          'obtener_detalle_ciclo_v2:${_scopeBody()}',
          'listar_resumen_ciclos_v2:{"p_granja_id":"farm-1"}',
          'calcular_ciclo_v2:${_scopeBody()}',
        ]);
      },
    );

    test('does not hide authorization failures behind compatibility data', () {
      final client = _RecordingHttpClient([
        (
          403,
          {
            'message': 'Cycle access denied',
            'code': '42501',
            'details': null,
            'hint': null,
          },
        ),
      ]);
      final repository = _repository(client);

      expect(
        repository.getCycleDetail(farmId: 'farm-1', cycleId: 'cycle-1'),
        throwsA(
          isA<PostgrestException>().having(
            (error) => error.code,
            'code',
            '42501',
          ),
        ),
      );
    });

    test('does not fall back for a malformed detail payload', () {
      final client = _RecordingHttpClient([
        (200, {'cycle_id': 'cycle-1'}),
      ]);
      final repository = _repository(client);

      expect(
        repository.getCycleDetail(farmId: 'farm-1', cycleId: 'cycle-1'),
        throwsA(anything),
      );
    });

    test('does not fall back when PGRST202 names another function', () {
      final client = _RecordingHttpClient([
        (
          404,
          {
            'message': 'Could not find the function public.other_function',
            'code': 'PGRST202',
            'details': null,
            'hint': null,
          },
        ),
      ]);
      final repository = _repository(client);

      expect(
        repository.getCycleDetail(farmId: 'farm-1', cycleId: 'cycle-1'),
        throwsA(
          isA<PostgrestException>().having(
            (error) => error.code,
            'code',
            'PGRST202',
          ),
        ),
      );
    });

    test('does not fall back for transport failures', () {
      final repository = _repository(_ThrowingHttpClient());

      expect(
        repository.getCycleDetail(farmId: 'farm-1', cycleId: 'cycle-1'),
        throwsA(isA<http.ClientException>()),
      );
    });
  });

  test('reads every Finance cycle workspace contract exactly', () async {
    final client = _RecordingHttpClient([
      (200, _detailJson),
      (200, _membersJson),
      (200, _feedsJson),
      (200, _expensesJson),
      (200, _projectionsJson),
      (200, _readinessJson),
    ]);
    final repository = _repository(client);

    final detail = await repository.getCycleDetail(
      farmId: 'farm-1',
      cycleId: 'cycle-1',
    );
    final members = await repository.getCycleMembers(
      farmId: 'farm-1',
      cycleId: 'cycle-1',
    );
    final feeds = await repository.getCycleFeeds(
      farmId: 'farm-1',
      cycleId: 'cycle-1',
    );
    final expenses = await repository.getCycleExpenses(
      farmId: 'farm-1',
      cycleId: 'cycle-1',
    );
    final projections = await repository.getCycleProjections(
      farmId: 'farm-1',
      cycleId: 'cycle-1',
    );
    final readiness = await repository.getCycleReadiness(
      farmId: 'farm-1',
      cycleId: 'cycle-1',
    );

    expect(detail.status, EconomicsV2CycleStatus.open);
    expect(detail.purpose, EconomicsV2Purpose.postura);
    expect(detail.activeAnimalCount, 2);
    expect(detail.marginPercentage, 50);
    expect(members.members.single.groupNameSnapshot, 'North coop');
    expect(members.candidates.single.animalId, 'animal-2');
    expect(feeds.intervals.single.isActive, isTrue);
    expect(feeds.candidates.single.mixtureId, 'mixture-2');
    expect(expenses.single.category, 'Veterinary');
    expect(projections.single.input.expectedUnitPrice, 3.5);
    expect(readiness.canCloseProduction, isTrue);
    expect(readiness.canSettle, isFalse);
    expect(_identities(client), [
      'obtener_detalle_ciclo_v2:${_scopeBody()}',
      'listar_animales_ciclo_v2:${_scopeBody()}',
      'listar_alimentos_ciclo_v2:${_scopeBody()}',
      'listar_gastos_ciclo_v2:${_scopeBody()}',
      'listar_proyecciones_ciclo_v2:${_scopeBody()}',
      'obtener_preparacion_cierre_ciclo_v2:${_scopeBody()}',
    ]);
  });

  test('writes canonical payloads and returns source-of-truth results', () async {
    final client = _RecordingHttpClient([
      (200, null),
      (200, 'feed-2'),
      (200, 'expense-2'),
      (200, _projectionJson),
      (200, _closedDetailJson),
      (200, _finalizationJson),
    ]);
    final repository = _repository(client);

    await repository.assignAnimal(
      EconomicsV2AssignAnimalRequest(
        farmId: 'farm-1',
        cycleId: 'cycle-1',
        animalId: 'animal-2',
        joinedOn: DateTime(2026, 8, 20),
      ),
    );
    await repository.linkFeed(
      EconomicsV2LinkFeedRequest(
        farmId: 'farm-1',
        cycleId: 'cycle-1',
        mixtureId: 'mixture-2',
        startsOn: DateTime(2026, 8, 21),
      ),
    );
    await repository.recordExpense(
      EconomicsV2RecordExpenseRequest(
        farmId: 'farm-1',
        cycleId: 'cycle-1',
        occurredOn: DateTime(2026, 8, 22),
        amount: 18.75,
        category: 'Veterinary',
        note: 'Routine treatment',
      ),
    );
    final projection = await repository.saveProjection(
      farmId: 'farm-1',
      cycleId: 'cycle-1',
      input: const EconomicsV2ProjectionInput(
        expectedUnitPrice: 3.5,
        productionPerDay: 20,
        feedPerDay: 4,
        otherCosts: 10,
        horizonDays: 30,
      ),
      note: 'Conservative scenario',
    );
    final closed = await repository.closeProduction(
      EconomicsV2CloseProductionRequest(
        farmId: 'farm-1',
        cycleId: 'cycle-1',
        closedOn: DateTime(2026, 8, 23),
      ),
    );
    final finalized = await repository.finalize(
      farmId: 'farm-1',
      cycleId: 'cycle-1',
    );

    expect(projection.result.projectedRevenue, 2100);
    expect(closed.status, EconomicsV2CycleStatus.productionClosed);
    expect(finalized.status, EconomicsV2CycleStatus.settled);
    expect(finalized.calculationVersion, 'v2');
    expect(_identities(client), [
      'asignar_animal_ciclo_v2:{"p_granja_id":"farm-1","p_cycle_id":"cycle-1","p_animal_id":"animal-2","p_joined_on":"2026-08-20"}',
      'reemplazar_alimento_ciclo_v2:{"p_granja_id":"farm-1","p_cycle_id":"cycle-1","p_mezcla_id":"mixture-2","p_starts_on":"2026-08-21","p_ends_on":null}',
      'registrar_gasto_ciclo_v2_con_categoria:{"p_granja_id":"farm-1","p_cycle_id":"cycle-1","p_occurred_on":"2026-08-22","p_amount":18.75,"p_category":"Veterinary","p_note":"Routine treatment"}',
      'guardar_proyeccion_ciclo_v2:{"p_granja_id":"farm-1","p_cycle_id":"cycle-1","p_assumptions":{"expected_unit_price":3.5,"production_per_day":20.0,"feed_per_day":4.0,"other_costs":10.0,"horizon_days":30},"p_note":"Conservative scenario"}',
      'cerrar_produccion_ciclo_v2:{"p_granja_id":"farm-1","p_cycle_id":"cycle-1","p_closed_on":"2026-08-23"}',
      'finalizar_ciclo_v2:${_scopeBody()}',
    ]);
  });
}

EconomicsV2SupabaseRepository _repository(http.Client client) =>
    EconomicsV2SupabaseRepository(
      SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: client,
      ),
    );

String _scopeBody() => '{"p_granja_id":"farm-1","p_cycle_id":"cycle-1"}';

List<String> _identities(_RecordingHttpClient client) => [
  for (final request in client.requests)
    '${request.name}:${jsonEncode(request.body)}',
];

const _detailJson = <String, dynamic>{
  'cycle_id': 'cycle-1',
  'granja_id': 'farm-1',
  'name': 'August posture',
  'status': 'open',
  'starts_on': '2026-08-01',
  'planned_ends_on': '2026-09-01',
  'production_closed_on': null,
  'settled_on': null,
  'purpose_id': 'purpose-1',
  'purpose_name': 'Posture',
  'purpose_code': 'postura',
  'active_animal_count': 2,
  'exited_animal_count': 1,
  'feed_cost': 20,
  'direct_expense_total': 10,
  'revenue': 60,
  'total_cost': 30,
  'profit': 30,
  'margin_percentage': 50,
  'unit_cost': 1.5,
  'break_even': null,
  'latest_group_name_snapshot': 'North coop',
  'updated_at': '2026-08-22T12:00:00Z',
};

const _missingDetailFunctionJson = <String, dynamic>{
  'message':
      'Could not find the function public.obtener_detalle_ciclo_v2'
      '(p_cycle_id, p_granja_id) in the schema cache',
  'code': 'PGRST202',
  'details':
      'Searched for the function public.obtener_detalle_ciclo_v2 with '
      'parameters p_cycle_id, p_granja_id',
  'hint': null,
};

const _legacySummariesJson = <Map<String, dynamic>>[
  {
    'cycle_id': 'cycle-1',
    'granja_id': 'farm-1',
    'status': 'closed',
    'starts_on': '2026-08-01',
    'ends_on': '2026-08-23',
    'purpose_id': 'purpose-1',
    'purpose_name': 'Posture',
    'active_animal_count': 2,
    'exited_animal_count': 1,
    'direct_expense_total': 10,
    'linked_mixture_count': 1,
    'latest_linked_group_name': 'North coop',
  },
];

const _legacyCalculationJson = <String, dynamic>{
  'cycle_id': 'cycle-1',
  'purpose_code': 'postura',
  'production_basis': 'good_eggs',
  'feed_cost': 20,
  'direct_cost': 10,
  'revenue': 60,
  'total_cost': 30,
  'profit': 30,
  'margin': 30,
  'margin_percentage': 50,
  'unit_cost': 1.5,
  'break_even': null,
};

final _closedDetailJson = <String, dynamic>{
  ..._detailJson,
  'status': 'production_closed',
  'production_closed_on': '2026-08-23',
};

const _membersJson = <String, dynamic>{
  'members': [
    {
      'animal_id': 'animal-1',
      'label': 'Bird 101',
      'group_name_snapshot': 'North coop',
      'joined_on': '2026-08-01',
      'left_on': null,
      'is_active': true,
    },
  ],
  'candidates': [
    {'animal_id': 'animal-2', 'label': 'Bird 102', 'group_name': 'North coop'},
  ],
};

const _feedsJson = <String, dynamic>{
  'intervals': [
    {
      'feed_id': 'feed-1',
      'mixture_id': 'mixture-1',
      'mixture_label': 'Mixture 01/08/2026',
      'group_name_snapshot': 'North coop',
      'starts_on': '2026-08-01',
      'ends_on': null,
      'cost': 20,
    },
  ],
  'candidates': [
    {
      'mixture_id': 'mixture-2',
      'mixture_label': 'Mixture 21/08/2026',
      'group_name': 'North coop',
    },
  ],
};

const _expensesJson = <Map<String, dynamic>>[
  {
    'expense_id': 'expense-1',
    'occurred_on': '2026-08-10',
    'amount': 10,
    'category': 'Veterinary',
    'note': 'Routine treatment',
  },
];

const _projectionJson = <String, dynamic>{
  'projection_id': 'projection-1',
  'created_at': '2026-08-20T12:00:00Z',
  'note': 'Conservative scenario',
  'calculation_version': 'v2',
  'assumptions': {
    'expected_unit_price': 3.5,
    'production_per_day': 20,
    'feed_per_day': 4,
    'other_costs': 10,
    'horizon_days': 30,
  },
  'result': {
    'expected_units': 600,
    'projected_revenue': 2100,
    'projected_total_cost': 40,
    'projected_balance': 2060,
  },
};

const _projectionsJson = <Map<String, dynamic>>[_projectionJson];

const _readinessJson = <String, dynamic>{
  'cycle_id': 'cycle-1',
  'status': 'open',
  'can_close_production': true,
  'can_settle': false,
  'has_members': true,
  'has_feed': true,
  'has_saleable_output': true,
  'sales_within_output': true,
  'open_feed_count': 1,
  'reasons': ['production_not_closed'],
};

const _finalizationJson = <String, dynamic>{
  'cycle_id': 'cycle-1',
  'status': 'settled',
  'calculation_version': 'v2',
  'settled_on': '2026-08-23',
  'result': {
    'cycle_id': 'cycle-1',
    'purpose_code': 'postura',
    'production_basis': 'eggs',
    'total_cost': 30,
    'revenue': 60,
    'profit': 30,
    'margin_percentage': 50,
    'unit_cost': 1.5,
    'break_even': null,
  },
};

final class _RpcRequest {
  const _RpcRequest(this.name, this.body);

  final String name;
  final Map<String, dynamic> body;
}

final class _RecordingHttpClient extends http.BaseClient {
  _RecordingHttpClient(this._responses);

  final List<(int, Object?)> _responses;
  final List<_RpcRequest> requests = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body =
        jsonDecode(await request.finalize().bytesToString())
            as Map<String, dynamic>;
    final (statusCode, response) = _responses.removeAt(0);
    requests.add(_RpcRequest(request.url.pathSegments.last, body));
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(jsonEncode(response))),
      statusCode,
      headers: const {'content-type': 'application/json'},
      request: request,
    );
  }
}

final class _ThrowingHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw http.ClientException('Network unavailable', request.url);
  }
}
