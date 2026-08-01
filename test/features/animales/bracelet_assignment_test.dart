import 'package:flutter_test/flutter_test.dart';
import 'package:rancho/features/model/altaAnimales/bracelet_assignment.dart';

void main() {
  group('BraceletAssignment', () {
    test('autoAssign fills the remaining slots from the available list', () {
      final assignment = BraceletAssignment(
        totalCount: 3,
        available: const [3, 4, 6],
        selected: const [5],
      ).autoAssign();

      expect(assignment.selected, [3, 4, 5]);
      expect(assignment.missingCount, 0);
    });

    test('manualAdd adds a valid bracelet and clear resets the selection', () {
      final assignment = BraceletAssignment(
        totalCount: 2,
        available: const [10, 11],
      ).manualAdd(12);

      expect(assignment.selected, [12]);
      expect(assignment.clear().selected, isEmpty);
      expect(assignment.clear().missingCount, 2);
    });

    test('rejects duplicate bracelets', () {
      final assignment = BraceletAssignment(
        totalCount: 2,
        available: const [1, 2],
        selected: const [7],
      );

      expect(() => assignment.manualAdd(7), throwsArgumentError);
    });

    test('rejects values outside the positive smallint range', () {
      expect(
        () => BraceletAssignment(totalCount: 1, available: const [0]),
        throwsArgumentError,
      );
      expect(
        () => BraceletAssignment(totalCount: 1).manualAdd(32768),
        throwsArgumentError,
      );
    });
  });
}
