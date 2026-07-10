// lib/features/animales/animales_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/supabase/supabase_client.dart';
import '../model/tipoAnimal/tipoAnimal.dart';
import '../model/grupo/grupo.dart';
import '../model/altaAnimales/altaAnimales.dart';
import '../model/altaAnimales/registrar_alta_animales_input.dart';
import '../model/animal/animal.dart';
import '../model/bajaAnimal/baja_animal.dart';
import '../model/bajaAnimal/registrar_baja_animales_input.dart';
import '../model/catalogoItem/catalogo_item.dart';

class AnimalesRepository {
  static const int _maxBraceletValue = 32767;

  final SupabaseClient _client;
  AnimalesRepository(this._client);

  // ── Tipos de animal de la granja ──────────────────────────────────────────
  Future<List<TipoAnimal>> getTipos(String granjaId) async {
    final data = await _client
        .from('tipo_animal')
        .select()
        .eq('granja_id', granjaId)
        .order('nombre');
    return (data as List).map((e) => TipoAnimal.fromJson(e)).toList();
  }

  /// agregar nuevo tipo de animal a la granja se requiere el Id de la granja [granjaId]
  /// el nombre del nuevo tipo de animal [nombre]
  Future<void> addTipoAnimal({
    required String granjaId,
    required String nombre,
    String? descripcion,
  }) async {
    final userId = supabase.auth.currentUser?.id;

    await _client.from('tipo_animal').insert({
      'granja_id': granjaId,
      'nombre': nombre,
      'created_by': userId,
      'descripcion': descripcion,
    });
  }

  Future<void> updateTipoAnimal({
    required String tipoId,
    required String granjaId,
    required String nombre,
    String? descripcion,
  }) async {
    await _client
        .from('tipo_animal')
        .update({'nombre': nombre, 'descripcion': descripcion})
        .eq('id', tipoId)
        .eq('granja_id', granjaId);
  }

  /// eliminar tipo de animal
  Future<void> deleteTipoAnimal({
    required String farmId,
    required String tipoId,
  }) async {
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) throw Exception('Usuario no autenticado');

