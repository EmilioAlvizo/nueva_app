import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/break_even_point.dart';
import '../../domain/repositories/finances_repository.dart';
import '../models/break_even_point_model.dart';

final class SupabaseFinancesRepository implements FinancesRepository {
  const SupabaseFinancesRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<BreakEvenPoint>> getBreakEvenPoints(String farmId) async {
    final viewData = await _client
        .from('puntos_equilibrio_huevos')
        .select(_breakEvenSelect)
        .eq('granja_id', farmId)
        .order('fecha_inicio', ascending: false);

    return List<BreakEvenPoint>.unmodifiable(
      _rows(
        viewData,
      ).map((row) => BreakEvenPointModel.fromJson(row).toEntity()),
    );
  }

  static List<Map<String, dynamic>> _rows(Object? value) {
    if (value is! List) {
      throw const FormatException('Expected a list response from Supabase.');
    }
    return [
      for (final row in value)
        if (row is Map)
          Map<String, dynamic>.from(row)
        else
          throw const FormatException('Expected a row object from Supabase.'),
    ];
  }
}

const _breakEvenSelect =
    'fecha_inicio,fecha_termino,mezcla_id,grupo_nombre,buenos,rotos,'
    'total_costo_comidas,punto_de_equilibrio,granja_id,grupo_id,'
    'fecha_fin_calculada,dias_mezcla,consumo_total,'
    'aves_promedio_ponderado,huevos_por_dia,huevos_por_dia_ave,'
    'consumo_por_dia,consumo_por_dia_ave,precio_venta_promedio,'
    'margen_porcentaje';
