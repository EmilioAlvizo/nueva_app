// lib/features/comida/data/comida_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'comida_models.dart';

class ComidaRepository {
  final SupabaseClient _client;
  ComidaRepository(this._client);

  static String _fecha(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  // ── LOTES DE ALIMENTO ──────────────────────────────────────────────────────

  Future<List<LoteAlimento>> getLotes(String granjaId) async {
    final data = await _client
        .from('lotes_alimento')
        .select('''
          *,
          tipo_animal ( nombre )
        ''')
        .eq('granja_id', granjaId)
        .order('fecha_compra', ascending: false);

    // Para cada lote calculamos kg_consumidos_total y num_periodos
    final ids = (data as List).map((e) => e['id'] as String).toList();

    // Traer periodos de todos los lotes de una sola vez
    Map<String, double> kgPorLote = {};
    Map<String, int> numPorLote = {};

    if (ids.isNotEmpty) {
      final periodos = await _client
          .from('periodos_alimento')
          .select('lote_alimento_id, kg_consumidos')
          .inFilter('lote_alimento_id', ids);

      for (final p in periodos as List) {
        final lid = p['lote_alimento_id'] as String;
        kgPorLote[lid] = (kgPorLote[lid] ?? 0) +
            (p['kg_consumidos'] as num).toDouble();
        numPorLote[lid] = (numPorLote[lid] ?? 0) + 1;
      }
    }

    return data.map((e) {
      final raw = Map<String, dynamic>.from(e);
      raw['tipo_nombre'] = (raw['tipo_animal'] as Map?)?['nombre'] ?? '';
      raw['kg_consumidos_total'] = kgPorLote[raw['id']] ?? 0.0;
      raw['num_periodos'] = numPorLote[raw['id']] ?? 0;
      return LoteAlimento.fromJson(raw);
    }).toList();
  }

  Future<void> addLote({
    required String granjaId,
    required String tipoAnimalId,
    required DateTime fechaCompra,
    required double cantidadKg,
    required double precioTotal,
    String? proveedor,
    String? notas,
  }) async {
    final userId = _client.auth.currentUser?.id;
    final precioPorKg = cantidadKg > 0 ? precioTotal / cantidadKg : null;

    final loteData = await _client
        .from('lotes_alimento')
        .insert({
          'granja_id': granjaId,
          'tipo_animal_id': tipoAnimalId,
          'fecha_compra': _fecha(fechaCompra),
          'cantidad_kg': cantidadKg,
          'precio_total': precioTotal,
          'precio_por_kg': precioPorKg,
          'proveedor': proveedor,
          'notas': notas,
          'created_by': userId,
        })
        .select('id')
        .single();

    // Al crear un lote, automáticamente creamos un período activo desde hoy
    final loteId = loteData['id'] as String;
    await _client.from('periodos_alimento').insert({
      'lote_alimento_id': loteId,
      'fecha_inicio': _fecha(DateTime.now()),
      'activo': true,
      'kg_consumidos': 0,
      'created_by': userId,
    });
  }

  Future<void> updateLote({
    required String id,
    required String tipoAnimalId,
    required DateTime fechaCompra,
    required double cantidadKg,
    required double precioTotal,
    String? proveedor,
    String? notas,
  }) async {
    final precioPorKg = cantidadKg > 0 ? precioTotal / cantidadKg : null;
    await _client.from('lotes_alimento').update({
      'tipo_animal_id': tipoAnimalId,
      'fecha_compra': _fecha(fechaCompra),
      'cantidad_kg': cantidadKg,
      'precio_total': precioTotal,
      'precio_por_kg': precioPorKg,
      'proveedor': proveedor,
      'notas': notas,
    }).eq('id', id);
  }

  Future<void> deleteLote(String id) async {
    // Los periodos se eliminan en cascada (FK con ON DELETE CASCADE)
    await _client.from('lotes_alimento').delete().eq('id', id);
  }

  // ── PERIODOS DE ALIMENTO ───────────────────────────────────────────────────

  Future<List<PeriodoAlimento>> getPeriodos(String granjaId) async {
    // Join: periodos → lotes → tipo_animal
    final data = await _client
        .from('periodos_alimento')
        .select('''
          *,
          lotes_alimento!lote_alimento_id (
            granja_id,
            tipo_animal_id,
            precio_total,
            cantidad_kg,
            proveedor,
            tipo_animal ( nombre )
          )
        ''')
        .order('fecha_inicio', ascending: false);

    // Filtrar por granja_id del lote
    final filtrados = (data as List).where((e) {
      final lote = e['lotes_alimento'] as Map?;
      return lote?['granja_id'] == granjaId;
    }).toList();

    return filtrados.map((e) {
      final raw = Map<String, dynamic>.from(e);
      final lote = raw['lotes_alimento'] as Map? ?? {};
      raw['tipo_animal_id'] = lote['tipo_animal_id'] ?? '';
      raw['tipo_nombre'] =
          (lote['tipo_animal'] as Map?)?['nombre'] ?? '';
      raw['precio_total'] = lote['precio_total'] ?? 0;
      raw['cantidad_kg'] = lote['cantidad_kg'] ?? 0;
      raw['proveedor'] = lote['proveedor'];
      // En las imágenes el "nombre" de la card es el proveedor del lote
      raw['nombre_alimento'] = lote['proveedor'];
      return PeriodoAlimento.fromJson(raw);
    }).toList();
  }

  Future<void> updatePeriodo({
    required String id,
    required DateTime fechaInicio,
    DateTime? fechaFin,
    required bool activo,
    required double kgConsumidos,
    String? notas,
  }) async {
    await _client.from('periodos_alimento').update({
      'fecha_inicio': _fecha(fechaInicio),
      'fecha_fin': fechaFin != null ? _fecha(fechaFin) : null,
      'activo': activo,
      'kg_consumidos': kgConsumidos,
      'notas': notas,
    }).eq('id', id);
  }

  Future<void> deletePeriodo(String id) async {
    await _client.from('periodos_alimento').delete().eq('id', id);
  }
}

final comidaRepositoryProvider = Provider<ComidaRepository>(
  (ref) => ComidaRepository(Supabase.instance.client),
);