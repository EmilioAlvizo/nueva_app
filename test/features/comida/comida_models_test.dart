import 'package:flutter_test/flutter_test.dart';
import 'package:rancho/features/comida/comida_models.dart';

void main() {
  group('FoodMixture.fromJson', () {
    test('maps nested categories and calculates totals', () {
      final mixture = FoodMixture.fromJson({
        'id': 'mix-1',
        'granja_id': 'farm-1',
        'grupo_id': 'group-1',
        'fecha_inicio': '2026-07-10',
        'fecha_termino': null,
        'created_at': '2026-07-10T10:00:00Z',
        'updated_at': '2026-07-10T11:00:00Z',
        'grupos': {'nombre': 'Ponedoras'},
        'mezcla_comida': [
          {
            'id': 'line-1',
            'cantidad': 25,
            'comida': {
              'id': 'food-1',
              'cat_comida_id': 'cat-1',
              'cantidad': 25,
              'precio': 42.5,
              'cat_comida': {'nombre': 'Maíz', 'activo': false},
            },
          },
          {
            'id': 'line-2',
            'cantidad': 5.5,
            'comida': {
              'id': 'food-2',
              'cat_comida_id': 'cat-2',
              'cantidad': 5.5,
              'precio': null,
              'cat_comida': {'nombre': 'Minerales', 'activo': true},
            },
          },
        ],
      });

      expect(mixture.groupName, 'Ponedoras');
      expect(mixture.isActive, isTrue);
      expect(mixture.updatedAt, DateTime.parse('2026-07-10T11:00:00Z'));
      expect(mixture.totalKg, 30.5);
      expect(mixture.totalCost, 42.5);
      expect(mixture.ingredients.first.categoryName, 'Maíz');
      expect(mixture.ingredients.first.categoryIsActive, isFalse);
    });
  });

  group('MixtureInput validation', () {
    test('rejects duplicate categories', () {
      final input = MixtureInput(
        farmId: 'farm-1',
        groupId: 'group-1',
        startDate: DateTime(2026, 7, 10),
        ingredients: const [
          MixtureIngredientInput(
            categoryId: 'cat-1',
            quantityKg: 2,
            totalCost: 4,
          ),
          MixtureIngredientInput(
            categoryId: 'cat-1',
            quantityKg: 3,
            totalCost: 6,
          ),
        ],
      );

      expect(input.validate(), contains('repetir'));
    });

    test('rejects invalid quantities, costs, and date order', () {
      final invalidIngredient = MixtureInput(
        farmId: 'farm-1',
        groupId: 'group-1',
        startDate: DateTime(2026, 7, 10),
        ingredients: const [
          MixtureIngredientInput(
            categoryId: 'cat-1',
            quantityKg: 0,
            totalCost: -1,
          ),
        ],
      );
      final invalidDates = MixtureInput(
        farmId: 'farm-1',
        groupId: 'group-1',
        startDate: DateTime(2026, 7, 10),
        endDate: DateTime(2026, 7, 9),
        ingredients: const [
          MixtureIngredientInput(
            categoryId: 'cat-1',
            quantityKg: 1,
            totalCost: 0,
          ),
        ],
      );

      expect(invalidIngredient.validate(), contains('mayor que 0'));
      expect(invalidDates.validate(), contains('anterior'));
    });
  });

  test('FoodValidation accepts comma decimals and bounds ingredient count', () {
    expect(FoodValidation.decimal('2,75'), 2.75);
    expect(FoodValidation.ingredientCount('0', maximum: 3), isNotNull);
    expect(FoodValidation.ingredientCount('4', maximum: 3), contains('3'));
    expect(FoodValidation.ingredientCount('3', maximum: 3), isNull);
  });

  test('ingredient validation rejects every non-finite numeric value', () {
    for (final value in [
      double.nan,
      double.infinity,
      double.negativeInfinity,
    ]) {
      expect(
        MixtureIngredientInput(
          categoryId: 'cat-1',
          quantityKg: value,
          totalCost: value,
        ).validate(),
        isNotNull,
      );
    }
  });
}
