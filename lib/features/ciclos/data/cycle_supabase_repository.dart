import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/cycle_models.dart';
import '../domain/cycle_repository.dart';

class CycleSupabaseRepository implements CycleRepository {
  CycleSupabaseRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<CycleCatalogs> getCatalogs() async {
    final results = await Future.wait([
      _client
          .from('cat_productos')
          .select('id,codigo,nombre,cat_unidades(codigo,nombre)')
          .eq('activo', true)
          .order('nombre'),
      _client
          .from('cat_metricas_producto')
          .select('id,producto_id,codigo,nombre,rol,cat_unidades(nombre)')
          .eq('activo', true)
          .order('nombre'),
    ]);
    return CycleCatalogs(
      products: _rows(results[0]).map(CycleProduct.fromJson).toList(),
      metrics: _rows(results[1]).map(CycleMetric.fromJson).toList(),
    );
  }

  @override
  Future<List<Cycle>> getCycles(String farmId) async {
    final data = await _client
        .from('ciclos_productivos')
        .select(_cycleSelect)
        .eq('granja_id', farmId)
        .order('fecha_inicio', ascending: false);
    return _rows(data).map(Cycle.fromJson).toList();
  }

  @override
  Future<CycleDetail> getCycleDetail(String cycleId) async {
    final results = await Future.wait([
      _client
          .from('ciclos_productivos')
          .select(_cycleSelect)
          .eq('id', cycleId)
          .maybeSingle(),
      _client
          .from('ciclo_miembros')
          .select(
            'id,animal_id,joined_at,left_at,animales(brazalete,grupos(nombre))',
          )
          .eq('ciclo_id', cycleId)
          .order('joined_at'),
    ]);
    final cycleData = results[0] as Map<String, dynamic>?;
    if (cycleData == null) {
      throw StateError('Cycle not found or unavailable.');
    }
    return CycleDetail(
      cycle: Cycle.fromJson(cycleData),
      members: _rows(results[1]).map(CycleMember.fromJson).toList(),
    );
  }

  @override
  Future<CycleEconomics?> getEconomics(String cycleId) async {
    final data = await _client
        .from('v_ciclo_economia')
        .select()
        .eq('ciclo_id', cycleId)
        .maybeSingle();
    return data == null ? null : CycleEconomics.fromJson(data);
  }

  @override
  Future<List<CycleTimelineItem>> getTimeline(String cycleId) async {
    final cycle = await _client
        .from('ciclos_productivos')
        .select('id,fecha_inicio')
        .eq('id', cycleId)
        .maybeSingle();
    final members = await _client
        .from('ciclo_miembros')
        .select('id,animal_id,joined_at,left_at,animales(brazalete)')
        .eq('ciclo_id', cycleId);
    final events = await _client
        .from('eventos_produccion')
        .select(
          'id,fecha,notas,created_at,evento_mediciones(valor,cat_metricas_producto(nombre,rol))',
        )
        .eq('ciclo_id', cycleId)
        .order('fecha');
    final items = <CycleTimelineItem>[];
    if (cycle != null) {
      items.add(
        CycleTimelineItem(
          id: 'start-${cycle['id']}',
          kind: CycleTimelineKind.started,
          occurredAt: DateTime.parse(cycle['fecha_inicio'] as String),
          title: 'Cycle started',
        ),
      );
    }
    for (final row in _rows(members)) {
      final animal = row['animales'] as Map?;
      final label = animal?['brazalete'] == null
          ? 'Animal ${row['animal_id']}'
          : 'Bracelet ${animal!['brazalete']}';
      items.add(
        CycleTimelineItem(
          id: 'joined-${row['id']}',
          kind: CycleTimelineKind.memberJoined,
          occurredAt: DateTime.parse(row['joined_at'] as String),
          title: '$label joined',
        ),
      );
      final leftAt = row['left_at'];
      if (leftAt != null) {
        items.add(
          CycleTimelineItem(
            id: 'left-${row['id']}',
            kind: CycleTimelineKind.memberLeft,
            occurredAt: DateTime.parse(leftAt as String),
            title: '$label left',
          ),
        );
      }
    }
    for (final row in _rows(events)) {
      final measurements = _rows(row['evento_mediciones']);
      final detail = measurements
          .map((measurement) {
            final metric = measurement['cat_metricas_producto'] as Map?;
            return '${metric?['nombre'] ?? 'Metric'}: ${measurement['valor']}';
          })
          .join(' · ');
      items.add(
        CycleTimelineItem(
          id: 'event-${row['id']}',
          kind: CycleTimelineKind.production,
          occurredAt: DateTime.parse(row['fecha'] as String),
          title: 'Production event',
          detail: detail.isEmpty ? row['notas'] as String? : detail,
        ),
      );
    }
    items.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return items;
  }

