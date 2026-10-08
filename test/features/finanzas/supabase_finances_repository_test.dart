// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:rancho/features/finanzas/data/repositories/supabase_finances_repository.dart';
import 'package:rancho/features/finanzas/domain/entities/finance_expense.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'queries the view once with its explicit farm-scoped contract',
    () async {
      final requests = <http.BaseRequest>[];
      final repository = _repository((request) async {
        requests.add(request);
        return _jsonResponse([_viewRow]);
      });

      final result = await repository.getBreakEvenPoints('farm-1');

      expect(result.single.groupName, 'Gallinero');
      expect(result.single.mixtureDays, 26);
      expect(result.single.directExpenses, 25);
      expect(result.single.totalCost, 825);
      expect(requests, hasLength(1));

      final request = requests.single;
      expect(request.method, 'GET');
      expect(request.url.path, '/rest/v1/puntos_equilibrio_huevos');
      expect(
        request.url.queryParameters['select'],
        'fecha_inicio,fecha_termino,mezcla_id,grupo_nombre,buenos,rotos,'
        'total_costo_comidas,punto_de_equilibrio,granja_id,grupo_id,'
        'fecha_fin_calculada,dias_mezcla,consumo_total,'
        'aves_promedio_ponderado,huevos_por_dia,huevos_por_dia_ave,'
        'consumo_por_dia,consumo_por_dia_ave,precio_venta_promedio,'
        'margen_porcentaje,total_gastos_directos,costo_total',
      );
      expect(request.url.queryParameters['granja_id'], 'eq.farm-1');
      expect(
        request.url.queryParameters['order'],
        startsWith('fecha_inicio.desc'),
      );
      expect(
        requests.where((item) => item.url.path == '/rest/v1/mezcla'),
        isEmpty,
      );
    },
  );

  test('loads the unified farm expense snapshot in one RPC', () async {
    final requests = <http.BaseRequest>[];
    final repository = _repository((request) async {
      requests.add(request);
      return _jsonResponse(_expenseSnapshot);
    });

    final result = await repository.getExpenses('farm-1');

    expect(requests, hasLength(1));
    expect(requests.single.url.path, '/rest/v1/rpc/list_finance_expenses');
    expect(_requestBody(requests.single), {'p_granja_id': 'farm-1'});
    expect(result.targets.single.kind, FinanceExpenseTargetKind.cycle);
    expect(result.expenses.single.amount, 42.5);
  });

  test('creates an expense with a tagged immutable target', () async {
    final requests = <http.BaseRequest>[];
    final repository = _repository((request) async {
      requests.add(request);
      return _jsonResponse(<String, Object?>{});
    });

    await repository.createExpense(
      'farm-1',
      FinanceExpenseDraft(
        targetKind: FinanceExpenseTargetKind.legacyMixture,
        targetId: 'mixture-1',
        occurredOn: DateTime(2026, 9, 19),
        amount: 20,
        category: 'Maintenance',
        note: null,
      ),
    );

    expect(requests.single.url.path, '/rest/v1/rpc/create_finance_expense');
    expect(_requestBody(requests.single), {
      'p_granja_id': 'farm-1',
      'p_target_kind': 'legacy_mixture',
      'p_target_id': 'mixture-1',
      'p_occurred_on': '2026-09-19',
      'p_amount': 20.0,
      'p_category': 'Maintenance',
      'p_note': null,
    });
  });

  test('sends immutable target and optimistic timestamp on update', () async {
    final requests = <http.BaseRequest>[];
    final repository = _repository((request) async {
      requests.add(request);
      return _jsonResponse(<String, Object?>{});
    });
    final expense = _expense;
    final draft = FinanceExpenseDraft(
      targetKind: expense.targetKind,
      targetId: expense.targetId,
      occurredOn: DateTime(2026, 9, 20),
      amount: 55,
      category: 'Veterinaria',
      note: 'Control',
    );

    await repository.updateExpense('farm-1', expense, draft);

    final request = requests.single;
    expect(request.url.path, '/rest/v1/rpc/update_finance_expense');
    expect(
      _requestBody(request),
      containsPair('p_expected_updated_at', '2026-09-20T12:00:00.000Z'),
    );
    expect(_requestBody(request), containsPair('p_target_kind', 'cycle'));
    expect(_requestBody(request), containsPair('p_target_id', 'cycle-1'));
    expect(_requestBody(request), containsPair('p_occurred_on', '2026-09-20'));
  });

  test('sends the complete identity contract on delete', () async {
    final requests = <http.BaseRequest>[];
    final repository = _repository((request) async {
      requests.add(request);
      return _jsonResponse('expense-1');
    });

    await repository.deleteExpense('farm-1', _expense);

    expect(requests.single.url.path, '/rest/v1/rpc/delete_finance_expense');
    expect(_requestBody(requests.single), {
      'p_granja_id': 'farm-1',
      'p_expense_id': 'expense-1',
      'p_target_kind': 'cycle',
      'p_target_id': 'cycle-1',
      'p_expected_updated_at': '2026-09-20T12:00:00.000Z',
    });
  });
}

