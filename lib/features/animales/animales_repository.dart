// lib/features/animales/animales_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/supabase/supabase_client.dart';
import '../model/tipoAnimal/tipoAnimal.dart';
import '../model/grupo/grupo.dart';
import '../model/altaAnimales/altaAnimales.dart';
import '../model/animal/animal.dart';
import '../model/bajaAnimal/baja_animal.dart';
import '../model/catalogoItem/catalogo_item.dart';

class AnimalesRepository {
  final SupabaseClient _client;
  AnimalesRepository(this._client);

  // ── Tipos de animal de la granja ──────────────────────────────────────────
  Future<List<TipoAnimal>> getTipos(String granjaId) async {
    final data = await _client
        .from('tipo_animal')
        .select()
        .eq('granja_id', granjaId)
        .order('nombre');
    print(data);
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
    } catch (e) {
      print(e);
    }
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
    } catch (e) {
      print(e);
    }
  }

  // ── Lotes de entrada con conteos (usa vista existente + join cat) ─────────
  Future<List<AltaAnimales>> vistaAltasAnimales(String grupoId) async {
    final data = await _client
        .from('vista_altas_animales')
        .select('''
          id,
          granja_id,
          grupo_id,
          tipo_animal_id,
          fecha_alta,
          proveedor,
          costo_total,
          cantidad_animales,
          created_by,    
          created_at,
          brazaletes,
          cat_tipo_adquisicion!tipo_adquisicion_id ( nombre )
        ''')
        .eq('grupo_id', grupoId)
        .order('fecha_alta', ascending: false);
    print('data');
    print(data);
    return (data as List).map((e) {
      final raw = Map<String, dynamic>.from(e);
      // Aplanar el join
      raw['tipo_adquisicion_nombre'] =
          (raw['cat_tipo_adquisicion'] as Map?)?['nombre'] ?? '';
      return AltaAnimales.fromJson(raw);
    }).toList();
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
    String? loteEntradaId,
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
      'lote_entrada_id': loteEntradaId,
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
  Future<Map<String, _ConteoGrupo>> getConteosGrupos(String granjaId) async {
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

    final Map<String, _ConteoGrupo> result = {};

    for (final e in vivosData as List) {
      final gId = e['grupo_id'] as String;
      result.putIfAbsent(gId, () => _ConteoGrupo());
      result[gId]!.vivos++;
    }
    for (final e in muertosData as List) {
      final gId = e['grupo_id'] as String;
      result.putIfAbsent(gId, () => _ConteoGrupo());
      result[gId]!.muertes++;
    }
    for (final e in totalData as List) {
      final gId = e['grupo_id'] as String;
      result.putIfAbsent(gId, () => _ConteoGrupo());
      result[gId]!.total++;
    }

    return result;
  }
}

class _ConteoGrupo {
  int vivos = 0;
  int muertes = 0;
  int total = 0;
}

final animalesRepositoryProvider = Provider<AnimalesRepository>((ref) {
  return AnimalesRepository(Supabase.instance.client);
});
