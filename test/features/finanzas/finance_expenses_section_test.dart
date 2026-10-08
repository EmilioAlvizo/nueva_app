import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rancho/core/testing/app_widget_keys.dart';
import 'package:rancho/core/theme/app_theme.dart';
import 'package:rancho/features/finanzas/domain/repositories/finances_repository.dart';
import 'package:rancho/features/finanzas/domain/entities/finance_expense.dart';
import 'package:rancho/features/finanzas/presentation/providers/finances_providers.dart';
import 'package:rancho/features/finanzas/presentation/screens/finance_expenses_screen_section.dart';
import 'package:rancho/features/finanzas/presentation/widgets/finance_expenses_section.dart';
import 'package:rancho/l10n/app_localizations.dart';

void main() {
  testWidgets('dashboard remains usable at 320dp and 2x text scale', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    var edits = 0;
    var deletes = 0;

    await tester.pumpWidget(
      _app(
        ExpensesDashboard(
          snapshot: _snapshot,
          today: DateTime(2026, 9, 25),
          busy: false,
          onRefresh: () async {},
          onAdd: () {},
          onEdit: (_) => edits++,
          onDelete: (_) => deletes++,
        ),
        textScaler: const TextScaler.linear(2),
      ),
    );

    expect(find.text(r'$42.50'), findsNWidgets(3));
    expect(find.text('1'), findsOneWidget);
    final card = find.byKey(
      ValueKey(AppWidgetKeys.financeExpenseCard('expense-1')),
    );
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.longPress(card);

    expect(edits, 1);
    expect(deletes, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('edit form keeps the target immutable and validates amount', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        FinanceExpenseForm(
          targets: _targets,
          today: DateTime(2026, 9, 25),
          expense: _expense,
        ),
      ),
    );

    final dropdown = tester
        .widget<DropdownButtonFormField<FinanceExpenseTarget>>(
          find.byKey(const ValueKey(AppWidgetKeys.financeExpenseTarget)),
        );
    expect(dropdown.onChanged, isNull);

    await tester.enterText(
      find.byKey(const ValueKey(AppWidgetKeys.financeExpenseAmount)),
      '0',
    );
    await tester.tap(
      find.byKey(const ValueKey(AppWidgetKeys.financeExpenseSubmit)),
    );
    await tester.pump();

    expect(find.text('Ingresa un monto mayor que cero.'), findsOneWidget);
  });

  testWidgets('opens the add form and submits through the screen boundary', (
    tester,
  ) async {
    final repository = _ExpenseFlowRepository();
    await _pumpExpensesScreen(tester, repository);

    await tester.tap(
      find.byKey(const ValueKey(AppWidgetKeys.financeExpensesAdd)),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey(AppWidgetKeys.financeExpenseForm)),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey(AppWidgetKeys.financeExpenseAmount)),
      '18.75',
    );
    await tester.enterText(
      find.byKey(const ValueKey(AppWidgetKeys.financeExpenseCategory)),
      'Alimento',
    );
    await tester.enterText(
      find.byKey(const ValueKey(AppWidgetKeys.financeExpenseNote)),
      'Compra urgente',
    );
    final submit = find.byKey(
      const ValueKey(AppWidgetKeys.financeExpenseSubmit),
    );
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(repository.createdDrafts, hasLength(1));
    final draft = repository.createdDrafts.single;
    expect(draft.targetKind, FinanceExpenseTargetKind.cycle);
    expect(draft.targetId, 'cycle-1');
    expect(draft.amount, 18.75);
    expect(draft.category, 'Alimento');
    expect(draft.note, 'Compra urgente');
    expect(repository.expenseReads, 2);
    expect(
      find.byKey(const ValueKey(AppWidgetKeys.financeExpenseForm)),
      findsNothing,
    );
  });

  testWidgets('long-press delete supports cancel and confirm', (tester) async {
    final repository = _ExpenseFlowRepository();
    await _pumpExpensesScreen(tester, repository);
    final card = find.byKey(
      ValueKey(AppWidgetKeys.financeExpenseCard(_expense.id)),
    );
    await tester.ensureVisible(card);

    await tester.longPress(card);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey(AppWidgetKeys.financeExpenseDeleteDialog)),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey(AppWidgetKeys.financeExpenseDeleteCancel)),
    );
    await tester.pumpAndSettle();
    expect(repository.deletedExpenses, isEmpty);

    await tester.longPress(card);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey(AppWidgetKeys.financeExpenseDeleteConfirm)),
    );
    await tester.pumpAndSettle();

    expect(repository.deletedExpenses, [same(_expense)]);
    expect(repository.expenseReads, 2);
    expect(
      find.byKey(const ValueKey(AppWidgetKeys.financeExpenseDeleteDialog)),
      findsNothing,
    );
  });
}

Widget _app(Widget child, {TextScaler textScaler = TextScaler.noScaling}) =>
    MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      builder: (context, widget) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: widget!,
      ),
      home: Scaffold(body: child),
    );

Future<void> _pumpExpensesScreen(
  WidgetTester tester,
  FinancesRepository repository,
) async {
  final container = ProviderContainer.test(
    overrides: [financesRepositoryProvider.overrideWithValue(repository)],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: _app(const FinanceExpensesScreenSection(farmId: 'farm-1')),
    ),
  );
  await tester.pump();
  await tester.pump();
}

final class _ExpenseFlowRepository extends Fake implements FinancesRepository {
  var expenseReads = 0;
  final createdDrafts = <FinanceExpenseDraft>[];
  final deletedExpenses = <FinanceExpense>[];

  @override
  Future<FinanceExpensesSnapshot> getExpenses(String farmId) async {
    expenseReads++;
    return _snapshot;
  }

  @override
  Future<void> createExpense(String farmId, FinanceExpenseDraft draft) async {
    createdDrafts.add(draft);
  }

  @override
  Future<void> deleteExpense(String farmId, FinanceExpense expense) async {
    deletedExpenses.add(expense);
  }
}

final _targets = [
  FinanceExpenseTarget(
    kind: FinanceExpenseTargetKind.cycle,
    id: 'cycle-1',
    label: 'Engorde norte',
    startsOn: DateTime(2026, 9),
    endsOnExclusive: DateTime(2026, 10),
  ),
  FinanceExpenseTarget(
    kind: FinanceExpenseTargetKind.legacyMixture,
    id: 'mixture-1',
    label: 'Gallinero',
    startsOn: DateTime(2026, 9),
    endsOnExclusive: null,
  ),
];

final _expense = FinanceExpense(
  id: 'expense-1',
  targetKind: FinanceExpenseTargetKind.cycle,
  targetId: 'cycle-1',
  targetLabel: 'Engorde norte',
  occurredOn: DateTime(2026, 9, 20),
  amount: 42.5,
  category: 'Veterinaria',
  note: 'Control sanitario',
  createdAt: DateTime(2026, 9, 20, 10),
  updatedAt: DateTime(2026, 9, 20, 10),
  canMutate: true,
);

final _snapshot = FinanceExpensesSnapshot(
  farmId: 'farm-1',
  role: 'editor',
  canEdit: true,
  targets: _targets,
  expenses: [_expense],
);
