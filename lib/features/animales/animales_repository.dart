// lib/features/animales/animales_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/supabase/supabase_client.dart';
import '../model/tipoAnimal/tipoAnimal.dart';
import '../model/grupo/grupo.dart';
import '../model/loteEntrada/loteEntrada.dart';

 
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