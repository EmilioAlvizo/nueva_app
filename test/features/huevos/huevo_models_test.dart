import 'package:flutter_test/flutter_test.dart';
import 'package:rancho/features/huevos/huevo_models.dart';

void main() {
  group('EggCollection', () {
    test('maps repository JSON and derives its total', () {
      final collection = EggCollection.fromJson({
        'id': 'collection-1',
        'granja_id': 'farm-1',
        'grupo_id': 'group-1',
        'fecha_recoleccion': '2026-07-20',
        'buenos': '24',
        'rotos': 3,
        'created_at': '2026-07-20T08:00:00Z',
        'group': {
          'nombre': 'Ponedoras A',
          'tipo_animal_id': 'type-1',
          'animal_type': {'nombre': 'Gallinas'},
        },
        'author': {'nombre': 'Ana Pérez'},
      });

      expect(collection.groupName, 'Ponedoras A');
      expect(collection.animalTypeName, 'Gallinas');
      expect(collection.authorName, 'Ana Pérez');
      expect(collection.goodEggs, 24);
      expect(collection.brokenEggs, 3);
      expect(collection.totalEggs, 27);
    });

    test('uses safe display fallbacks when joins are absent', () {
      final collection = EggCollection.fromJson({
        'id': 'collection-2',
        'granja_id': 'farm-1',
        'grupo_id': 'group-2',
        'fecha_recoleccion': '2026-07-20',
        'buenos': 1,
        'rotos': 0,
        'created_at': '2026-07-20T08:00:00Z',
      });

      expect(collection.groupName, 'Grupo desconocido');
      expect(collection.animalTypeName, 'Tipo desconocido');
      expect(collection.authorName, 'Usuario desconocido');
    });
  });

  group('EggSale', () {
    test('maps nullable historical group and numeric price', () {
      final sale = EggSale.fromJson({
        'id': 'sale-1',
        'granja_id': 'farm-1',
        'grupo_id': null,
        'fecha_venta': '2026-07-21',
        'cantidad': 6.0,
        'precio': '2.50',
        'created_at': '2026-07-21T10:00:00Z',
      });

      expect(sale.groupId, isNull);
      expect(sale.groupName, 'Sin grupo histórico');
      expect(sale.quantity, 6);
      expect(sale.unitPrice, 2.5);
      expect(sale.total, 15);
    });
  });

  group('EggData.filtered', () {
    test('applies animal type, group, and inclusive period boundaries', () {
      final data = EggData(
        collections: [
          _collection(id: 'first', date: DateTime(2026, 7, 1)),
          _collection(id: 'boundary', date: DateTime(2026, 6, 25)),
          _collection(
            id: 'other-type',
            animalTypeId: 'type-2',
            date: DateTime(2026, 7, 1),
          ),
        ],
        sales: [
          _sale(id: 'today', date: DateTime(2026, 7, 1)),
          _sale(id: 'future', date: DateTime(2026, 7, 2)),
          _sale(id: 'old', date: DateTime(2026, 6, 23)),
        ],
      );

      final filtered = data.filtered(
        animalTypeId: 'type-1',
        filters: const EggFilters(groupId: 'group-1', period: EggPeriod.weekly),
        now: DateTime(2026, 7, 1, 23, 59),
      );

      expect(filtered.collections.map((item) => item.id), [
        'first',
        'boundary',
      ]);
      expect(filtered.sales.map((item) => item.id), ['today']);
    });

    test('total period keeps all dates while preserving other filters', () {
      final data = EggData(
        collections: [
          _collection(id: 'old', date: DateTime(2020)),
          _collection(id: 'other-group', groupId: 'group-2'),
        ],
        sales: const [],
      );

      final filtered = data.filtered(
        animalTypeId: 'all',
        filters: const EggFilters(groupId: 'group-1', period: EggPeriod.total),
        now: DateTime(2026, 7, 1),
      );

      expect(filtered.collections.single.id, 'old');
    });
  });

  group('EggSummary', () {
    test('aggregates destinations, income, average, and activity counts', () {
      final summary = EggSummary.fromData(
        EggData(
          collections: [
            _collection(goodEggs: 20, brokenEggs: 2),
            _collection(id: 'collection-2', goodEggs: 10, brokenEggs: 1),
          ],
          sales: [
            _sale(quantity: 12, unitPrice: 2.5),
            _sale(id: 'sale-2', quantity: 3, unitPrice: 5),
          ],
        ),
      );

      expect(summary.goodEggs, 30);
      expect(summary.brokenEggs, 3);
      expect(summary.soldEggs, 15);
      expect(summary.consumedEggs, 15);
      expect(summary.income, 45);
      expect(summary.averageSalePrice, 3);
      expect(summary.destinationTotal, 33);
      expect(summary.collectionCount, 2);
      expect(summary.saleCount, 2);
    });

    test('keeps empty and oversold summaries finite and non-negative', () {
      final empty = EggSummary.fromData(
        const EggData(collections: [], sales: []),
      );
      final oversold = EggSummary.fromData(
        EggData(
          collections: [_collection(goodEggs: 2)],
          sales: [_sale(quantity: 5)],
        ),
      );

      expect(empty.averageSalePrice, 0);
      expect(empty.income.isFinite, isTrue);
      expect(oversold.consumedEggs, 0);
    });
  });

  group('filters and inputs', () {
    test('EggFilters has value equality and explicit group clearing', () {
      const filters = EggFilters(groupId: 'group-1');

      expect(filters, const EggFilters(groupId: 'group-1'));
      expect(filters.copyWith(period: EggPeriod.total).groupId, 'group-1');
      expect(filters.copyWith(clearGroup: true).groupId, isNull);
    });

    test('collection input rejects missing, negative, and empty totals', () {
      expect(_collectionInput(groupId: '').validate(), isNotNull);
      expect(_collectionInput(goodEggs: -1).validate(), isNotNull);
      expect(
        _collectionInput(goodEggs: 0, brokenEggs: 0).validate(),
        isNotNull,
      );
      expect(_collectionInput().validate(), isNull);
    });

    test('sale input rejects invalid quantity and non-finite prices', () {
      expect(_saleInput(groupId: '').validate(), isNotNull);
      expect(_saleInput(quantity: 0).validate(), isNotNull);
      expect(_saleInput(unitPrice: double.nan).validate(), isNotNull);
      expect(_saleInput(unitPrice: double.infinity).validate(), isNotNull);
      expect(_saleInput().validate(), isNull);
      expect(_saleInput().total, 5);
    });
  });
}

