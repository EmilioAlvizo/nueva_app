import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rancho/core/testing/app_widget_keys.dart';
import 'package:rancho/core/theme/app_theme.dart';
import 'package:rancho/core/theme/finance_theme.dart';
import 'package:rancho/features/ciclos/domain/cycle_models.dart';
import 'package:rancho/features/ciclos/domain/economics_v2_models.dart';
import 'package:rancho/features/ciclos/domain/economics_v2_repository.dart';
import 'package:rancho/features/ciclos/presentation/providers/cycle_providers.dart';
import 'package:rancho/features/finanzas/data/models/break_even_point_model.dart';
import 'package:rancho/features/finanzas/domain/entities/break_even_point.dart';
import 'package:rancho/features/finanzas/domain/repositories/finances_repository.dart';
import 'package:rancho/features/finanzas/presentation/providers/finances_providers.dart';
import 'package:rancho/features/finanzas/presentation/screens/finances_screen.dart';
import 'package:rancho/features/finanzas/presentation/widgets/finance_tab_bar.dart';
import 'package:rancho/features/finanzas/presentation/widgets/meat_break_even_card.dart';
import 'package:rancho/l10n/app_localizations.dart';

void main() {
  testWidgets('horizontal swipes navigate all five tabs and back', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await _pumpScreen(
      tester,
      repository: _ValueRepository(const []),
      textScale: 1.5,
    );
    await _flushAsync(tester);

    expect(find.text('Equilibrio'), findsOneWidget);
    expect(find.text('Ingresos'), findsOneWidget);
    expect(find.text('Gastos'), findsOneWidget);
    expect(find.text('Gráficos'), findsOneWidget);
    expect(find.text('Ciclos'), findsOneWidget);
    _expectFinanceTabSelected(tester, AppWidgetKeys.financeBalanceTab);
    expect(_key(AppWidgetKeys.financeEmpty), findsOneWidget);

    await tester.drag(_key(AppWidgetKeys.financePages), const Offset(-250, 0));
    await tester.pumpAndSettle();
    _expectFinanceTabSelected(tester, AppWidgetKeys.financeIncomeTab);
    expect(_key(AppWidgetKeys.financeIncomeUnavailable), findsOneWidget);

    await tester.drag(_key(AppWidgetKeys.financePages), const Offset(-250, 0));
    await tester.pumpAndSettle();
    _expectFinanceTabSelected(tester, AppWidgetKeys.financeExpensesTab);
    expect(_key(AppWidgetKeys.financeExpensesUnavailable), findsOneWidget);

    await tester.drag(_key(AppWidgetKeys.financePages), const Offset(-250, 0));
    await tester.pumpAndSettle();
    _expectFinanceTabSelected(tester, AppWidgetKeys.financeChartsTab);
    expect(_key(AppWidgetKeys.financeChartsUnavailable), findsOneWidget);
    expect(
      find.text('No se muestran estimaciones ni datos financieros inventados.'),
      findsOneWidget,
    );

    await tester.drag(_key(AppWidgetKeys.financePages), const Offset(-250, 0));
    await tester.pumpAndSettle();
    _expectFinanceTabSelected(tester, AppWidgetKeys.financeCyclesTab);
    expect(_key(AppWidgetKeys.financeCyclesEmpty), findsOneWidget);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    final finance = FinanceTheme.of(
      tester.element(_key(AppWidgetKeys.financeCyclesEmpty)),
    );
    expect(scaffold.backgroundColor, finance.cycleCanvas);

    await tester.drag(_key(AppWidgetKeys.financePages), const Offset(250, 0));
    await tester.pumpAndSettle();
    _expectFinanceTabSelected(tester, AppWidgetKeys.financeChartsTab);
    expect(_key(AppWidgetKeys.financeChartsUnavailable), findsOneWidget);

    await tester.drag(_key(AppWidgetKeys.financePages), const Offset(250, 0));
    await tester.pumpAndSettle();
    _expectFinanceTabSelected(tester, AppWidgetKeys.financeExpensesTab);
    expect(_key(AppWidgetKeys.financeExpensesUnavailable), findsOneWidget);

    await tester.drag(_key(AppWidgetKeys.financePages), const Offset(250, 0));
    await tester.pumpAndSettle();
    _expectFinanceTabSelected(tester, AppWidgetKeys.financeIncomeTab);
    expect(_key(AppWidgetKeys.financeIncomeUnavailable), findsOneWidget);

    await tester.drag(_key(AppWidgetKeys.financePages), const Offset(250, 0));
    await tester.pumpAndSettle();
    _expectFinanceTabSelected(tester, AppWidgetKeys.financeBalanceTab);
    expect(_key(AppWidgetKeys.financeEmpty), findsOneWidget);
  });

  testWidgets('tab taps stay synchronized with horizontal swipes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await _pumpScreen(
      tester,
      repository: _ValueRepository(const []),
      textScale: 1.5,
    );
    await _flushAsync(tester);

    await tester.ensureVisible(_key(AppWidgetKeys.financeExpensesTab));
    await tester.tap(_key(AppWidgetKeys.financeExpensesTab));
    await tester.pumpAndSettle();
    _expectFinanceTabSelected(tester, AppWidgetKeys.financeExpensesTab);
    expect(_key(AppWidgetKeys.financeExpensesUnavailable), findsOneWidget);

    await tester.drag(_key(AppWidgetKeys.financePages), const Offset(250, 0));
    await tester.pumpAndSettle();
    _expectFinanceTabSelected(tester, AppWidgetKeys.financeIncomeTab);
    expect(_key(AppWidgetKeys.financeIncomeUnavailable), findsOneWidget);

    await tester.ensureVisible(_key(AppWidgetKeys.financeChartsTab));
    await tester.tap(_key(AppWidgetKeys.financeChartsTab));
    await tester.pumpAndSettle();
    _expectFinanceTabSelected(tester, AppWidgetKeys.financeChartsTab);
    expect(_key(AppWidgetKeys.financeChartsUnavailable), findsOneWidget);

    await tester.ensureVisible(_key(AppWidgetKeys.financeCyclesTab));
    await tester.tap(_key(AppWidgetKeys.financeCyclesTab));
    await tester.pumpAndSettle();
    _expectFinanceTabSelected(tester, AppWidgetKeys.financeCyclesTab);
    expect(_key(AppWidgetKeys.financeCyclesEmpty), findsOneWidget);

    await tester.drag(_key(AppWidgetKeys.financePages), const Offset(250, 0));
    await tester.pumpAndSettle();
    _expectFinanceTabSelected(tester, AppWidgetKeys.financeChartsTab);

    await tester.ensureVisible(_key(AppWidgetKeys.financeBalanceTab));
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

  testWidgets('keeps legacy balance while V2 entry is hidden by default', (
    tester,
  ) async {
    await _pumpScreen(tester, repository: _ValueRepository([_point]));
    await _flushAsync(tester);

    expect(
      _key(AppWidgetKeys.financeBreakEvenCard(_point.mixtureId)),
      findsOneWidget,
    );
    expect(_key(AppWidgetKeys.financeEconomicsV2Entry), findsNothing);
    expect(find.bySemanticsLabel('Abrir ciclos de producción'), findsNothing);
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

  testWidgets('renders unavailable per-bird metrics as dashes', (tester) async {
    await _pumpScreen(
      tester,
      repository: const _NullablePerBirdMetricsRepository(),
    );
    await _flushAsync(tester);

    expect(
      find.text('0.00 aves • - huevo/(día·ave) • - kg/(día·ave)'),
      findsOneWidget,
    );
    expect(_key(AppWidgetKeys.financeError), findsNothing);
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

  testWidgets('renders meat-only balance from one bulk summary request', (
    tester,
  ) async {
    final economics = _ControlledEconomicsRepository(
      summaries: [_meatSummary, _summary, _meatSummaryWithoutMetrics],
    );
    await _pumpScreen(
      tester,
      repository: _ValueRepository(const []),
      economicsRepository: economics,
    );
    await _flushAsync(tester);

    expect(
      _key(AppWidgetKeys.financeMeatBreakEvenCard(_meatSummary.cycleId)),
      findsOneWidget,
    );
    expect(find.byType(MeatBreakEvenCard), findsOneWidget);
    expect(_key(AppWidgetKeys.financeEmpty), findsNothing);
    expect(find.text('Engorda · Corral sur'), findsOneWidget);
    expect(
      find.text('Resultado económico acumulado del ciclo'),
      findsOneWidget,
    );
    expect(find.text('Punto de equilibrio'), findsWidgets);
    expect(find.text(r'-$18.75'), findsOneWidget);
    expect(find.text(r'$325'), findsOneWidget);
    expect(find.text(r'$200'), findsOneWidget);
    expect(find.text(r'$125'), findsOneWidget);
    expect(find.text(r'$250'), findsOneWidget);
    expect(
      find.text('4 animales • 2 ventas • 10 kg de alimento'),
      findsOneWidget,
    );
    expect(find.text('20 ago 2026 → 20 sept 2026 · 32 días'), findsOneWidget);
    expect(economics.accessCalls, 1);
    expect(economics.summaryCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders meat before the unchanged egg grid', (tester) async {
    final economics = _ControlledEconomicsRepository(summaries: [_meatSummary]);
    await _pumpScreen(
      tester,
      repository: _ValueRepository([_point]),
      economicsRepository: economics,
    );
    await _flushAsync(tester);

    final meat = _key(
      AppWidgetKeys.financeMeatBreakEvenCard(_meatSummary.cycleId),
    );
    final egg = _key(AppWidgetKeys.financeBreakEvenCard(_point.mixtureId));
    expect(meat, findsOneWidget);
    expect(egg, findsOneWidget);
    expect(tester.getTopLeft(meat).dy, lessThan(tester.getTopLeft(egg).dy));
  });

  testWidgets('keeps valid egg cards when the V2 summary request fails', (
    tester,
  ) async {
    final economics = _ControlledEconomicsRepository(
      summaryError: Exception('offline'),
    );
    await _pumpScreen(
      tester,
      repository: _ValueRepository([_point]),
      economicsRepository: economics,
    );
    await _flushAsync(tester);

    expect(
      _key(AppWidgetKeys.financeBreakEvenCard(_point.mixtureId)),
      findsOneWidget,
    );
    expect(find.byType(MeatBreakEvenCard), findsNothing);
    expect(_key(AppWidgetKeys.financeError), findsNothing);
    expect(economics.summaryCalls, 1);
  });

  testWidgets('keeps valid egg cards when the V2 access request fails', (
    tester,
  ) async {
    final economics = _ControlledEconomicsRepository(
      accessError: Exception('access unavailable'),
      summaries: [_meatSummary],
    );
    await _pumpScreen(
      tester,
      repository: _ValueRepository([_point]),
      economicsRepository: economics,
    );
    await _flushAsync(tester);

    expect(
      _key(AppWidgetKeys.financeBreakEvenCard(_point.mixtureId)),
      findsOneWidget,
    );
    expect(find.byType(MeatBreakEvenCard), findsNothing);
    expect(_key(AppWidgetKeys.financeError), findsNothing);
    expect(economics.accessCalls, 1);
    expect(economics.summaryCalls, 0);
  });

  testWidgets('does not request summaries for a viewer', (tester) async {
    final economics = _ControlledEconomicsRepository(
      access: const EconomicsV2FarmAccess(
        farmId: 'farm-1',
        enabled: true,
        role: 'viewer',
        canEdit: false,
      ),
      summaries: [_meatSummary],
    );
    await _pumpScreen(
      tester,
      repository: _ValueRepository([_point]),
      economicsRepository: economics,
    );
    await _flushAsync(tester);

    expect(economics.accessCalls, 1);
    expect(economics.summaryCalls, 0);
    expect(find.byType(MeatBreakEvenCard), findsNothing);
  });

  testWidgets('refreshes and awaits egg and eligible meat sources', (
    tester,
  ) async {
    final finances = _CountingValueRepository([_point]);
    final economics = _ControlledEconomicsRepository(summaries: [_meatSummary]);
    await _pumpScreen(
      tester,
      repository: finances,
      economicsRepository: economics,
    );
    await _flushAsync(tester);

    final indicator = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    await indicator.onRefresh();
    await _flushAsync(tester);

    expect(finances.calls, 2);
    expect(economics.summaryCalls, 2);
    expect(
      _key(AppWidgetKeys.financeMeatBreakEvenCard(_meatSummary.cycleId)),
      findsOneWidget,
    );
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
  EconomicsV2Repository? economicsRepository,
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) async {
  final container = ProviderContainer.test(
    overrides: [
      financesRepositoryProvider.overrideWithValue(repository),
      cycleAccessProvider(
        'farm-1',
      ).overrideWithValue(const AsyncData(CycleAccess(CycleRole.viewer))),
      economicsV2RepositoryProvider.overrideWithValue(
        economicsRepository ?? _ViewerEconomicsRepository(),
      ),
    ],
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
  await tester.pump();
  await tester.pump();
}

final class _ViewerEconomicsRepository extends Fake
    implements EconomicsV2Repository {
  @override
  Future<EconomicsV2FarmAccess> getAccess(String farmId) async =>
      EconomicsV2FarmAccess(
        farmId: farmId,
        enabled: true,
        role: 'viewer',
        canEdit: false,
      );

  @override
  Future<List<EconomicsV2CycleSummary>> getCycleSummaries(
    String farmId,
  ) async => const [];
}

final class _ControlledEconomicsRepository extends Fake
    implements EconomicsV2Repository {
  _ControlledEconomicsRepository({
    this.access = const EconomicsV2FarmAccess(
      farmId: 'farm-1',
      enabled: true,
      role: 'owner',
      canEdit: true,
    ),
    this.summaries = const [],
    this.accessError,
    this.summaryError,
  });

  final EconomicsV2FarmAccess access;
  final List<EconomicsV2CycleSummary> summaries;
  final Object? accessError;
  final Object? summaryError;
  var accessCalls = 0;
  var summaryCalls = 0;

  @override
  Future<EconomicsV2FarmAccess> getAccess(String farmId) async {
    accessCalls++;
    if (accessError case final error?) throw error;
    return access;
  }

  @override
  Future<List<EconomicsV2CycleSummary>> getCycleSummaries(String farmId) async {
    summaryCalls++;
    if (summaryError case final error?) throw error;
    return summaries;
  }
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

final _summary = EconomicsV2CycleSummary(
  cycleId: 'cycle-egg',
  farmId: 'farm-1',
  status: 'open',
  startsOn: DateTime(2026, 8, 20),
  purposeId: 'purpose-egg',
  purposeName: 'Postura',
  purpose: EconomicsV2Purpose.postura,
  activeAnimalCount: 4,
  exitedAnimalCount: 0,
  directExpenseTotal: 25,
  linkedMixtureCount: 1,
  latestLinkedGroupName: 'Gallinero',
);

final _meatSummaryWithoutMetrics = EconomicsV2CycleSummary(
  cycleId: 'cycle-meat-incomplete',
  farmId: 'farm-1',
  status: 'open',
  startsOn: DateTime(2026, 8, 20),
  purposeId: 'purpose-meat',
  purposeName: 'Carne',
  purpose: EconomicsV2Purpose.carne,
  activeAnimalCount: 4,
  exitedAnimalCount: 0,
  directExpenseTotal: 25,
  linkedMixtureCount: 1,
);

final _meatSummary = EconomicsV2CycleSummary(
  cycleId: 'cycle-meat',
  farmId: 'farm-1',
  status: 'production_closed',
  startsOn: DateTime(2026, 8, 20),
  endsOn: DateTime(2026, 9, 21),
  productionClosedOn: DateTime(2026, 9, 20),
  purposeId: 'purpose-meat',
  purposeName: 'Carne',
  purpose: EconomicsV2Purpose.carne,
  activeAnimalCount: 2,
  exitedAnimalCount: 2,
  directExpenseTotal: 25,
  linkedMixtureCount: 2,
  latestLinkedGroupName: 'Corral sur',
  meatMetrics: const EconomicsV2MeatCycleMetrics(
    animalCount: 4,
    feedCost: 200,
    feedKgTotal: 10,
    acquisitionCost: 100,
    totalCost: 325,
    animalSaleRevenue: 250,
    saleCount: 2,
    soldAnimalCount: 4,
    profit: -75,
    balancePerAnimal: -18.75,
  ),
);

final class _ValueRepository implements FinancesRepository {
  const _ValueRepository(this.value);

  final List<BreakEvenPoint> value;

  @override
  Future<List<BreakEvenPoint>> getBreakEvenPoints(String farmId) async => value;
}

final class _CountingValueRepository implements FinancesRepository {
  _CountingValueRepository(this.value);

  final List<BreakEvenPoint> value;
  var calls = 0;

  @override
  Future<List<BreakEvenPoint>> getBreakEvenPoints(String farmId) async {
    calls++;
    return value;
  }
}

final class _NullablePerBirdMetricsRepository implements FinancesRepository {
  const _NullablePerBirdMetricsRepository();

  @override
  Future<List<BreakEvenPoint>> getBreakEvenPoints(String farmId) async => [
    BreakEvenPointModel.fromJson(_nullablePerBirdMetricsJson).toEntity(),
  ];
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

final _nullablePerBirdMetricsJson = <String, Object?>{
  'fecha_inicio': '2026-07-01',
  'fecha_termino': null,
  'mezcla_id': '416e648e-1dd2-4a2f-8246-e42bcc6f36cb',
  'grupo_nombre': 'Gallinero',
  'buenos': 97,
  'rotos': 2,
  'total_costo_comidas': 800,
  'punto_de_equilibrio': 8.2474,
  'granja_id': '48b129e9-a48b-438a-a401-96d4dd863da5',
  'grupo_id': '7428302e-9d3b-4967-9baa-4747c98778bc',
  'fecha_fin_calculada': '2026-07-26',
  'dias_mezcla': 26,
  'consumo_total': 80,
  'aves_promedio_ponderado': 0,
  'huevos_por_dia': 3.7308,
  'huevos_por_dia_ave': null,
  'consumo_por_dia': 3.0769,
  'consumo_por_dia_ave': null,
  'precio_venta_promedio': 5,
  'margen_porcentaje': -39.37,
};
