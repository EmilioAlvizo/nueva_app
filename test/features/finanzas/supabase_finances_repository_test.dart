// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:rancho/features/finanzas/data/repositories/supabase_finances_repository.dart';
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
        'margen_porcentaje',
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
};

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
