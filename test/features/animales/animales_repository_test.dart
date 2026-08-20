// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:rancho/features/animales/animales_repository.dart';
import 'package:rancho/features/model/altaAnimales/registrar_alta_animales_input.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('AnimalesRepository.registrarAltaAnimales', () {
    test('calls registrar_alta_animales rpc once with mapped params', () async {
      final requests = <_RecordedRequest>[];
      final repository = _createRepository((request) async {
        requests.add(request);

        return http.Response(
          jsonEncode({
            'id': 'alta-1',
            'granja_id': 'farm-1',
            'tipo_animal_id': 'type-1',
            'grupo_id': 'group-1',
            'proposito_id': null,
            'tipo_adquisicion_id': null,
            'proveedor': 'Proveedor Uno',
            'fecha_alta': '2026-07-08',
            'cantidad_animales': 2,
            'costo_total': 150.75,
            'notas': 'Ingreso inicial',
            'created_by': 'user-1',
            'created_at': '2026-07-08T12:00:00Z',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final alta = await repository.registrarAltaAnimales(
        RegistrarAltaAnimalesInput(
          granjaId: 'farm-1',
          tipoAnimalId: 'type-1',
          grupoId: 'group-1',
          propositoId: 'purpose-1',
          tipoAdquisicionId: 'acquisition-1',
          fechaAlta: DateTime.utc(2026, 7, 8),
          cantidad: 2,
          bracelets: const [11, 12],
          proveedor: 'Proveedor Uno',
          costoTotal: 150.75,
          notas: 'Ingreso inicial',
        ),
      );

      expect(requests, hasLength(1));
      expect(requests.single.method, 'POST');
      expect(requests.single.uri.path, '/rest/v1/rpc/registrar_alta_animales');
      expect(requests.single.jsonBody, {
        'granja_id': 'farm-1',
        'tipo_animal_id': 'type-1',
        'grupo_id': 'group-1',
        'proposito_id': 'purpose-1',
        'tipo_adquisicion_id': 'acquisition-1',
        'fecha_alta': '2026-07-08',
        'cantidad': 2,
        'bracelets': [11, 12],
        'proveedor': 'Proveedor Uno',
        'costo_total': 150.75,
        'notas': 'Ingreso inicial',
      });
      expect(alta.id, 'alta-1');
      expect(alta.createdAt, DateTime.parse('2026-07-08T12:00:00Z'));
    });

    test('rejects invalid bracelet payload before calling rpc', () async {
      var rpcCalls = 0;
      final repository = _createRepository((request) async {
        rpcCalls++;
        return http.Response(
          '{}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      expect(
        () => repository.registrarAltaAnimales(
          RegistrarAltaAnimalesInput(
            granjaId: 'farm-1',
            tipoAnimalId: 'type-1',
            fechaAlta: DateTime.utc(2026, 7, 8),
            cantidad: 1,
            bracelets: const [5, 5],
          ),
        ),
        throwsArgumentError,
      );
      expect(rpcCalls, 0);
    });
  });

  group('AnimalesRepository.registrarVentaAnimalV2', () {
    test(
      'sends canonical sale payload and refetches committed bajas',
      () async {
        final requests = <_RecordedRequest>[];
        final repository = _createRepository((request) async {
          requests.add(request);

          if (request.uri.path.endsWith('/rpc/registrar_venta_animal_v2')) {
            return http.Response(
              jsonEncode('sale-1'),
              200,
              headers: {'content-type': 'application/json'},
            );
          }

          if (request.uri.path.endsWith('/vista_bajas_animales')) {
            return http.Response(
              jsonEncode([_bajaJson()]),
              200,
              headers: {'content-type': 'application/json'},
            );
          }

          throw StateError(
            'Unexpected request: ${request.method} ${request.uri}',
          );
        });

        final bajas = await repository.registrarVentaAnimalV2(
          granjaId: 'farm-1',
          animalIds: const ['animal-1', 'animal-2'],
          fechaVenta: DateTime.utc(2026, 8, 19),
          totalAmount: 150.75,
          peso: 2.5,
          notas: '  Canonical sale  ',
        );

        expect(bajas, hasLength(1));
        expect(bajas.single.id, 'baja-1');
        expect(requests, hasLength(2));
        expect(requests.first.method, 'POST');
        expect(
          requests.first.uri.path,
          '/rest/v1/rpc/registrar_venta_animal_v2',
        );
        expect(requests.first.jsonBody, {
          'p_granja_id': 'farm-1',
          'p_animal_ids': ['animal-1', 'animal-2'],
          'p_fecha_venta': '2026-08-19',
          'p_total_amount': 150.75,
          'p_peso': 2.5,
          'p_notas': 'Canonical sale',
        });
        expect(requests.last.uri.path, '/rest/v1/vista_bajas_animales');
        expect(requests.last.uri.queryParameters['granja_id'], 'eq.farm-1');
      },
    );

    test(
      'preserves nullable sale fields when refetching the canonical baja',
      () async {
        final requests = <_RecordedRequest>[];
        final repository = _createRepository((request) async {
          requests.add(request);

          if (request.uri.path.endsWith('/rpc/registrar_venta_animal_v2')) {
            return http.Response(
              jsonEncode('sale-2'),
              200,
              headers: {'content-type': 'application/json'},
            );
          }

          return http.Response(
            jsonEncode([_bajaJson(id: 'baja-2')]),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final bajas = await repository.registrarVentaAnimalV2(
          granjaId: 'farm-1',
          animalIds: const ['animal-1'],
          fechaVenta: DateTime.utc(2026, 8, 20),
          totalAmount: 0,
          notas: '   ',
        );

        expect(bajas.single.id, 'baja-2');
        expect(requests.first.jsonBody['p_peso'], isNull);
        expect(requests.first.jsonBody['p_notas'], isNull);
        expect(requests.last.uri.queryParameters['granja_id'], 'eq.farm-1');
      },
    );

    test('does not refetch when the canonical sale RPC fails', () async {
      final requests = <_RecordedRequest>[];
      final repository = _createRepository((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({'message': 'Sale access denied', 'code': '42501'}),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      await expectLater(
        repository.registrarVentaAnimalV2(
          granjaId: 'farm-1',
          animalIds: const ['animal-1'],
          fechaVenta: DateTime.utc(2026, 8, 20),
          totalAmount: 10,
        ),
        throwsA(isA<PostgrestException>()),
      );

      expect(requests, hasLength(1));
      expect(
        requests.single.uri.path,
        '/rest/v1/rpc/registrar_venta_animal_v2',
      );
    });
  });

  group('AnimalesRepository.getAltas', () {
    test('queries all altas for a farm and maps rows', () async {
      final requests = <_RecordedRequest>[];
      final repository = _createRepository((request) async {
        requests.add(request);

        if (request.uri.path.endsWith('/animales')) {
          return http.Response(
            jsonEncode([
              {'alta_id': 'alta-1', 'brazalete': 1, 'activo': true},
              {'alta_id': 'alta-1', 'brazalete': 2, 'activo': true},
              {'alta_id': 'alta-1', 'brazalete': 3, 'activo': false},
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response(
          jsonEncode([
            {
              'id': 'alta-1',
              'granja_id': 'farm-1',
              'tipo_animal_id': 'type-1',
              'grupo_id': null,
              'proposito_id': null,
              'tipo_adquisicion_id': null,
              'proveedor': null,
              'fecha_alta': '2026-07-08',
              'cantidad_animales': 3,
              'costo_total': null,
              'notas': null,
              'created_by': 'user-1',
              'created_at': '2026-07-08T08:00:00Z',
              'brazaletes': [1, 2, 3],
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final altas = await repository.getAltas('farm-1');

      expect(altas, hasLength(1));
      expect(altas.single.grupoId, isNull);
      expect(altas.single.createdAt, DateTime.parse('2026-07-08T08:00:00Z'));
      expect(altas.single.cantidadVivos, 2);
      expect(altas.single.cantidadInactivos, 1);
      expect(requests, hasLength(2));
      expect(requests.first.uri.path, '/rest/v1/vista_altas_animales');
      expect(requests.first.uri.queryParameters['granja_id'], 'eq.farm-1');
      expect(
        requests.first.uri.queryParameters.containsKey('grupo_id'),
        isFalse,
      );
      expect(requests.last.uri.path, '/rest/v1/animales');
      expect(requests.last.uri.queryParameters['alta_id'], 'in.("alta-1")');
    });

    test('adds a group filter when grupoId is provided', () async {
      final requests = <_RecordedRequest>[];
      final repository = _createRepository((request) async {
        requests.add(request);
        return http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      await repository.getAltas('farm-1', grupoId: 'group-9');

      expect(requests.single.uri.queryParameters['grupo_id'], 'eq.group-9');
    });
  });

  group('AnimalesRepository.getNoGroupOverview', () {
    test('returns counts and latest altas for ungrouped records', () async {
      final requests = <_RecordedRequest>[];
      final repository = _createRepository((request) async {
        requests.add(request);

        if (request.uri.path.endsWith('/animales')) {
          return http.Response(
            jsonEncode([
              {'tipo_animal_id': 'type-1', 'activo': true},
              {'tipo_animal_id': 'type-1', 'activo': true},
              {'tipo_animal_id': 'type-1', 'activo': false},
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        throw StateError(
          'Unexpected request: ${request.method} ${request.uri}',
        );
      });

      final overview = await repository.getNoGroupOverview('farm-1');

      expect(overview.activeCount, 2);
      expect(overview.deadCount, 1);
      expect(overview.latestAltas, isEmpty);
      expect(overview.typeSummaries, hasLength(1));
      expect(overview.typeSummaries.single.tipoAnimalId, 'type-1');
      expect(overview.typeSummaries.single.activeCount, 2);
      expect(overview.typeSummaries.single.inactiveCount, 1);
      expect(requests, hasLength(1));
      expect(requests.single.uri.path, '/rest/v1/animales');
      expect(requests.single.uri.queryParameters['granja_id'], 'eq.farm-1');
      expect(requests.single.uri.queryParameters['grupo_id'], 'is.null');
      expect(
        requests.single.uri.queryParameters.containsKey('activo'),
        isFalse,
      );
    });

    test('returns an empty overview when no ungrouped records exist', () async {
      final repository = _createRepository((_) async {
        return http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final overview = await repository.getNoGroupOverview('farm-1');

      expect(overview.activeCount, 0);
      expect(overview.deadCount, 0);
      expect(overview.latestAltas, isEmpty);
    });
  });

  group('AnimalesRepository.getAvailableBracelets', () {
    test(
      'returns free bracelet numbers for the selected farm and type',
      () async {
        final requests = <_RecordedRequest>[];
        final repository = _createRepository((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode([
              {'brazalete': 2},
              {'brazalete': 4},
              {'brazalete': null},
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final available = await repository.getAvailableBracelets(
          'farm-1',
          'type-1',
        );

        expect(available.take(5), [1, 3, 5, 6, 7]);
        expect(requests.single.uri.queryParameters['granja_id'], 'eq.farm-1');
        expect(
          requests.single.uri.queryParameters['tipo_animal_id'],
          'eq.type-1',
        );
      },
    );

    test('starts at bracelet 1 when no used bracelet exists', () async {
      final repository = _createRepository((_) async {
        return http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final available = await repository.getAvailableBracelets(
        'farm-1',
        'type-1',
      );

      expect(available.take(3), [1, 2, 3]);
    });
  });
}

Map<String, dynamic> _bajaJson({String id = 'baja-1'}) => {
  'id': id,
  'granja_id': 'farm-1',
  'tipo_animal_id': 'type-1',
  'razon_baja_id': 'reason-sale',
  'fecha_baja': '2026-08-19',
  'cantidad_animales': 2,
  'importe_total': 150.75,
  'notas': 'Canonical sale',
  'tipo_nombre': 'Chicken',
  'grupo_nombre': 'Group One',
  'razon_nombre': 'Sale',
  'brazaletes': [1, 2],
};

AnimalesRepository _createRepository(
  Future<http.Response> Function(_RecordedRequest request) handler,
) {
  final httpClient = _RecordingHttpClient(handler);
  final client = SupabaseClient(
    'https://example.supabase.co',
    'anon-key',
    httpClient: httpClient,
  );

  return AnimalesRepository(client);
}

class _RecordingHttpClient extends http.BaseClient {
  _RecordingHttpClient(this._handler);

  final Future<http.Response> Function(_RecordedRequest request) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = await utf8.decoder.bind(request.finalize()).join();
    final response = await _handler(
      _RecordedRequest(
        method: request.method,
        uri: request.url,
        headers: request.headers,
        body: body,
      ),
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
    required this.headers,
    required this.body,
  });

  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final String body;

  Map<String, dynamic> get jsonBody => body.isEmpty
      ? <String, dynamic>{}
      : jsonDecode(body) as Map<String, dynamic>;
}
