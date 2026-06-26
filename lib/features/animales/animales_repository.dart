// lib/features/animales/animales_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/supabase/supabase_client.dart';
import '../model/tipoAnimal/tipoAnimal.dart';
import '../model/grupo/grupo.dart';
import '../model/loteEntrada/loteEntrada.dart';
import '../model/ejemplar/ejemplar.dart';
import '../model/bajaEjemplar/baja_ejemplar.dart';
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
  Future<void> deleteTipoAnimal({required String farmId,required String tipoId}) async {
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) throw Exception('Usuario no autenticado');

    try {
      await supabase.from('tipo_animal').delete()
        .eq('granja_id',farmId)
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
  Future<void> deleteGrupo({required String farmId,required String grupoId}) async {
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) throw Exception('Usuario no autenticado');

    try {
      await supabase.from('grupos').delete()
        .eq('granja_id',farmId)
        .eq('id', grupoId);
    } catch (e) {
      print(e);
    }
  }
 
  // ── Lotes de entrada con conteos (usa vista existente + join cat) ─────────
  Future<List<LoteEntrada>> getLotesDeGrupo(String grupoId) async {
    final data = await _client
        .from('vista_altas_animales')
        .select('''
          id,
          grupo_id,
          tipo_animal_id,
          fecha_alta,
          proveedor,
          costo_total,
          total_animales,
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
  Future<void> addEjemplar({
    required String granjaId,
    required String tipoAnimalId,
    required String grupoId,
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

final animalesRepositoryProvider = Provider<AnimalesRepository>((
  ref,
) {
  return AnimalesRepository(Supabase.instance.client);
});