EggCollection _collection({
  String id = 'collection-1',
  String groupId = 'group-1',
  String animalTypeId = 'type-1',
  DateTime? date,
  int goodEggs = 10,
  int brokenEggs = 0,
}) {
  return EggCollection(
    id: id,
    farmId: 'farm-1',
    groupId: groupId,
    date: date ?? DateTime(2026, 7, 1),
    goodEggs: goodEggs,
    brokenEggs: brokenEggs,
    createdAt: DateTime(2026, 7, 1),
    groupName: groupId,
    animalTypeId: animalTypeId,
    animalTypeName: animalTypeId,
    authorName: 'Ana Pérez',
  );
}

EggSale _sale({
  String id = 'sale-1',
  String? groupId = 'group-1',
  String animalTypeId = 'type-1',
  DateTime? date,
  int quantity = 2,
  double unitPrice = 2.5,
}) {
  return EggSale(
    id: id,
    farmId: 'farm-1',
    groupId: groupId,
    date: date ?? DateTime(2026, 7, 1),
    quantity: quantity,
    unitPrice: unitPrice,
    createdAt: DateTime(2026, 7, 1),
    groupName: groupId ?? 'Historical',
    animalTypeId: animalTypeId,
    animalTypeName: animalTypeId,
    authorName: 'Ana Pérez',
  );
}

EggCollectionInput _collectionInput({
  String groupId = 'group-1',
  int goodEggs = 1,
  int brokenEggs = 0,
}) {
  return EggCollectionInput(
    farmId: 'farm-1',
    groupId: groupId,
    goodEggs: goodEggs,
    brokenEggs: brokenEggs,
    date: DateTime(2026, 7, 1),
  );
}

EggSaleInput _saleInput({
  String groupId = 'group-1',
  int quantity = 2,
  double unitPrice = 2.5,
}) {
  return EggSaleInput(
    farmId: 'farm-1',
    groupId: groupId,
    quantity: quantity,
    unitPrice: unitPrice,
    date: DateTime(2026, 7, 1),
  );
}
