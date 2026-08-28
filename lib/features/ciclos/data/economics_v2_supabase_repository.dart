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
  Future<EconomicsV2FarmAccess> getAccess(String farmId) async {
    final data = await _client.rpc<Map<String, dynamic>>(
      'obtener_acceso_ciclos_v2',
      params: {'p_granja_id': farmId},
    );
    return EconomicsV2FarmAccess(
      farmId: data['granja_id'] as String,
      enabled: data['enabled'] as bool,
      role: data['role'] as String,
      canEdit: data['can_edit'] as bool,
    );
  }

  @override
  Future<List<EconomicsV2CycleSummary>> getCycleSummaries(String farmId) async {
    final data = await _client.rpc<List<dynamic>>(
      'listar_resumen_ciclos_v2',
      params: {'p_granja_id': farmId},
    );
    return [
      for (final row in _rows(data))
        EconomicsV2CycleSummary(
          cycleId: row['cycle_id'] as String,
          farmId: row['granja_id'] as String,
          status: row['status'] as String,
          startsOn: DateTime.parse(row['starts_on'] as String),
          endsOn: switch (row['ends_on']) {
            final String value => DateTime.parse(value),
            _ => null,
          },
          purposeId: row['purpose_id'] as String,
          purposeName: row['purpose_name'] as String,
          activeAnimalCount: (row['active_animal_count'] as num).toInt(),
          exitedAnimalCount: (row['exited_animal_count'] as num).toInt(),
          directExpenseTotal: (row['direct_expense_total'] as num).toDouble(),
          linkedMixtureCount: (row['linked_mixture_count'] as num).toInt(),
          latestLinkedGroupName: row['latest_linked_group_name'] as String?,
        ),
    ];
  }

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
  Future<EconomicsV2CycleDetail> getCycleDetail({
    required String farmId,
    required String cycleId,
  }) async {
    try {
      final data = await _scopedRpc(
        'obtener_detalle_ciclo_v2',
        farmId,
        cycleId,
      );
      return EconomicsV2CycleDetail.fromJson(data);
    } on PostgrestException catch (error) {
      if (!_isMissingDetailFunction(error)) rethrow;
      return _getCompatibilityCycleDetail(farmId: farmId, cycleId: cycleId);
    }
  }

  @override
  Future<EconomicsV2CycleMembers> getCycleMembers({
    required String farmId,
    required String cycleId,
  }) async {
    final data = await _scopedRpc('listar_animales_ciclo_v2', farmId, cycleId);
    return EconomicsV2CycleMembers.fromJson(data);
  }

  @override
  Future<EconomicsV2CycleFeeds> getCycleFeeds({
    required String farmId,
    required String cycleId,
  }) async {
    final data = await _scopedRpc('listar_alimentos_ciclo_v2', farmId, cycleId);
    return EconomicsV2CycleFeeds.fromJson(data);
  }

  @override
  Future<List<EconomicsV2CycleExpense>> getCycleExpenses({
    required String farmId,
    required String cycleId,
  }) async {
    final data = await _client.rpc<List<dynamic>>(
      'listar_gastos_ciclo_v2',
      params: _scope(farmId, cycleId),
    );
    return [
      for (final row in _rows(data)) EconomicsV2CycleExpense.fromJson(row),
    ];
  }

  @override
  Future<List<EconomicsV2SavedProjection>> getCycleProjections({
    required String farmId,
    required String cycleId,
  }) async {
    final data = await _client.rpc<List<dynamic>>(
      'listar_proyecciones_ciclo_v2',
      params: _scope(farmId, cycleId),
    );
    return [
      for (final row in _rows(data)) EconomicsV2SavedProjection.fromJson(row),
    ];
  }

  @override
  Future<EconomicsV2CycleReadiness> getCycleReadiness({
    required String farmId,
    required String cycleId,
  }) async {
    final data = await _scopedRpc(
      'obtener_preparacion_cierre_ciclo_v2',
      farmId,
      cycleId,
    );
    return EconomicsV2CycleReadiness.fromJson(data);
  }

  @override
  Future<EconomicsV2SavedProjection> saveProjection({
    required String farmId,
    required String cycleId,
    required EconomicsV2ProjectionInput input,
    String? note,
  }) async {
    final data = await _client.rpc<Map<String, dynamic>>(
      'guardar_proyeccion_ciclo_v2',
      params: {
        ..._scope(farmId, cycleId),
        'p_assumptions': input.toJson(),
        'p_note': note,
      },
    );
    return EconomicsV2SavedProjection.fromJson(data);
  }

  @override
  Future<EconomicsV2CycleDetail> closeProduction(
    EconomicsV2CloseProductionRequest request,
  ) async {
    final data = await _client.rpc<Map<String, dynamic>>(
      'cerrar_produccion_ciclo_v2',
      params: {
        ..._scope(request.farmId, request.cycleId),
        'p_closed_on': _date(request.closedOn),
      },
    );
    return EconomicsV2CycleDetail.fromJson(data);
  }

  @override
  Future<EconomicsV2Finalization> finalize({
    required String farmId,
    required String cycleId,
  }) async {
    final data = await _client.rpc<Map<String, dynamic>>(
      'finalizar_ciclo_v2',
      params: _scope(farmId, cycleId),
    );
    return EconomicsV2Finalization.fromJson(data);
  }

  @override
  Future<EconomicsV2CycleCreated> createCycle(
    EconomicsV2CreateCycleRequest request,
  ) async {
    final cycleId = await _client.rpc<String>(
      'crear_ciclo_v2_con_fechas',
      params: {
        'p_granja_id': request.farmId,
        'p_proposito_id': request.purposeId,
        'p_starts_on': _date(request.startsOn),
        'p_ends_on': switch (request.endsOn) {
          final value? => _date(value),
          null => null,
        },
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
    final category = request.category;
    final expenseId = await _client.rpc<String>(
      category == null
          ? 'registrar_gasto_ciclo_v2'
          : 'registrar_gasto_ciclo_v2_con_categoria',
      params: {
        'p_granja_id': request.farmId,
        'p_cycle_id': request.cycleId,
        'p_occurred_on': _date(request.occurredOn),
        'p_amount': request.amount,
        ...switch (category) {
          final value? => {'p_category': value},
          null => const <String, dynamic>{},
        },
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
      'reemplazar_alimento_ciclo_v2',
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

  Future<EconomicsV2CycleDetail> _getCompatibilityCycleDetail({
    required String farmId,
    required String cycleId,
  }) async {
    final summaries = await getCycleSummaries(farmId);
    final summary = summaries.singleWhere(
      (candidate) => candidate.farmId == farmId && candidate.cycleId == cycleId,
    );
    final calculation = await _scopedRpc('calcular_ciclo_v2', farmId, cycleId);
    final status = EconomicsV2CycleStatus.fromCode(summary.status);

    return EconomicsV2CycleDetail(
      cycleId: summary.cycleId,
      farmId: summary.farmId,
      name: null,
      status: status,
      startsOn: summary.startsOn,
      plannedEndsOn: status == EconomicsV2CycleStatus.open
          ? summary.endsOn
          : null,
      productionClosedOn: status == EconomicsV2CycleStatus.productionClosed
          ? summary.endsOn
          : null,
      settledOn: null,
      purposeId: summary.purposeId,
      purposeName: summary.purposeName,
      purpose: EconomicsV2Purpose.fromCode(
        calculation['purpose_code'] as String,
      ),
      activeAnimalCount: summary.activeAnimalCount,
      exitedAnimalCount: summary.exitedAnimalCount,
      feedCost: (calculation['feed_cost'] as num).toDouble(),
      directExpenseTotal: summary.directExpenseTotal,
      revenue: (calculation['revenue'] as num).toDouble(),
      totalCost: (calculation['total_cost'] as num).toDouble(),
      profit: (calculation['profit'] as num).toDouble(),
      marginPercentage: (calculation['margin_percentage'] as num?)?.toDouble(),
      unitCost: (calculation['unit_cost'] as num?)?.toDouble(),
      breakEven: (calculation['break_even'] as num?)?.toDouble(),
      latestGroupNameSnapshot: summary.latestLinkedGroupName,
      updatedAt: null,
      isCompatibilityMode: true,
    );
  }

  static bool _isMissingDetailFunction(PostgrestException error) {
    if (error.code != 'PGRST202') return false;
    final description = '${error.message} ${error.details} ${error.hint}';
    return description.contains('obtener_detalle_ciclo_v2');
  }

  Future<Map<String, dynamic>> _scopedRpc(
    String name,
    String farmId,
    String cycleId,
  ) => _client.rpc<Map<String, dynamic>>(name, params: _scope(farmId, cycleId));

  static Map<String, dynamic> _scope(String farmId, String cycleId) => {
    'p_granja_id': farmId,
    'p_cycle_id': cycleId,
  };
}
