import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
import 'package:rancho/features/ciclos/data/economics_v2_supabase_repository.dart';
import 'package:rancho/features/ciclos/domain/economics_v2_lifecycle_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('EconomicsV2SupabaseRepository lifecycle RPC bridge', () {
    test('sends all lifecycle RPC names and typed payloads exactly', () async {
      final client = _RecordingHttpClient([
        (200, 'cycle-1'),
        (200, null),
        (200, 'expense-1'),
        (200, 'feed-1'),
      ]);
      final repository = _repository(client);

      final cycle = await repository.createCycle(
        EconomicsV2CreateCycleRequest(
          farmId: 'farm-1',
          purposeId: 'purpose-1',
          startsOn: DateTime(2026, 8, 21),
        ),
      );
      final assignment = await repository.assignAnimal(
        EconomicsV2AssignAnimalRequest(
          farmId: 'farm-1',
          cycleId: 'cycle-1',
          animalId: 'animal-1',
          joinedOn: DateTime(2026, 8, 22),
        ),
      );
      final expense = await repository.recordExpense(
        EconomicsV2RecordExpenseRequest(
          farmId: 'farm-1',
          cycleId: 'cycle-1',
          occurredOn: DateTime(2026, 8, 23),
          amount: 12.5,
          note: 'Feed delivery',
        ),
      );
      final feed = await repository.linkFeed(
        EconomicsV2LinkFeedRequest(
          farmId: 'farm-1',
          cycleId: 'cycle-1',
          mixtureId: 'mixture-1',
          startsOn: DateTime(2026, 8, 24),
          endsOn: DateTime(2026, 8, 31),
        ),
      );

      expect(cycle.cycleId, 'cycle-1');
      expect(assignment.cycleId, 'cycle-1');
      expect(assignment.animalId, 'animal-1');
      expect(expense.expenseId, 'expense-1');
      expect(feed.feedId, 'feed-1');
      expect(_identities(client), [
        'crear_ciclo_v2:{"p_granja_id":"farm-1","p_proposito_id":"purpose-1","p_starts_on":"2026-08-21"}',
        'asignar_animal_ciclo_v2:{"p_granja_id":"farm-1","p_cycle_id":"cycle-1","p_animal_id":"animal-1","p_joined_on":"2026-08-22"}',
        'registrar_gasto_ciclo_v2:{"p_granja_id":"farm-1","p_cycle_id":"cycle-1","p_occurred_on":"2026-08-23","p_amount":12.5,"p_note":"Feed delivery"}',
        'vincular_alimento_ciclo_v2:{"p_granja_id":"farm-1","p_cycle_id":"cycle-1","p_mezcla_id":"mixture-1","p_starts_on":"2026-08-24","p_ends_on":"2026-08-31"}',
      ]);
    });

    test('keeps nullable lifecycle fields in the exact RPC payload', () async {
      final client = _RecordingHttpClient([
        (200, 'expense-2'),
        (200, 'feed-2'),
      ]);
      final repository = _repository(client);

      final expense = await repository.recordExpense(
        EconomicsV2RecordExpenseRequest(
          farmId: 'farm-2',
          cycleId: 'cycle-2',
          occurredOn: DateTime(2026, 9, 1),
          amount: 0,
        ),
      );
      final feed = await repository.linkFeed(
        EconomicsV2LinkFeedRequest(
          farmId: 'farm-2',
          cycleId: 'cycle-2',
          mixtureId: 'mixture-2',
          startsOn: DateTime(2026, 9, 2),
        ),
      );

      expect(expense.expenseId, 'expense-2');
      expect(feed.feedId, 'feed-2');
      expect(_identities(client), [
        'registrar_gasto_ciclo_v2:{"p_granja_id":"farm-2","p_cycle_id":"cycle-2","p_occurred_on":"2026-09-01","p_amount":0.0,"p_note":null}',
        'vincular_alimento_ciclo_v2:{"p_granja_id":"farm-2","p_cycle_id":"cycle-2","p_mezcla_id":"mixture-2","p_starts_on":"2026-09-02","p_ends_on":null}',
      ]);
    });

    test('propagates the server PostgREST error without remapping', () async {
      final client = _RecordingHttpClient([
        (
          403,
          {
            'message': 'Farm access denied',
            'code': '42501',
            'details': 'farm-3 is not owned by the current user',
            'hint': 'Use an authorized farm.',
          },
        ),
      ]);
      final repository = _repository(client);

      await expectLater(
        repository.createCycle(
          EconomicsV2CreateCycleRequest(
            farmId: 'farm-3',
            purposeId: 'purpose-3',
            startsOn: DateTime(2026, 9, 3),
          ),
        ),
        throwsA(
          isA<PostgrestException>()
              .having((error) => error.message, 'message', 'Farm access denied')
              .having((error) => error.code, 'code', '42501')
              .having(
                (error) => error.details,
                'details',
                'farm-3 is not owned by the current user',
              )
              .having((error) => error.hint, 'hint', 'Use an authorized farm.'),
        ),
      );
    });
  });
}

EconomicsV2SupabaseRepository _repository(_RecordingHttpClient client) =>
    EconomicsV2SupabaseRepository(
      SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: client,
      ),
    );

final class _RpcRequest {
  const _RpcRequest(this.name, this.body);

  final String name;
  final Map<String, dynamic> body;
}

List<String> _identities(_RecordingHttpClient client) => [
  for (final request in client.requests)
    '${request.name}:${jsonEncode(request.body)}',
];

final class _RecordingHttpClient extends http.BaseClient {
  _RecordingHttpClient(this._responses);

  final List<(int, Object?)> _responses;
  final List<_RpcRequest> requests = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body =
        jsonDecode(await request.finalize().bytesToString())
            as Map<String, dynamic>;
    final (statusCode, response) = _responses.removeAt(0);
    requests.add(_RpcRequest(request.url.pathSegments.last, body));
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(jsonEncode(response))),
      statusCode,
      headers: const {'content-type': 'application/json'},
      request: request,
    );
  }
}
