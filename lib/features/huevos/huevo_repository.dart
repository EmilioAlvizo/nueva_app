// lib/features/huevos/data/huevo_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'huevo_models.dart';

class HuevoRepository {
  final SupabaseClient _client;
  HuevoRepository(this._client);

  static String _soloFecha(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  // ── Catálogos ─────────────────────────────────────────────────────────────

  Future<List<CatItemHuevo>> getRazonesReduccion() async {
    final data = await _client
        .from('cat_razon_reduccion')
        .select('id, nombre')
        .order('nombre');
    return (data as List).map((e) => CatItemHuevo(e['id'], e['nombre'])).toList();
  }

  /// Obtiene el periodo de alimento activo para la granja.
  /// Las recolecciones y reducciones requieren un periodo_alimento_id.
  /// Si no existe uno activo, lanza excepción con mensaje claro.
  Future<String> getPeriodoActivoId(String granjaId) async {
    final data = await _client
        .from('periodos_alimento')
        .select('id')
        .eq('activo', true)
        .limit(1)
        .maybeSingle();

    if (data == null) {
      throw Exception(
        'No hay un período de alimento activo. '
        'Crea uno en la sección de Alimentos antes de registrar huevos.',
      );
    }
    return data['id'] as String;
  }

  // ── Recolecciones ──────────────────────────────────────────────────────────

  Future<List<RecoleccionHuevo>> getRecolecciones(String granjaId) async {
    final data = await _client
        .from('recolecciones_huevo')
        .select('''
          *,
          tipo_animal ( nombre ),
          grupos ( nombre )
        ''')
        .eq('granja_id', granjaId)
        .order('fecha', ascending: false);

    return (data as List).map((e) {
      final raw = Map<String, dynamic>.from(e);
      raw['tipo_nombre'] = (raw['tipo_animal'] as Map?)?['nombre'] ?? '';
      raw['grupo_nombre'] = (raw['grupos'] as Map?)?['nombre'];
      return RecoleccionHuevo.fromJson(raw);
    }).toList();
  }

  Future<void> addRecoleccion({
    required String granjaId,
    required String tipoAnimalId,
    required String periodoAlimentoId,
    String? grupoId,
    required DateTime fecha,
    required int huevosBuenos,
    required int huevosRotos,
    String? notas,
  }) async {
    final userId = _client.auth.currentUser?.id;
    await _client.from('recolecciones_huevo').insert({
      'granja_id': granjaId,
      'tipo_animal_id': tipoAnimalId,
      'periodo_alimento_id': periodoAlimentoId,
      'grupo_id': grupoId,
      'fecha': _soloFecha(fecha),
      'huevos_buenos': huevosBuenos,
      'huevos_rotos': huevosRotos,
      'notas': notas,
      'created_by': userId,
    });
  }

  Future<void> updateRecoleccion({
    required String id,
    required String tipoAnimalId,
    String? grupoId,
    required DateTime fecha,
    required int huevosBuenos,
    required int huevosRotos,
    String? notas,
  }) async {
    await _client.from('recolecciones_huevo').update({
      'tipo_animal_id': tipoAnimalId,
      'grupo_id': grupoId,
      'fecha': _soloFecha(fecha),
      'huevos_buenos': huevosBuenos,
      'huevos_rotos': huevosRotos,
      'notas': notas,
    }).eq('id', id);
  }

  Future<void> deleteRecoleccion(String id) async {
    await _client.from('recolecciones_huevo').delete().eq('id', id);
  }

  // ── Reducciones ────────────────────────────────────────────────────────────

  Future<List<ReduccionHuevo>> getReducciones(String granjaId) async {
    final data = await _client
        .from('reducciones_huevo')
        .select('''
          *,
          tipo_animal ( nombre ),
          cat_razon_reduccion!razon_reduccion_id ( nombre )
        ''')
        .eq('granja_id', granjaId)
        .order('fecha', ascending: false);

    return (data as List).map((e) {
      final raw = Map<String, dynamic>.from(e);
      raw['tipo_nombre'] = (raw['tipo_animal'] as Map?)?['nombre'] ?? '';
      raw['razon_nombre'] =
          (raw['cat_razon_reduccion'] as Map?)?['nombre'] ?? '';
      return ReduccionHuevo.fromJson(raw);
    }).toList();
  }

  Future<void> addReduccion({
    required String granjaId,
    required String tipoAnimalId,
    required String periodoAlimentoId,
    required String razonReduccionId,
    required int cantidad,
    double? importe,
    required DateTime fecha,
    String? notas,
  }) async {
    final userId = _client.auth.currentUser?.id;
    await _client.from('reducciones_huevo').insert({
      'granja_id': granjaId,
      'tipo_animal_id': tipoAnimalId,
      'periodo_alimento_id': periodoAlimentoId,
      'razon_reduccion_id': razonReduccionId,
      'cantidad': cantidad,
      'importe': importe,
      'fecha': _soloFecha(fecha),
      'notas': notas,
      'created_by': userId,
    });
  }

  Future<void> updateReduccion({
    required String id,
    required String tipoAnimalId,
    required String razonReduccionId,
    required int cantidad,
    double? importe,
    required DateTime fecha,
    String? notas,
  }) async {
    await _client.from('reducciones_huevo').update({
      'tipo_animal_id': tipoAnimalId,
      'razon_reduccion_id': razonReduccionId,
      'cantidad': cantidad,
      'importe': importe,
      'fecha': _soloFecha(fecha),
      'notas': notas,
    }).eq('id', id);
  }

  Future<void> deleteReduccion(String id) async {
    await _client.from('reducciones_huevo').delete().eq('id', id);
  }
}

final huevoRepositoryProvider = Provider<HuevoRepository>(
  (ref) => HuevoRepository(Supabase.instance.client),
);