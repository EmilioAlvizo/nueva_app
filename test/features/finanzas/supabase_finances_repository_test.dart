// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nueva_app/features/finanzas/data/repositories/supabase_finances_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('scopes mixtures by farm before querying the required view', () async {
    final requests = <http.BaseRequest>[];
    final repository = _repository((request) async {
      requests.add(request);
      if (request.url.path == '/rest/v1/mezcla') {
        return _jsonResponse([
          {
            'id': '97eb3256-1dd0-42cf-91d0-7d5b84e23b62',
            'grupos': {'granja_id': 'farm-1'},
          },
          {
            'id': '416e648e-1dd2-4a2f-8246-e42bcc6f36cb',
            'grupos': {'granja_id': 'farm-1'},
          },
        ]);
      }
      return _jsonResponse([
        {
          'fecha_inicio': '2023-12-11',
          'fecha_termino': '2024-02-12',
          'mezcla_id': '97eb3256-1dd0-42cf-91d0-7d5b84e23b62',
          'grupo_nombre': 'Gallinero',
          'buenos': 184,
          'rotos': 0,
          'total_costo_comidas': '610',
          'punto_de_equilibrio': '3.3152173913043478',
        },
      ]);
    });

    final result = await repository.getBreakEvenPoints('farm-1');

    expect(result.single.groupName, 'Gallinero');
    expect(requests, hasLength(2));

    final mixtureRequest = requests.first;
    expect(mixtureRequest.method, 'GET');
    expect(mixtureRequest.url.path, '/rest/v1/mezcla');
    expect(
      mixtureRequest.url.queryParameters['select'],
      'id,grupos!inner(granja_id)',
    );
    expect(mixtureRequest.url.queryParameters['grupos.granja_id'], 'eq.farm-1');

    final viewRequest = requests.last;
    expect(viewRequest.method, 'GET');
    expect(viewRequest.url.path, '/rest/v1/puntos_equilibrio_huevos');
    expect(
      viewRequest.url.queryParameters['select'],
      'fecha_inicio,fecha_termino,mezcla_id,grupo_nombre,buenos,rotos,'
      'total_costo_comidas,punto_de_equilibrio',
    );
    expect(
      viewRequest.url.queryParameters['mezcla_id'],
      'in.("97eb3256-1dd0-42cf-91d0-7d5b84e23b62",'
      '"416e648e-1dd2-4a2f-8246-e42bcc6f36cb")',
    );
    expect(
      viewRequest.url.queryParameters['order'],
      startsWith('fecha_inicio.desc'),
    );
  });

  test('does not query the view when the farm has no mixtures', () async {
    final requests = <http.BaseRequest>[];
    final repository = _repository((request) async {
      requests.add(request);
      return _jsonResponse([]);
    });

    final result = await repository.getBreakEvenPoints('farm-without-mixtures');

    expect(result, isEmpty);
    expect(requests, hasLength(1));
    expect(requests.single.url.path, '/rest/v1/mezcla');
  });
}

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
