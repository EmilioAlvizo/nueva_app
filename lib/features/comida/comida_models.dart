import 'dart:math';

class FoodCategory {
  const FoodCategory({
    required this.id,
    required this.name,
    required this.isActive,
    this.farmId,
    this.createdAt,
  });

  final String id;
  final String? farmId;
  final String name;
  final bool isActive;
  final DateTime? createdAt;

  factory FoodCategory.fromJson(Map<String, dynamic> json) => FoodCategory(
    id: json['id'] as String,
    farmId: json['granja_id'] as String?,
    name: json['nombre'] as String,
    isActive: json['activo'] as bool? ?? true,
    createdAt: switch (json['created_at']) {
      final String value => DateTime.parse(value),
      _ => null,
    },
  );
}

class FoodGroup {
  const FoodGroup({required this.id, required this.name});

  final String id;
  final String name;

  factory FoodGroup.fromJson(Map<String, dynamic> json) =>
      FoodGroup(id: json['id'] as String, name: json['nombre'] as String);
}

class MixtureIngredient {
  const MixtureIngredient({
    required this.id,
    required this.foodId,
    required this.categoryId,
    required this.categoryName,
    required this.categoryIsActive,
    required this.quantityKg,
    required this.totalCost,
  });

  final String id;
  final String foodId;
  final String categoryId;
  final String categoryName;
  final bool categoryIsActive;
  final double quantityKg;
  final double totalCost;

  factory MixtureIngredient.fromJson(Map<String, dynamic> json) {
    final food = Map<String, dynamic>.from(json['comida'] as Map);
    final category = Map<String, dynamic>.from(food['cat_comida'] as Map);
    return MixtureIngredient(
      id: json['id'] as String,
      foodId: food['id'] as String,
      categoryId: food['cat_comida_id'] as String,
      categoryName: category['nombre'] as String,
      categoryIsActive: category['activo'] as bool? ?? true,
      quantityKg: ((json['cantidad'] ?? food['cantidad']) as num).toDouble(),
      totalCost: (food['precio'] as num?)?.toDouble() ?? 0,
    );
  }
}

class FoodMixture {
  const FoodMixture({
    required this.id,
    required this.farmId,
    required this.groupId,
    required this.groupName,
    required this.startDate,
    required this.updatedAt,
    required this.ingredients,
    this.endDate,
    this.createdAt,
  });

  final String id;
  final String farmId;
  final String groupId;
  final String groupName;
  final DateTime startDate;
  final DateTime updatedAt;
  final DateTime? endDate;
  final DateTime? createdAt;
  final List<MixtureIngredient> ingredients;

  bool get isActive => endDate == null;
  double get totalKg =>
      ingredients.fold(0, (sum, item) => sum + item.quantityKg);
  double get totalCost =>
      ingredients.fold(0, (sum, item) => sum + item.totalCost);

  factory FoodMixture.fromJson(Map<String, dynamic> json) {
    final group = json['grupos'] as Map?;
    final ingredientRows =
        (json['mezcla_comida'] as List? ?? const [])
            .map(
              (row) => MixtureIngredient.fromJson(
                Map<String, dynamic>.from(row as Map),
              ),
            )
            .toList()
          ..sort((a, b) => a.categoryName.compareTo(b.categoryName));
    return FoodMixture(
      id: json['id'] as String,
      farmId: json['granja_id'] as String,
      groupId: json['grupo_id'] as String,
      groupName: group?['nombre'] as String? ?? 'Grupo sin nombre',
      startDate: DateTime.parse(json['fecha_inicio'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      endDate: switch (json['fecha_termino']) {
        final String value => DateTime.parse(value),
        _ => null,
      },
      createdAt: switch (json['created_at']) {
        final String value => DateTime.parse(value),
        _ => null,
      },
      ingredients: List.unmodifiable(ingredientRows),
    );
  }
}

class FoodStats {
  const FoodStats({
    required this.totalKg,
    required this.totalCost,
    required this.count,
  });

  final double totalKg;
  final double totalCost;
  final int count;

  factory FoodStats.forMixtures(List<FoodMixture> mixtures) => FoodStats(
    totalKg: mixtures.fold(0, (sum, mixture) => sum + mixture.totalKg),
    totalCost: mixtures.fold(0, (sum, mixture) => sum + mixture.totalCost),
    count: mixtures.length,
  );

  factory FoodStats.forCategories({
    required List<FoodMixture> mixtures,
    required List<FoodCategory> categories,
  }) => FoodStats(
    totalKg: mixtures.fold(0, (sum, mixture) => sum + mixture.totalKg),
    totalCost: mixtures.fold(0, (sum, mixture) => sum + mixture.totalCost),
    count: categories.where((category) => category.isActive).length,
  );
}

class FoodAccess {
  const FoodAccess({required this.canEdit});

  final bool canEdit;
}

class MixtureIngredientInput {
  const MixtureIngredientInput({
    required this.categoryId,
    required this.quantityKg,
    required this.totalCost,
  });

  final String categoryId;
  final double quantityKg;
  final double totalCost;

  Map<String, Object> toJson() => {
    'categoria_id': categoryId,
    'cantidad_kg': quantityKg,
    'costo_total': totalCost,
  };

  String? validate() {
    if (categoryId.trim().isEmpty) return 'Selecciona una categoría.';
    if (!quantityKg.isFinite || quantityKg <= 0) {
      return 'La cantidad debe ser mayor que 0.';
    }
    if (!totalCost.isFinite || totalCost < 0) {
      return 'El precio total no puede ser negativo.';
    }
    return null;
  }
}

class MixtureInput {
  MixtureInput({
    String? mixtureId,
    required this.farmId,
    required this.groupId,
    required this.startDate,
    required this.ingredients,
    this.endDate,
    this.expectedUpdatedAt,
  }) : mixtureId = mixtureId ?? newFoodUuid();

  final String mixtureId;
  final String farmId;
  final String groupId;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime? expectedUpdatedAt;
  final List<MixtureIngredientInput> ingredients;

  String? validate() {
    if (farmId.trim().isEmpty || groupId.trim().isEmpty) {
      return 'Selecciona un grupo.';
    }
    if (endDate != null && _dateOnly(endDate!).isBefore(_dateOnly(startDate))) {
      return 'La fecha de término no puede ser anterior al inicio.';
    }
    if (ingredients.isEmpty) return 'Agrega al menos un ingrediente.';
    final categoryIds = <String>{};
    for (final ingredient in ingredients) {
      final error = ingredient.validate();
      if (error != null) return error;
      if (!categoryIds.add(ingredient.categoryId)) {
        return 'No puedes repetir una categoría en la misma mezcla.';
      }
    }
    return null;
  }
}

abstract final class FoodValidation {
  static String? categoryName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Escribe el nombre de la categoría.';
    }
    if (value.trim().length > 80) {
      return 'El nombre no puede superar 80 caracteres.';
    }
    return null;
  }

  static String? ingredientCount(String? value, {required int maximum}) {
    final count = int.tryParse(value?.trim() ?? '');
    if (count == null || count <= 0) {
      return 'La cantidad de ingredientes debe ser mayor que 0.';
    }
    if (count > maximum) {
      return 'Sólo hay $maximum categorías disponibles.';
    }
    return null;
  }

  static double? decimal(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String newFoodUuid() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