final _viewRow = <String, Object?>{
  'fecha_inicio': '2026-07-01',
  'fecha_termino': null,
  'mezcla_id': '416e648e-1dd2-4a2f-8246-e42bcc6f36cb',
  'grupo_nombre': 'Gallinero',
  'buenos': 97,
  'rotos': 2,
  'total_costo_comidas': 800,
  'punto_de_equilibrio': 8.2474,
  'granja_id': '48b129e9-a48b-438a-a401-96d4dd863da5',
  'grupo_id': '7428302e-9d3b-4967-9baa-4747c98778bc',
  'fecha_fin_calculada': '2026-07-26',
  'dias_mezcla': 26,
  'consumo_total': 80,
  'aves_promedio_ponderado': 15,
  'huevos_por_dia': 3.7308,
  'huevos_por_dia_ave': 0.2487,
  'consumo_por_dia': 3.0769,
  'consumo_por_dia_ave': 0.2051,
  'precio_venta_promedio': 5,
  'margen_porcentaje': -39.37,
  'total_gastos_directos': 25,
  'costo_total': 825,
};

final _expenseSnapshot = <String, Object?>{
  'granja_id': 'farm-1',
  'role': 'editor',
  'can_edit': true,
  'targets': [
    {
      'target_kind': 'cycle',
      'target_id': 'cycle-1',
      'target_label': 'Engorde norte',
      'starts_on': '2026-09-01',
      'ends_on_exclusive': '2026-10-01',
    },
  ],
  'expenses': [
    {
      'expense_id': 'expense-1',
      'target_kind': 'cycle',
      'target_id': 'cycle-1',
      'target_label': 'Engorde norte',
      'occurred_on': '2026-09-19',
      'amount': 42.5,
      'category': 'Veterinaria',
      'note': null,
      'created_at': '2026-09-19T10:00:00Z',
      'updated_at': '2026-09-20T12:00:00Z',
      'can_mutate': true,
    },
  ],
};

final _expense = FinanceExpense(
  id: 'expense-1',
  targetKind: FinanceExpenseTargetKind.cycle,
  targetId: 'cycle-1',
  targetLabel: 'Engorde norte',
  occurredOn: DateTime(2026, 9, 19),
  amount: 42.5,
  category: 'Veterinaria',
  note: null,
  createdAt: DateTime.utc(2026, 9, 19, 10),
  updatedAt: DateTime.utc(2026, 9, 20, 12),
  canMutate: true,
);

Map<String, dynamic> _requestBody(http.BaseRequest request) =>
    jsonDecode((request as http.Request).body) as Map<String, dynamic>;

SupabaseFinancesRepository _repository(
  Future<http.Response> Function(http.BaseRequest request) handler,
) {
  final client = SupabaseClient(
    'https://example.supabase.co',
    'anon-key',
    httpClient: _RecordingHttpClient(handler),
  );
  client.auth.stopAutoRefresh();
  return SupabaseFinancesRepository(client);
}

http.Response _jsonResponse(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: const {'content-type': 'application/json'},
);

final class _RecordingHttpClient extends http.BaseClient {
  _RecordingHttpClient(this._handler);

  final Future<http.Response> Function(http.BaseRequest request) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _handler(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      reasonPhrase: response.reasonPhrase,
      request: request,
    );
  }
}
