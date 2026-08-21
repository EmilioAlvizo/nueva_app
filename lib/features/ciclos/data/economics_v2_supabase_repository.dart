import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/economics_v2_lifecycle_models.dart';
import '../domain/economics_v2_lifecycle_repository.dart';
import '../domain/economics_v2_models.dart';
import '../domain/economics_v2_repository.dart';

class EconomicsV2SupabaseRepository
    implements EconomicsV2Repository, EconomicsV2LifecycleRepository {
  EconomicsV2SupabaseRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<EconomicsV2Cycle>> getCycles(String farmId) async {
    final data = await _client
        .from('economics_v2_cycle_economics')
        .select('cycle_id,granja_id,status')
        .eq('granja_id', farmId);
    return _rows(data).map(EconomicsV2Cycle.fromJson).toList();
  }

  @override
  Future<EconomicsV2Calculation> calculate({
    required String farmId,
    required String cycleId,
  }) async {
    final data = await _client.rpc<Map<String, dynamic>>(
      'calcular_ciclo_v2',
      params: {'p_granja_id': farmId, 'p_cycle_id': cycleId},
    );
    return EconomicsV2Calculation.fromJson(data);
  }

  @override
  Future<EconomicsV2Projection> project({
    required String farmId,
    required String cycleId,
    required EconomicsV2ProjectionInput input,
  }) async {
    final data = await _client.rpc<Map<String, dynamic>>(
      'proyectar_ciclo_v2',
      params: {
        'p_granja_id': farmId,
        'p_cycle_id': cycleId,
        'p_assumptions': input.toJson(),
      },
    );
    return EconomicsV2Projection.fromJson(data);
  }

  @override
  Future<void> finalize({required String farmId, required String cycleId}) =>
      _client.rpc<void>(
        'finalizar_ciclo_v2',
        params: {'p_granja_id': farmId, 'p_cycle_id': cycleId},
      );

  @override
  Future<EconomicsV2CycleCreated> createCycle(
    EconomicsV2CreateCycleRequest request,
  ) async {
    final cycleId = await _client.rpc<String>(
      'crear_ciclo_v2',
      params: {
        'p_granja_id': request.farmId,
        'p_proposito_id': request.purposeId,
        'p_starts_on': _date(request.startsOn),
      },
    );
    return EconomicsV2CycleCreated(cycleId: cycleId);
  }

  @override
  Future<EconomicsV2AnimalAssigned> assignAnimal(
    EconomicsV2AssignAnimalRequest request,
  ) async {
    await _client.rpc<void>(
      'asignar_animal_ciclo_v2',
      params: {
        'p_granja_id': request.farmId,
        'p_cycle_id': request.cycleId,
        'p_animal_id': request.animalId,
        'p_joined_on': _date(request.joinedOn),
      },
    );
    return EconomicsV2AnimalAssigned(
      cycleId: request.cycleId,
      animalId: request.animalId,
    );
  }

  @override
  Future<EconomicsV2ExpenseRecorded> recordExpense(
    EconomicsV2RecordExpenseRequest request,
  ) async {
    final expenseId = await _client.rpc<String>(
      'registrar_gasto_ciclo_v2',
      params: {
        'p_granja_id': request.farmId,
        'p_cycle_id': request.cycleId,
        'p_occurred_on': _date(request.occurredOn),
        'p_amount': request.amount,
        'p_note': request.note,
      },
    );
    return EconomicsV2ExpenseRecorded(expenseId: expenseId);
  }

  @override
  Future<EconomicsV2FeedLinked> linkFeed(
    EconomicsV2LinkFeedRequest request,
  ) async {
    final endsOn = request.endsOn;
    final feedId = await _client.rpc<String>(
      'vincular_alimento_ciclo_v2',
      params: {
        'p_granja_id': request.farmId,
        'p_cycle_id': request.cycleId,
        'p_mezcla_id': request.mixtureId,
        'p_starts_on': _date(request.startsOn),
        'p_ends_on': endsOn == null ? null : _date(endsOn),
      },
    );
    return EconomicsV2FeedLinked(feedId: feedId);
  }

  static List<Map<String, dynamic>> _rows(Object? value) => [
    for (final row in value as List? ?? const [])
      Map<String, dynamic>.from(row as Map),
  ];

  static String _date(DateTime value) =>
      value.toIso8601String().substring(0, 10);
}
