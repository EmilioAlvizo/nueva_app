import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/break_even_point.dart';
import '../../domain/repositories/finances_repository.dart';
import '../models/break_even_point_model.dart';

final class SupabaseFinancesRepository implements FinancesRepository {
  const SupabaseFinancesRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<BreakEvenPoint>> getBreakEvenPoints(String farmId) async {
    final mixtureData = await _client
        .from('mezcla')
        .select('id,grupos!inner(granja_id)')
        .eq('grupos.granja_id', farmId);
    final mixtureIds = <String>{
      for (final row in _rows(mixtureData)) _requiredMixtureId(row),
    }.toList(growable: false);

    if (mixtureIds.isEmpty) return const [];

    final viewData = await _client
        .from('puntos_equilibrio_huevos')
        .select(_breakEvenSelect)
        .inFilter('mezcla_id', mixtureIds)
        .order('fecha_inicio', ascending: false);

    return List<BreakEvenPoint>.unmodifiable(
      _rows(
        viewData,
      ).map((row) => BreakEvenPointModel.fromJson(row).toEntity()),
    );
  }

  static String _requiredMixtureId(Map<String, dynamic> row) {
    final value = row['id'];
    if (value is! String || value.trim().isEmpty) {
      throw const FormatException('Expected mixture id in farm scope query.');
    }
    return value.trim();
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
    'total_costo_comidas,punto_de_equilibrio';