    try {
      await supabase
          .from('tipo_animal')
          .delete()
          .eq('granja_id', farmId)
          .eq('id', tipoId);
    } catch (_) {}
  }

  // ── Grupos de la granja ───────────────────────────────────────────────────
  Future<List<Grupo>> getGrupos(String granjaId) async {
    final data = await _client
        .from('grupos')
        .select()
        .eq('granja_id', granjaId)
        .order('nombre');
    return (data as List).map((e) => Grupo.fromJson(e)).toList();
  }

  /// eliminar grupos
  Future<void> deleteGrupo({
    required String farmId,
    required String grupoId,
  }) async {
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) throw Exception('Usuario no autenticado');

    try {
      await supabase
          .from('grupos')
          .delete()
          .eq('granja_id', farmId)
          .eq('id', grupoId);
    } catch (_) {}
  }

  Future<void> updateGrupo({
    required String grupoId,
    required String granjaId,
    required String tipoAnimalId,
    required String nombre,
    String? descripcion,
  }) async {
    await _client
        .from('grupos')
        .update({
          'tipo_animal_id': tipoAnimalId,
          'nombre': nombre,
          'descripcion': descripcion,
        })
        .eq('id', grupoId)
        .eq('granja_id', granjaId);
  }

  // ── Lotes de entrada con conteos (usa vista existente + join cat) ─────────
  Future<List<AltaAnimales>> vistaAltasAnimales(String grupoId) async {
    final data = await _client
        .from('vista_altas_animales')
        .select(_altasSelect)
        .eq('grupo_id', grupoId)
        .order('fecha_alta', ascending: false);
    return _enrichAltas(_mapAltas(data));
  }

  Future<AltaAnimales> registrarAltaAnimales(
    RegistrarAltaAnimalesInput input,
  ) async {
    _validateRegistrarAltaInput(input);

    final data = await _client
        .rpc('registrar_alta_animales', params: input.toRpcParams())
        .single();

    return AltaAnimales.fromJson(Map<String, dynamic>.from(data));
  }

  Future<List<AltaAnimales>> getAltas(
    String granjaId, {
    String? grupoId,
  }) async {
    var query = _client
        .from('vista_altas_animales')
        .select(_altasSelect)
        .eq('granja_id', granjaId);

    if (grupoId != null) {
      query = query.eq('grupo_id', grupoId);
    }

    final data = await query.order('fecha_alta', ascending: false);
    return _enrichAltas(_mapAltas(data));
  }

  Future<NoGroupOverview> getNoGroupOverview(String granjaId) async {
    final noGroupAnimals = await _client
        .from('animales')
        .select('tipo_animal_id, activo')
        .eq('granja_id', granjaId)
        .isFilter('grupo_id', null);

    final altas = await _client
        .from('vista_altas_animales')
        .select(_altasSelect)
        .eq('granja_id', granjaId)
        .isFilter('grupo_id', null)
        .order('fecha_alta', ascending: false);

    final latestAltas = await _enrichAltas(_mapAltas(altas));
    final countsByType = <String, ({int active, int dead})>{};

    for (final row in noGroupAnimals as List) {
      final json = Map<String, dynamic>.from(row as Map);
      final tipoAnimalId = json['tipo_animal_id'] as String?;
      if (tipoAnimalId == null) {
        continue;
      }

      final current = countsByType[tipoAnimalId] ?? (active: 0, dead: 0);
      final activo = json['activo'] as bool? ?? true;
      countsByType[tipoAnimalId] = activo
          ? (active: current.active + 1, dead: current.dead)
          : (active: current.active, dead: current.dead + 1);
    }

    final altasByType = <String, List<AltaAnimales>>{};
    for (final alta in latestAltas) {
      final bucket = altasByType.putIfAbsent(alta.tipoAnimalId, () => []);
      if (bucket.length < 3) {
        bucket.add(alta);
      }
    }

    final tipoIds = {...countsByType.keys, ...altasByType.keys};
    final typeSummaries = [
      for (final tipoAnimalId in tipoIds)
        NoGroupTypeOverview(
          tipoAnimalId: tipoAnimalId,
          activeCount: countsByType[tipoAnimalId]?.active ?? 0,
          deadCount: countsByType[tipoAnimalId]?.dead ?? 0,
          latestAltas: altasByType[tipoAnimalId] ?? const [],
        ),
    ];

    return NoGroupOverview(
      activeCount: countsByType.values.fold(
        0,
        (sum, item) => sum + item.active,
      ),
      deadCount: countsByType.values.fold(0, (sum, item) => sum + item.dead),
      latestAltas: latestAltas.take(3).toList(growable: false),
      typeSummaries: typeSummaries,
    );
  }

  Future<List<int>> getAvailableBracelets(
    String granjaId,
    String tipoAnimalId,
  ) async {
    final data = await _client
        .from('animales')
        .select('brazalete')
        .eq('granja_id', granjaId)
        .eq('tipo_animal_id', tipoAnimalId)
        .order('brazalete', ascending: true);

    final usedBracelets = (data as List)
        .map((row) => row['brazalete'])
        .whereType<num>()
        .map((value) => value.toInt())
        .where((value) => value > 0 && value <= _maxBraceletValue)
        .toSet();

    final availableBracelets = <int>[];
    for (var bracelet = 1; bracelet <= _maxBraceletValue; bracelet++) {
      if (!usedBracelets.contains(bracelet)) {
        availableBracelets.add(bracelet);
      }
    }

    return availableBracelets;
  }

  // ── Animales individuales de la granja ──────────────────────────────────
  /// Lista todos los ejemplares de la granja con el nombre de su tipo y
  /// grupo ya incluidos (join). Útil para la tab "Animales".
  Future<List<Animal>> getAnimales(String granjaId) async {
    final data = await _client
        .from('animales')
        .select('''
          id,
          granja_id,
          tipo_animal_id,
          grupo_id,
          alta_id,
          baja_id,
          brazalete,
          proposito_id,
          tipo_adquisicion_id,
      fecha_adquisicion,
      costo_adquisicion,
      activo,
      notas,
      tipo_animal ( nombre ),
          grupos ( nombre )
        ''')
        .eq('granja_id', granjaId)
        .order('brazalete');

    return (data as List).map((e) {
      final raw = Map<String, dynamic>.from(e);
      raw['tipo_nombre'] = (raw['tipo_animal'] as Map?)?['nombre'] ?? '';
      raw['grupo_nombre'] = (raw['grupos'] as Map?)?['nombre'] ?? '';
      return Animal.fromJson(raw);
    }).toList();
  }

  // ── Catálogos para el formulario de ejemplar ──────────────────────────────
  /// Catálogo de propósitos (Postura, Carne, Ornamental…). Incluye los
  /// globales (granja_id null) y los propios de la granja, si los hubiera.
  Future<List<CatalogoItem>> getPropositos(String granjaId) async {
    final data = await _client
        .from('cat_proposito_animal')
        .select('id, nombre')
        .or('granja_id.is.null,granja_id.eq.$granjaId')
        .eq('activo', true)
        .order('orden');
    return (data as List).map((e) => CatalogoItem.fromJson(e)).toList();
  }

  /// Catálogo de formas de adquisición (Compra, Nacimiento, Donación…).
  Future<List<CatalogoItem>> getTiposAdquisicion(String granjaId) async {
    final data = await _client
        .from('cat_tipo_adquisicion')
        .select('id, nombre')
        .or('granja_id.is.null,granja_id.eq.$granjaId')
        .eq('activo', true)
        .order('orden');
    return (data as List).map((e) => CatalogoItem.fromJson(e)).toList();
  }

  // ── CRUD de ejemplares ─────────────────────────────────────────────────────
  Future<void> addAnimal({
    required String granjaId,
    required String tipoAnimalId,
    String? grupoId,
    required int brazalete,
    required String propositoId,
    required String tipoAdquisicionId,
    required DateTime fechaAdquisicion,
    double? costoAdquisicion,
    String? notas,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    await _client.from('animales').insert({
      'granja_id': granjaId,
      'tipo_animal_id': tipoAnimalId,
      'grupo_id': grupoId,
      'brazalete': brazalete,
      'proposito_id': propositoId,
      'tipo_adquisicion_id': tipoAdquisicionId,
      'fecha_adquisicion': _soloFecha(fechaAdquisicion),
      'costo_adquisicion': costoAdquisicion,
      'notas': notas,
      'created_by': userId,
    });
  }

  Future<void> updateEjemplar({
    required String id,
    required String tipoAnimalId,
    required String grupoId,
    required int brazalete,
    required String propositoId,
    required String tipoAdquisicionId,
    required DateTime fechaAdquisicion,
    double? costoAdquisicion,
    String? notas,
    required bool activo,
  }) async {
    await _client
        .from('animales')
        .update({
          'tipo_animal_id': tipoAnimalId,
          'grupo_id': grupoId,
          'brazalete': brazalete,
          'proposito_id': propositoId,
          'tipo_adquisicion_id': tipoAdquisicionId,
          'fecha_adquisicion': _soloFecha(fechaAdquisicion),
          'costo_adquisicion': costoAdquisicion,
          'notas': notas,
          'activo': activo,
        })
        .eq('id', id);
  }

  Future<void> deleteEjemplar(String id) async {
    await _client.from('animales').delete().eq('id', id);
  }

  static String _soloFecha(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Lista las bajas (eventos) de la granja con: tipo, grupo (si aplica),
  /// razón de baja y brazaletes de los animales afectados. Usa la vista
  /// `vista_bajas_animales`, que ya agrega los brazaletes y nombres.
  Future<List<BajaAnimal>> getBajasAnimales(String granjaId) async {
    final data = await _client
        .from('vista_bajas_animales')
        .select()
        .eq('granja_id', granjaId)
        .order('fecha_baja', ascending: false);

    return (data as List)
        .map((e) => BajaAnimal.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Catálogo de razones de baja (Muerte, Venta, Donación, Sacrificio…).
  /// Incluye los globales (granja_id null) y los propios de la granja.
  Future<List<CatalogoItem>> getRazonesBaja(String granjaId) async {
    final data = await _client
        .from('cat_razon_baja')
        .select('id, nombre')
        .or('granja_id.is.null,granja_id.eq.$granjaId')
        .eq('activo', true)
        .order('orden');
    return (data as List).map((e) => CatalogoItem.fromJson(e)).toList();
  }

  Future<void> registrarBajaAnimales(RegistrarBajaAnimalesInput input) async {
    _validateRegistrarBajaInput(input);

    await _client
        .rpc('registrar_baja_animales', params: input.toRpcParams())
        .single();
  }

  Future<void> eliminarAltaAnimales(
    String altaId, {
    required bool deleteBajas,
  }) async {
    await _client.rpc(
      'eliminar_alta_animales',
      params: {'p_alta_id': altaId, 'p_delete_bajas': deleteBajas},
    );
  }

  /// Actualiza los campos editables de un evento de baja ya existente.
  /// No toca `cantidad_animales` ni los animales enlazados: cambiar cuántos
  /// o cuáles animales pertenecen al evento equivale a crear una baja nueva.
  Future<void> actualizarBaja({
    required String id,
    required String razonBajaId,
    required DateTime fechaBaja,
    double? importeTotal,
    String? notas,
  }) async {
    await _client
        .from('bajas_animales')
        .update({
          'razon_baja_id': razonBajaId,
          'fecha_baja': _soloFecha(fechaBaja),
          'importe_total': importeTotal,
          'notas': notas,
        })
        .eq('id', id);
  }

  /// Elimina un evento de baja y revierte sus efectos: los animales que
  /// quedaron enlazados a esta baja vuelven a estar activos y sin baja_id.
  /// No usa una sola transacción atómica (Supabase client no expone RPC
  /// transaccional por defecto), así que primero se revierten los animales
  /// y luego se borra el evento; si el borrado falla, los animales ya
  /// quedaron reactivados, lo cual es el estado más seguro.
  Future<void> eliminarBaja(String bajaId) async {
    await _client
        .from('animales')
        .update({'baja_id': null, 'activo': true})
        .eq('baja_id', bajaId);

    await _client.from('bajas_animales').delete().eq('id', bajaId);
  }

  // ── Conteos de vivos/muertes por grupo ────────────────────────────────────
  Future<Map<String, ConteoGrupo>> getConteosGrupos(String granjaId) async {
    // vivos
    final vivosData = await _client
        .from('animales')
        .select('grupo_id')
        .eq('granja_id', granjaId)
        .eq('activo', true);

    // muertos (activo=false, lo manejamos contando bajas)
    final muertosData = await _client
        .from('animales')
        .select('grupo_id')
        .eq('granja_id', granjaId)
        .eq('activo', false);

    // total
    final totalData = await _client
        .from('animales')
        .select('grupo_id')
        .eq('granja_id', granjaId);

    final Map<String, ConteoGrupo> result = {};

    for (final e in vivosData as List) {
      final gId = e['grupo_id'] as String?;
      if (gId == null) continue; // animal sin grupo, skip
      result.putIfAbsent(gId, () => ConteoGrupo());
      result[gId]!.vivos++;
    }

    for (final e in muertosData as List) {
      final gId = e['grupo_id'] as String?;
      if (gId == null) continue;
      result.putIfAbsent(gId, () => ConteoGrupo());
      result[gId]!.muertes++;
    }

    for (final e in totalData as List) {
      final gId = e['grupo_id'] as String?;
      if (gId == null) continue;
      result.putIfAbsent(gId, () => ConteoGrupo());
      result[gId]!.total++;
    }

    return result;
  }

  Future<List<AltaAnimales>> _enrichAltas(List<AltaAnimales> altas) async {
    if (altas.isEmpty) {
      return altas;
    }

    final altaIds = altas.map((alta) => alta.id).toList(growable: false);
    final animalesData = await _client
        .from('animales')
        .select('alta_id, brazalete, activo')
        .inFilter('alta_id', altaIds)
        .order('alta_id')
        .order('brazalete', ascending: true);

    final statsByAlta = <String, _AltaEnrichment>{};

    for (final row in animalesData as List) {
      final json = Map<String, dynamic>.from(row as Map);
      final altaId = json['alta_id'] as String?;
      if (altaId == null) {
        continue;
      }

      final stats = statsByAlta.putIfAbsent(altaId, _AltaEnrichment.new);
      final isActive = json['activo'] as bool? ?? true;
      if (isActive) {
        stats.vivos++;
      } else {
        stats.muertos++;
      }

      final bracelet = (json['brazalete'] as num?)?.toInt();
      if (bracelet != null) {
        stats.brazaletes.add(AltaBrazalete(numero: bracelet, activo: isActive));
      }
    }

    return [
      for (final alta in altas)
        switch (statsByAlta[alta.id]) {
          final _AltaEnrichment stats => alta.copyWith(
            brazaletes: [
              for (final bracelet in stats.brazaletes) bracelet.numero,
            ],
            brazaletesDetalle: stats.brazaletes,
            cantidadVivos: stats.vivos,
            cantidadMuertos: stats.muertos,
          ),
          null => alta.copyWith(
            cantidadVivos: alta.cantidadAnimales,
            cantidadMuertos: 0,
          ),
        },
    ];
  }
}

class _AltaEnrichment {
  int vivos = 0;
  int muertos = 0;
  final List<AltaBrazalete> brazaletes = [];
}

List<AltaAnimales> _mapAltas(dynamic data) => (data as List)
    .map((row) => AltaAnimales.fromJson(Map<String, dynamic>.from(row)))
    .toList();

void _validateRegistrarAltaInput(RegistrarAltaAnimalesInput input) {
  if (input.cantidad <= 0) {
    throw ArgumentError.value(
      input.cantidad,
      'cantidad',
      'must be greater than 0',
    );
  }

  final bracelets = input.bracelets;
  if (bracelets == null) {
    return;
  }

  if (bracelets.length > input.cantidad) {
    throw ArgumentError.value(
      bracelets,
      'bracelets',
      'count must be less than or equal to cantidad',
    );
  }

  final uniqueBracelets = <int>{};
  for (final bracelet in bracelets) {
    if (bracelet <= 0 || bracelet > AnimalesRepository._maxBraceletValue) {
      throw ArgumentError.value(
        bracelet,
        'bracelets',
        'must contain only positive small integers',
      );
    }

    if (!uniqueBracelets.add(bracelet)) {
      throw ArgumentError.value(
        bracelets,
        'bracelets',
        'must not contain duplicates',
      );
    }
  }
}

void _validateRegistrarBajaInput(RegistrarBajaAnimalesInput input) {
  if (input.animalIds.isEmpty) {
    throw ArgumentError.value(
      input.animalIds,
      'animalIds',
      'must contain at least one animal',
    );
  }

  final uniqueIds = input.animalIds.toSet();
  if (uniqueIds.length != input.animalIds.length) {
    throw ArgumentError.value(
      input.animalIds,
      'animalIds',
      'must not contain duplicates',
    );
  }
}

const String _altasSelect = '''
id,
granja_id,
grupo_id,
tipo_animal_id,
proposito_id,
tipo_adquisicion_id,
fecha_alta,
proveedor,
costo_total,
cantidad_animales,
created_by,
created_at,
notas,
brazaletes
''';

class NoGroupOverview {
  const NoGroupOverview({
    required this.activeCount,
    required this.deadCount,
    required this.latestAltas,
    required this.typeSummaries,
  });

  final int activeCount;
  final int deadCount;
  final List<AltaAnimales> latestAltas;
  final List<NoGroupTypeOverview> typeSummaries;
}

class NoGroupTypeOverview {
  const NoGroupTypeOverview({
    required this.tipoAnimalId,
    required this.activeCount,
    required this.deadCount,
    required this.latestAltas,
  });

  final String tipoAnimalId;
  final int activeCount;
  final int deadCount;
  final List<AltaAnimales> latestAltas;
}

class ConteoGrupo {
  int vivos = 0;
  int muertes = 0;
  int total = 0;
}

final animalesRepositoryProvider = Provider<AnimalesRepository>((ref) {
  return AnimalesRepository(Supabase.instance.client);
});
