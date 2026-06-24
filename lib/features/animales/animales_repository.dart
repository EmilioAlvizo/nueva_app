// lib/features/animales/animales_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/supabase/supabase_client.dart';
import '../model/tipoAnimal/tipoAnimal.dart';
import '../model/grupo/grupo.dart';
import '../model/loteEntrada/loteEntrada.dart';
import '../model/ejemplar/ejemplar.dart';
import '../model/bajaEjemplar/baja_ejemplar.dart';

 
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
  

  // ── Grupos de la granja ───────────────────────────────────────────────────
  Future<List<Grupo>> getGrupos(String granjaId) async {
    final data = await _client
        .from('grupos')
        .select()
        .eq('granja_id', granjaId)
        .order('nombre');
    return (data as List).map((e) => Grupo.fromJson(e)).toList();
  }
 
  // ── Lotes de entrada con conteos (usa vista existente + join cat) ─────────
  Future<List<LoteEntrada>> getLotesDeGrupo(String grupoId) async {
    final data = await _client
        .from('vista_lotes_entrada')
        .select('''
          id,
          grupo_id,
          tipo_animal_id,
          fecha_adquisicion,
          proveedor,
          costo_total,
          total_ejemplares,
          brazaletes,
          cat_tipo_adquisicion!tipo_adquisicion_id ( nombre )
        ''')
        .eq('grupo_id', grupoId)
        .order('fecha_adquisicion', ascending: false);
 
    return (data as List).map((e) {
      final raw = Map<String, dynamic>.from(e);
      // Aplanar el join
      raw['tipo_adquisicion_nombre'] =
          (raw['cat_tipo_adquisicion'] as Map?)?['nombre'] ?? '';
      return LoteEntrada.fromJson(raw);
    }).toList();
  }
 
  // ── Ejemplares individuales de la granja ──────────────────────────────────
  /// Lista todos los ejemplares de la granja con el nombre de su tipo y
  /// grupo ya incluidos (join). Útil para la tab "Ejemplares".
  Future<List<Ejemplar>> getEjemplares(String granjaId) async {
    final data = await _client
        .from('ejemplares')
        .select('''
          id,
          granja_id,
          tipo_animal_id,
          grupo_id,
          brazalete,
          fecha_adquisicion,
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
      return Ejemplar.fromJson(raw);
    }).toList();
  }

  // ── Bajas de ejemplares (individuales, con info de lote de baja) ──────────
  /// Lista las bajas de ejemplares de la granja con: brazalete, tipo, grupo,
  /// razón de baja y, si aplica, el id del lote de baja al que pertenecen
  /// (para poder agruparlas en la tab "Bajas → Por lote").
  Future<List<BajaEjemplar>> getBajasEjemplares(String granjaId) async {
    final data = await _client
        .from('bajas_ejemplares')
        .select('''
          id,
          ejemplar_id,
          razon_baja_id,
          fecha_baja,
          importe_venta,
          notas,
          lotes_baja_id,
          cat_razon_baja ( nombre ),
          ejemplares!inner (
            brazalete,
            granja_id,
            tipo_animal_id,
            tipo_animal ( nombre ),
            grupos ( nombre )
          )
        ''')
        .eq('ejemplares.granja_id', granjaId)
        .order('fecha_baja', ascending: false);

    return (data as List).map((e) {
      final raw = Map<String, dynamic>.from(e);
      final ejemplar = (raw['ejemplares'] as Map?) ?? {};
      raw['brazalete'] = ejemplar['brazalete'];
      raw['tipo_animal_id'] = ejemplar['tipo_animal_id'];
      raw['tipo_nombre'] = (ejemplar['tipo_animal'] as Map?)?['nombre'] ?? '';
      raw['grupo_nombre'] = (ejemplar['grupos'] as Map?)?['nombre'] ?? '';
      raw['razon_nombre'] = (raw['cat_razon_baja'] as Map?)?['nombre'] ?? '';
      return BajaEjemplar.fromJson(raw);
    }).toList();
  }

  // ── Conteos de vivos/muertes por grupo ────────────────────────────────────
  Future<Map<String, _ConteoGrupo>> getConteosGrupos(String granjaId) async {
    // vivos
    final vivosData = await _client
        .from('ejemplares')
        .select('grupo_id')
        .eq('granja_id', granjaId)
        .eq('activo', true);
 
    // muertos (activo=false, lo manejamos contando bajas)
    final muertosData = await _client
        .from('ejemplares')
        .select('grupo_id')
        .eq('granja_id', granjaId)
        .eq('activo', false);
 
    // total
    final totalData = await _client
        .from('ejemplares')
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

final animalesRepositoryProvider = Provider<AnimalesRepository>((
  ref,
) {
  return AnimalesRepository(Supabase.instance.client);
});