import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/break_even_point.dart';
import '../../domain/entities/finance_expense.dart';
import '../../domain/repositories/finances_repository.dart';
import '../models/break_even_point_model.dart';
import '../models/finance_expenses_snapshot_model.dart';

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

  @override
  Future<FinanceExpensesSnapshot> getExpenses(String farmId) async {
    final response = await _client.rpc(
      'list_finance_expenses',
      params: {'p_granja_id': farmId},
    );
    if (response is! Map) {
      throw const FormatException(
        'Expected an object response from list_finance_expenses.',
      );
    }
    return FinanceExpensesSnapshotModel.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  @override
  Future<void> createExpense(String farmId, FinanceExpenseDraft draft) async {
    await _client.rpc(
      'create_finance_expense',
      params: _draftParams(farmId: farmId, draft: draft),
    );
  }

  @override
  Future<void> updateExpense(
    String farmId,
    FinanceExpense expense,
    FinanceExpenseDraft draft,
  ) async {
    await _client.rpc(
      'update_finance_expense',
      params: {
        ..._draftParams(farmId: farmId, draft: draft),
        'p_expense_id': expense.id,
        'p_expected_updated_at': expense.updatedAt.toUtc().toIso8601String(),
      },
    );
  }

  @override
  Future<void> deleteExpense(String farmId, FinanceExpense expense) async {
    await _client.rpc(
      'delete_finance_expense',
      params: {
        'p_granja_id': farmId,
        'p_expense_id': expense.id,
        'p_target_kind': expense.targetKind.wireValue,
        'p_target_id': expense.targetId,
        'p_expected_updated_at': expense.updatedAt.toUtc().toIso8601String(),
      },
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

Map<String, Object?> _draftParams({
  required String farmId,
  required FinanceExpenseDraft draft,
}) => {
  'p_granja_id': farmId,
  'p_target_kind': draft.targetKind.wireValue,
  'p_target_id': draft.targetId,
  'p_occurred_on': _date(draft.occurredOn),
  'p_amount': draft.amount,
  'p_category': draft.category,
  'p_note': draft.note,
};

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

const _breakEvenSelect =
    'fecha_inicio,fecha_termino,mezcla_id,grupo_nombre,buenos,rotos,'
    'total_costo_comidas,punto_de_equilibrio,granja_id,grupo_id,'
    'fecha_fin_calculada,dias_mezcla,consumo_total,'
    'aves_promedio_ponderado,huevos_por_dia,huevos_por_dia_ave,'
    'consumo_por_dia,consumo_por_dia_ave,precio_venta_promedio,'
    'margen_porcentaje,total_gastos_directos,costo_total';
