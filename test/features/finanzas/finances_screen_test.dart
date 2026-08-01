import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nueva_app/core/testing/app_widget_keys.dart';
import 'package:nueva_app/core/theme/app_theme.dart';
import 'package:nueva_app/features/finanzas/domain/entities/break_even_point.dart';
import 'package:nueva_app/features/finanzas/domain/repositories/finances_repository.dart';
import 'package:nueva_app/features/finanzas/presentation/providers/finances_providers.dart';
import 'package:nueva_app/features/finanzas/presentation/screens/finances_screen.dart';
import 'package:nueva_app/features/finanzas/presentation/widgets/finance_tab_bar.dart';
import 'package:nueva_app/l10n/app_localizations.dart';

void main() {
  testWidgets('horizontal swipes navigate all four tabs and back', (
    tester,
  ) async {
    await _pumpScreen(tester, repository: _ValueRepository(const []));
    await _flushAsync(tester);

    expect(find.text('Equilibrio'), findsOneWidget);
    expect(find.text('Ingresos'), findsOneWidget);
    expect(find.text('Gastos'), findsOneWidget);
    expect(find.text('Gráficos'), findsOneWidget);
    _expectFinanceTabSelected(tester, AppWidgetKeys.financeBalanceTab);
    expect(_key(AppWidgetKeys.financeEmpty), findsOneWidget);

    await tester.drag(_key(AppWidgetKeys.financePages), const Offset(-600, 0));
    await tester.pumpAndSettle();
    _expectFinanceTabSelected(tester, AppWidgetKeys.financeIncomeTab);
    expect(_key(AppWidgetKeys.financeIncomeUnavailable), findsOneWidget);

    await tester.drag(_key(AppWidgetKeys.financePages), const Offset(-600, 0));
    await tester.pumpAndSettle();
    _expectFinanceTabSelected(tester, AppWidgetKeys.financeExpensesTab);
    expect(_key(AppWidgetKeys.financeExpensesUnavailable), findsOneWidget);

    await tester.drag(_key(AppWidgetKeys.financePages), const Offset(-600, 0));
    await tester.pumpAndSettle();
    _expectFinanceTabSelected(tester, AppWidgetKeys.financeChartsTab);
    expect(_key(AppWidgetKeys.financeChartsUnavailable), findsOneWidget);
    expect(
      find.text('No se muestran estimaciones ni datos financieros inventados.'),
      findsOneWidget,
    );

    await tester.drag(_key(AppWidgetKeys.financePages), const Offset(600, 0));
    await tester.pumpAndSettle();
    _expectFinanceTabSelected(tester, AppWidgetKeys.financeExpensesTab);
    expect(_key(AppWidgetKeys.financeExpensesUnavailable), findsOneWidget);

    await tester.drag(_key(AppWidgetKeys.financePages), const Offset(600, 0));
    await tester.pumpAndSettle();
    _expectFinanceTabSelected(tester, AppWidgetKeys.financeIncomeTab);
    expect(_key(AppWidgetKeys.financeIncomeUnavailable), findsOneWidget);

    await tester.drag(_key(AppWidgetKeys.financePages), const Offset(600, 0));
    await tester.pumpAndSettle();
    _expectFinanceTabSelected(tester, AppWidgetKeys.financeBalanceTab);
    expect(_key(AppWidgetKeys.financeEmpty), findsOneWidget);
  });

  testWidgets('tab taps stay synchronized with horizontal swipes', (
    tester,
  ) async {
    await _pumpScreen(tester, repository: _ValueRepository(const []));
    await _flushAsync(tester);

    await tester.tap(_key(AppWidgetKeys.financeExpensesTab));
    await tester.pumpAndSettle();
    _expectFinanceTabSelected(tester, AppWidgetKeys.financeExpensesTab);
    expect(_key(AppWidgetKeys.financeExpensesUnavailable), findsOneWidget);

    await tester.drag(_key(AppWidgetKeys.financePages), const Offset(600, 0));
    await tester.pumpAndSettle();
    _expectFinanceTabSelected(tester, AppWidgetKeys.financeIncomeTab);
    expect(_key(AppWidgetKeys.financeIncomeUnavailable), findsOneWidget);

    await tester.tap(_key(AppWidgetKeys.financeChartsTab));
    await tester.pumpAndSettle();
    _expectFinanceTabSelected(tester, AppWidgetKeys.financeChartsTab);
    expect(_key(AppWidgetKeys.financeChartsUnavailable), findsOneWidget);

    await tester.tap(_key(AppWidgetKeys.financeBalanceTab));
    await tester.pumpAndSettle();
    _expectFinanceTabSelected(tester, AppWidgetKeys.financeBalanceTab);
    expect(_key(AppWidgetKeys.financeEmpty), findsOneWidget);
  });

  testWidgets('tab animation follows the page and retargets midway', (
    tester,
  ) async {
    await _pumpScreen(tester, repository: _ValueRepository(const []));
    await _flushAsync(tester);

    await tester.tap(_key(AppWidgetKeys.financeChartsTab));
    await tester.pump();
    _expectFinanceTabSelected(tester, AppWidgetKeys.financeBalanceTab);
    expect(_pagePosition(tester, AppWidgetKeys.financePages), 0);

    await tester.pump(const Duration(milliseconds: 50));
    _expectFinanceTabSelected(tester, AppWidgetKeys.financeIncomeTab);
    expect(
      _pagePosition(tester, AppWidgetKeys.financePages),
      inInclusiveRange(0.5, 1.5),
    );

    await tester.tap(_key(AppWidgetKeys.financeIncomeTab));
    await tester.pumpAndSettle();
    _expectFinanceTabSelected(tester, AppWidgetKeys.financeIncomeTab);
    expect(
      _pagePosition(tester, AppWidgetKeys.financePages),
      closeTo(1, 0.001),
    );
    expect(_key(AppWidgetKeys.financeIncomeUnavailable), findsOneWidget);
  });

  testWidgets('shows a loading state while break-even data is pending', (
    tester,
  ) async {
    final repository = _PendingRepository();
    await _pumpScreen(tester, repository: repository);
    await tester.pump();

    expect(_key(AppWidgetKeys.financeLoading), findsOneWidget);
    repository.complete(const []);
  });

  testWidgets('shows a retryable error and reloads the query', (tester) async {
    final repository = _FailOnceRepository();
    await _pumpScreen(tester, repository: repository);
    await _flushAsync(tester);

    expect(_key(AppWidgetKeys.financeError), findsOneWidget);
    await tester.tap(_key(AppWidgetKeys.financeRetry));
    await _flushAsync(tester);

    expect(repository.calls, 2);
    expect(_key(AppWidgetKeys.financeEmpty), findsOneWidget);
  });

  testWidgets('shows the break-even empty state', (tester) async {
    await _pumpScreen(tester, repository: _ValueRepository(const []));
    await _flushAsync(tester);

    expect(_key(AppWidgetKeys.financeEmpty), findsOneWidget);
    expect(find.text('Aún no hay datos de equilibrio'), findsOneWidget);
  });

  testWidgets('renders view-backed cards in the light theme', (tester) async {
    await _pumpScreen(tester, repository: _ValueRepository([_point]));
    await _flushAsync(tester);

    expect(
      _key(AppWidgetKeys.financeBreakEvenCard(_point.mixtureId)),
      findsOneWidget,
    );
    expect(find.text('Gallinero'), findsOneWidget);
    expect(find.textContaining('3.32'), findsOneWidget);
    expect(find.textContaining('610.00'), findsOneWidget);
    expect(find.text('Huevos buenos'), findsOneWidget);
    expect(find.text('184'), findsOneWidget);
    expect(find.text('Consumo total'), findsOneWidget);
    expect(find.text('80 kg'), findsOneWidget);
    expect(
      find.text('15.00 aves • 0.19 huevo/(día·ave) • 0.08 kg/(día·ave)'),
      findsOneWidget,
    );
    expect(find.text('Aves promedio ponderado'), findsNothing);
    expect(find.text('Huevos por día'), findsNothing);
    expect(find.text('Huevos por día por ave'), findsNothing);
    expect(find.text('Consumo por día'), findsNothing);
    expect(find.text('Consumo por día por ave'), findsNothing);
    expect(find.text('Precio promedio de venta'), findsNothing);
    expect(find.text('2.88'), findsNothing);
    expect(find.text('1.25 kg'), findsNothing);
    expect(find.text(r'$5.00'), findsNothing);
    expect(find.text('Huevos rotos'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders without overflow at 288dp in the dark theme', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(288, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await _pumpScreen(
      tester,
      repository: _ValueRepository([_point]),
      brightness: Brightness.dark,
      textScale: 1.5,
    );
    await _flushAsync(tester);

    expect(
      _key(AppWidgetKeys.financeBreakEvenCard(_point.mixtureId)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Finder _key(String value) => find.byKey(ValueKey(value));

double _pagePosition(WidgetTester tester, String keyValue) {
  return tester.widget<PageView>(_key(keyValue)).controller!.page!;
}

void _expectFinanceTabSelected(WidgetTester tester, String keyValue) {
  final button = tester.widget<FinanceTabButton>(
    find.ancestor(of: _key(keyValue), matching: find.byType(FinanceTabButton)),
  );
  expect(button.selected, isTrue);
}

Future<ProviderContainer> _pumpScreen(
  WidgetTester tester, {
  required FinancesRepository repository,
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) async {
  final container = ProviderContainer.test(
    overrides: [financesRepositoryProvider.overrideWithValue(repository)],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const FinancesScreen(farmId: 'farm-1'),
      ),
    ),
  );
  return container;
}

Future<void> _flushAsync(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

final _point = BreakEvenPoint(
  farmId: '48b129e9-a48b-438a-a401-96d4dd863da5',
  groupId: '7428302e-9d3b-4967-9baa-4747c98778bc',
  startedAt: DateTime(2023, 12, 11),
  endedAt: DateTime(2024, 2, 12),
  calculatedEndAt: DateTime(2024, 2, 12),
  mixtureId: '97eb3256-1dd0-42cf-91d0-7d5b84e23b62',
  groupName: 'Gallinero',
  mixtureDays: 64,
  goodEggs: 184,
  brokenEggs: 0,
  totalFoodCost: 610,
  totalFeedConsumption: 80,
  weightedAverageBirds: 15,
  eggsPerDay: 2.875,
  eggsPerDayPerBird: 0.1917,
  feedPerDay: 1.25,
  feedPerDayPerBird: 0.0833,
  breakEvenPrice: 3.3152173913043478,
  averageSalePrice: 5,
  marginPercentage: 50.82,
);

final class _ValueRepository implements FinancesRepository {
  const _ValueRepository(this.value);

  final List<BreakEvenPoint> value;

  @override
  Future<List<BreakEvenPoint>> getBreakEvenPoints(String farmId) async => value;
}

final class _PendingRepository implements FinancesRepository {
  final _completer = Completer<List<BreakEvenPoint>>();

  void complete(List<BreakEvenPoint> value) => _completer.complete(value);

  @override
  Future<List<BreakEvenPoint>> getBreakEvenPoints(String farmId) {
    return _completer.future;
  }
}

final class _FailOnceRepository implements FinancesRepository {
  int calls = 0;

  @override
  Future<List<BreakEvenPoint>> getBreakEvenPoints(String farmId) async {
    calls++;
    if (calls == 1) throw Exception('offline');
    return const [];
  }
}
