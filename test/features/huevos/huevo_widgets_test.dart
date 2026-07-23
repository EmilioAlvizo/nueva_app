import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nueva_app/core/theme/app_colors.dart';
import 'package:nueva_app/core/theme/app_theme.dart';
import 'package:nueva_app/features/huevos/huevo_cards.dart';
import 'package:nueva_app/features/huevos/huevo_forms.dart';
import 'package:nueva_app/features/huevos/huevo_models.dart';
import 'package:nueva_app/features/huevos/huevo_summary.dart';

void main() {
  testWidgets(
    'collection card matches the collection reference and menu behavior',
    (tester) async {
      var edited = false;
      var deleted = false;
      await _pump(
        tester,
        EggCollectionCard(
          collection: _collection(),
          canEdit: true,
          onEdit: () => edited = true,
          onDelete: () => deleted = true,
        ),
      );

      final surface = tester.widget<DecoratedBox>(
        find.byKey(const Key('egg-collection-surface')),
      );
      final decoration = surface.decoration as BoxDecoration;
      expect(decoration.color, isNotNull);
      expect(decoration.border, isNull);
      expect(find.byIcon(Icons.egg_outlined), findsOneWidget);
      expect(find.byKey(const Key('egg-record-icon')), findsNothing);
      expect(find.text('Recolección'), findsOneWidget);
      expect(find.text('Ponedoras'), findsOneWidget);
      expect(find.text('Gallinas'), findsOneWidget);
      expect(find.text('18'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Buenos'), findsOneWidget);
      expect(find.text('Rotos'), findsOneWidget);

      final brokenValue = tester.widget<Text>(
        find.byKey(const Key('egg-broken-value')),
      );
      final cardContext = tester.element(find.byType(EggCollectionCard));
      expect(brokenValue.style?.color, Theme.of(cardContext).colorScheme.error);

      final author = tester.widget<Text>(
        find.byKey(const Key('egg-collection-author')),
      );
      final authorSpan = author.textSpan! as TextSpan;
      expect(authorSpan.text, 'Registrado por ');
      expect(authorSpan.children, hasLength(1));
      final nameSpan = authorSpan.children!.single as TextSpan;
      expect(nameSpan.text, 'Ana Pérez');
      expect(nameSpan.style?.fontWeight, FontWeight.w800);

      expect(find.byKey(const Key('egg-date-footer')), findsOneWidget);
      expect(find.text('20 de julio 2026'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today_outlined), findsNothing);
      expect(find.byType(CircleAvatar), findsOneWidget);
      final footer = tester.widget<Container>(
        find.byKey(const Key('egg-date-footer')),
      );
      final date = tester.widget<Text>(
        find.byKey(const Key('egg-collection-date')),
      );
      final animalLabel = tester.widget<RotatedBox>(
        find.ancestor(
          of: find.byKey(const Key('egg-animal-type-label')),
          matching: find.byType(RotatedBox),
        ),
      );
      expect(footer.alignment, Alignment.center);
      expect(date.textAlign, TextAlign.center);
      expect(animalLabel.quarterTurns, 3);

      final cardRect = tester.getRect(
        find.byKey(const ValueKey('egg-collection-collection-1')),
      );
      final stripeRect = tester.getRect(
        find.byKey(const Key('egg-group-stripe')),
      );
      final footerRect = tester.getRect(
        find.byKey(const Key('egg-date-footer')),
      );
      expect(stripeRect.width, 36);
      expect(stripeRect.right, closeTo(cardRect.right, 0.01));
      expect(stripeRect.top, closeTo(cardRect.top, 0.01));
      expect(stripeRect.bottom, closeTo(cardRect.bottom, 0.01));
      expect(footerRect.right, closeTo(stripeRect.left, 0.01));

      final menuRect = tester.getRect(find.byKey(const Key('egg-record-menu')));
      expect(menuRect.width, greaterThanOrEqualTo(48));
      expect(menuRect.height, greaterThanOrEqualTo(48));

      await tester.tap(find.byKey(const Key('egg-record-menu')));
      await tester.pumpAndSettle();
      expect(find.text('Editar'), findsOneWidget);
      expect(find.text('Eliminar'), findsOneWidget);
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      expect(edited, isTrue);

      await tester.tap(find.byKey(const Key('egg-record-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      expect(deleted, isTrue);
    },
  );

  testWidgets(
    'collection card hides menu and does not overflow at narrow width',
    (tester) async {
      await _pump(
        tester,
        SizedBox(
          width: 288,
          child: EggCollectionCard(
            collection: _collection(
              groupName: 'Gallinero de ponedoras del sector norte',
              animalTypeName: 'Gallina ponedora',
              authorName: 'Ana María Pérez Rodríguez',
            ),
            canEdit: false,
          ),
        ),
        theme: AppTheme.light,
      );

      expect(find.byKey(const Key('egg-record-menu')), findsNothing);
      expect(find.byKey(const Key('egg-animal-type-stripe')), findsOneWidget);
      expect(find.byKey(const Key('egg-animal-type-label')), findsOneWidget);
      expect(find.byKey(const Key('egg-collection-group')), findsOneWidget);
      expect(find.byKey(const Key('egg-collection-author')), findsOneWidget);
      expect(tester.takeException(), isNull);
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

Future<void> _pump(WidgetTester tester, Widget child, {ThemeData? theme}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.dark,
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    ),
  );
}

EggCollection _collection({
  String groupName = 'Ponedoras',
  String animalTypeName = 'Gallinas',
  String authorName = 'Ana Pérez',
}) => EggCollection(
  id: 'collection-1',
  farmId: 'farm-1',
  groupId: 'group-1',
  date: DateTime(2026, 7, 20),
  goodEggs: 18,
  brokenEggs: 2,
  createdAt: DateTime(2026, 7, 20),
  groupName: groupName,
  animalTypeId: 'type-1',
  animalTypeName: animalTypeName,
  authorName: authorName,
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