  @override
  Future<List<CycleGroup>> getGroups(String farmId) async {
    final data = await _client
        .from('grupos')
        .select('id,tipo_animal_id,nombre')
        .eq('granja_id', farmId)
        .order('nombre');
    return _rows(data).map(CycleGroup.fromJson).toList();
  }

  @override
  Future<List<CycleMemberCandidate>> getMemberCandidates(String farmId) async {
    final candidatesRequest = _client
        .from('animales')
        .select(
          'id,tipo_animal_id,grupo_id,brazalete,tipo_animal(nombre),grupos(nombre)',
        )
        .eq('granja_id', farmId)
        .eq('activo', true)
        .order('brazalete');
    final cyclesRequest = getCycles(farmId);
    final data = await candidatesRequest;
    final activeCycleIds = (await cyclesRequest)
        .where((cycle) => cycle.isActive)
        .map((cycle) => cycle.id)
        .toList(growable: false);
    if (activeCycleIds.isEmpty) {
      return _rows(data).map(CycleMemberCandidate.fromJson).toList();
    }

    final memberships = await _client
        .from('ciclo_miembros')
        .select('animal_id')
        .isFilter('left_at', null)
        .inFilter('ciclo_id', activeCycleIds);
    final assignedAnimalIds = _rows(
      memberships,
    ).map((row) => row['animal_id'] as String).toSet();
    return [
      for (final candidate in _rows(data).map(CycleMemberCandidate.fromJson))
        if (!assignedAnimalIds.contains(candidate.id)) candidate,
    ];
  }

  @override
  Future<CycleAccess> getAccess(String farmId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return const CycleAccess(CycleRole.viewer);
    }
    final farm = await _client
        .from('granjas')
        .select('owner_id')
        .eq('id', farmId)
        .maybeSingle();
    if (farm?['owner_id'] == userId) {
      return const CycleAccess(CycleRole.owner);
    }
    final member = await _client
        .from('miembros_granja')
        .select('rol')
        .eq('granja_id', farmId)
        .eq('user_id', userId)
        .maybeSingle();
    return CycleAccess(CycleRole.fromDatabase(member?['rol'] as String?));
  }

  @override
  Future<Cycle> createCycle(CycleCreationInput input) async {
    final data = await _client.rpc<Map<String, dynamic>>(
      'crear_ciclo_productivo',
      params: {
        'p_granja_id': input.farmId,
        'p_producto_codigo': input.productCode,
        'p_tipo_animal_id': input.animalTypeId,
        'p_animal_ids': input.animalIds,
        'p_fecha_inicio': _date(input.startedAt),
        'p_nombre': _nullableText(input.name),
        'p_notas': _nullableText(input.notes),
      },
    );
    return Cycle.fromJson(data);
  }

  @override
  Future<Cycle> editMembers(CycleMembershipEditInput input) async {
    final removals = _normalizedMemberIds(input.removals);
    final removalIds = removals.toSet();
    final additions = [
      for (final animalId in _normalizedMemberIds(input.additions))
        if (!removalIds.contains(animalId)) animalId,
    ];
    if (additions.isEmpty && removals.isEmpty) {
      throw ArgumentError('Select at least one membership change.');
    }

    final data = await _client.rpc<Map<String, dynamic>>(
      'editar_miembros_ciclo',
      params: {
        'p_ciclo_id': input.cycleId,
        'p_version': input.version,
        'p_agregar': additions,
        'p_retirar': removals,
      },
    );
    return Cycle.fromJson(data);
  }

  static List<Map<String, dynamic>> _rows(Object? value) => [
    for (final row in value as List? ?? const [])
      Map<String, dynamic>.from(row as Map),
  ];

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  static String? _nullableText(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  static List<String> _normalizedMemberIds(Iterable<String> values) => [
    for (final value in values.map((value) => value.trim()).toSet())
      if (value.isNotEmpty) value,
  ];
}

const _cycleSelect = '''
id,granja_id,tipo_animal_id,producto_id,tipo_produccion,unidad_produccion,
nombre,fecha_inicio,fecha_fin,activo,version,notas,
tipo_animal(nombre),cat_productos(codigo,nombre)
''';
