import 'package:flutter_test/flutter_test.dart';
import 'package:rancho/features/granja/granja.dart';

void main() {
  group('Granja.fromMap', () {
    test('preserves a null email from the embedded owner profile', () {
      late Granja farm;

      expect(
        () => farm = Granja.fromMap({
          'id': 'farm-1',
          'nombre': 'North Farm',
          'created_at': '2026-08-25T12:00:00Z',
          'owner_id': 'user-1',
          'perfiles': {'id': 'user-1', 'nombre': 'Farm Owner', 'email': null},
        }),
        returnsNormally,
      );
      expect(farm.ownerProfile, isNotNull);
      expect(farm.ownerProfile?.email, isNull);
    });
  });
}
