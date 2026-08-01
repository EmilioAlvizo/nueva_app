// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:rancho/features/comida/comida_models.dart';
import 'package:rancho/features/comida/comida_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'createMixture sends one atomic RPC with total-cost ingredients',
    () async {
      final requests = <_RecordedRequest>[];
      final repository = _repository((request) async {
        requests.add(request);
        return http.Response('', 204);
      });

      final input = MixtureInput(
        farmId: 'farm-1',
        groupId: 'group-1',
        startDate: DateTime.utc(2026, 7, 10),
        ingredients: const [
          MixtureIngredientInput(
            categoryId: 'cat-1',
            quantityKg: 12.5,
            totalCost: 31.75,
          ),
        ],
      );
      await repository.createMixture(input);
      await repository.createMixture(input);

      expect(requests, hasLength(2));
      expect(requests.first.method, 'POST');
      expect(requests.first.uri.path, '/rest/v1/rpc/crear_mezcla_completa');
      expect(requests.first.jsonBody, {
        'p_granja_id': 'farm-1',
        'p_mezcla_id': input.mixtureId,
        'p_fecha_inicio': '2026-07-10',
        'p_grupo_id': 'group-1',
        'p_ingredientes': [
          {'categoria_id': 'cat-1', 'cantidad_kg': 12.5, 'costo_total': 31.75},
        ],
      });
      expect(requests.last.jsonBody['p_mezcla_id'], input.mixtureId);
      expect(input.mixtureId, matches(RegExp(r'^[0-9a-f-]{36}$')));
    },
  );

  test('invalid mixture never reaches Supabase', () async {
    var calls = 0;
    final repository = _repository((request) async {
      calls++;
      return http.Response('', 204);
    });

    expect(
      () => repository.createMixture(
        MixtureInput(
          farmId: 'farm-1',
          groupId: 'group-1',
          startDate: DateTime.utc(2026, 7, 10),
          ingredients: const [
            MixtureIngredientInput(
              categoryId: 'cat-1',
              quantityKg: -1,
              totalCost: 10,
            ),
          ],
        ),
      ),
      throwsArgumentError,
    );
    expect(calls, 0);
  });

  test('updateMixture sends the optimistic concurrency precondition', () async {
    final requests = <_RecordedRequest>[];
    final repository = _repository((request) async {
      requests.add(request);
      return http.Response('', 204);
    });
    final expected = DateTime.parse('2026-07-10T11:00:00Z');

    await repository.updateMixture(
      mixtureId: 'mix-1',
      input: MixtureInput(
        mixtureId: 'mix-1',
        farmId: 'farm-1',
        groupId: 'group-1',
        startDate: DateTime.utc(2026, 7, 10),
        expectedUpdatedAt: expected,
        ingredients: const [
          MixtureIngredientInput(
            categoryId: 'cat-1',
            quantityKg: 1,
            totalCost: 2,
          ),
        ],
      ),
    );

    expect(
      requests.single.jsonBody['p_expected_updated_at'],
      expected.toIso8601String(),
    );
  });
}

SupabaseComidaRepository _repository(
  Future<http.Response> Function(_RecordedRequest request) handler,
) {
  final client = SupabaseClient(
    'https://example.supabase.co',
    'anon-key',
    httpClient: _RecordingHttpClient(handler),
  );
  client.auth.stopAutoRefresh();
  return SupabaseComidaRepository(client);
}

class _RecordingHttpClient extends http.BaseClient {
  _RecordingHttpClient(this._handler);

  final Future<http.Response> Function(_RecordedRequest request) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = await utf8.decoder.bind(request.finalize()).join();
    final response = await _handler(
      _RecordedRequest(method: request.method, uri: request.url, body: body),
    );
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      reasonPhrase: response.reasonPhrase,
      request: request,
    );
  }
}

class _RecordedRequest {
  const _RecordedRequest({
    required this.method,
    required this.uri,
    required this.body,
  });

  final String method;
  final Uri uri;
  final String body;

  Map<String, dynamic> get jsonBody => jsonDecode(body) as Map<String, dynamic>;
}
