import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nueva_app/core/theme/app_colors.dart';
import 'package:nueva_app/core/theme/app_theme.dart';
import 'package:nueva_app/features/huevos/huevo_cards.dart';
import 'package:nueva_app/features/huevos/huevo_forms.dart';
import 'package:nueva_app/features/huevos/huevo_models.dart';
import 'package:nueva_app/features/huevos/huevo_pie_chart.dart';
import 'package:nueva_app/features/huevos/huevo_summary.dart';

void main() {
  testWidgets(
    'collection card has olive body, right stripe, footer, and menu',
    (tester) async {
      var edited = false;
      await _pump(
        tester,
        EggCollectionCard(
          collection: _collection(),
          canEdit: true,
          onEdit: () => edited = true,
          onDelete: () {},
        ),
      );

      final decorated = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(EggCollectionCard),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect((decorated.decoration as BoxDecoration).color, AppColors.bgCard);
      final stripe = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byKey(const Key('egg-group-stripe')),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(stripe.color, eggConsumptionColor);
      expect(find.byKey(const Key('egg-date-footer')), findsOneWidget);
      expect(find.byType(CircleAvatar), findsOneWidget);
      expect(find.text('Buenos'), findsOneWidget);
      expect(find.text('Rotos'), findsOneWidget);

      await tester.tap(find.byKey(const Key('egg-record-menu')));
      await tester.pumpAndSettle();
      expect(find.text('Editar'), findsOneWidget);
      expect(find.text('Eliminar'), findsOneWidget);
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      expect(edited, isTrue);
    },
  );

  testWidgets(
    'sale card uses orange icon, green total, detail, and permissions',
    (tester) async {
      await _pump(tester, EggSaleCard(sale: _sale(), canEdit: false));

      final icon = tester.widget<Icon>(
        find.byIcon(Icons.point_of_sale_rounded),
      );
      expect(icon.color, AppColors.naranjal);
      final total = tester.widget<Text>(find.text(r'$12.00'));
      expect(total.style?.color, AppColors.green);
      expect(find.text(r'4 × $3.00'), findsOneWidget);
      expect(find.byKey(const Key('egg-record-menu')), findsNothing);
      expect(find.byKey(const Key('egg-group-stripe')), findsOneWidget);
      expect(find.byKey(const Key('egg-date-footer')), findsOneWidget);
    },
  );

  testWidgets(
    'summary renders metrics, destination, statistics, and activities',
    (tester) async {
      await _pump(
        tester,
        const EggSummaryView(
          summary: EggSummary(
            goodEggs: 20,
            brokenEggs: 2,
            soldEggs: 8,
            consumedEggs: 12,
            income: 24,
            averageSalePrice: 3,
            collectionCount: 2,
            saleCount: 1,
          ),
        ),
      );

      expect(find.byKey(const Key('egg-metric-eggs')), findsOneWidget);
      expect(find.byKey(const Key('egg-destination-card')), findsOneWidget);
      expect(find.byKey(const Key('egg-pie-chart')), findsOneWidget);
      expect(find.byKey(const Key('egg-average-sale-price')), findsOneWidget);
      expect(find.byKey(const Key('egg-break-even-strip')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Recolecciones'),
        300,
        scrollable: find.descendant(
          of: find.byKey(const Key('egg-summary-view')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('Recolecciones'), findsOneWidget);
      expect(find.text('Ventas'), findsOneWidget);
    },
  );

  testWidgets('forms discard an initial group not present in valid choices', (
    tester,
  ) async {
    await _pump(
      tester,
      EggCollectionForm(
        farmId: 'farm-1',
        groups: const [
          EggGroupChoice(
            id: 'group-1',
            name: 'Ponedoras',
            animalTypeId: 'type-1',
            animalTypeName: 'Gallinas',
          ),
        ],
        initialGroupId: 'invalid-group',
        onSave: (_) async {},
      ),
    );

    final field = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const Key('collection-group-field')),
    );
    expect(field.initialValue, isNull);
  });
}

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    ),
  );
}

EggCollection _collection() => EggCollection(
  id: 'collection-1',
  farmId: 'farm-1',
  groupId: 'group-1',
  date: DateTime(2026, 7, 20),
  goodEggs: 18,
  brokenEggs: 2,
  createdAt: DateTime(2026, 7, 20),
  groupName: 'Ponedoras',
  animalTypeId: 'type-1',
  animalTypeName: 'Gallinas',
  authorName: 'Ana Pérez',
);

EggSale _sale() => EggSale(
  id: 'sale-1',
  farmId: 'farm-1',
  groupId: 'group-1',
  date: DateTime(2026, 7, 21),
  quantity: 4,
  unitPrice: 3,
  createdAt: DateTime(2026, 7, 21),
  groupName: 'Ponedoras',
  animalTypeId: 'type-1',
  animalTypeName: 'Gallinas',
  authorName: 'Ana Pérez',
);
