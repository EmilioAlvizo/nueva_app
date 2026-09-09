import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rancho/core/testing/app_widget_keys.dart';
import 'package:rancho/core/theme/app_theme.dart';
import 'package:rancho/core/theme/finance_theme.dart';
import 'package:rancho/features/animales/animales_provider.dart';
import 'package:rancho/features/ciclos/domain/cycle_models.dart';
import 'package:rancho/features/ciclos/domain/economics_v2_lifecycle_models.dart';
import 'package:rancho/features/ciclos/domain/economics_v2_lifecycle_repository.dart';
import 'package:rancho/features/ciclos/domain/economics_v2_models.dart';
import 'package:rancho/features/ciclos/domain/economics_v2_repository.dart';
import 'package:rancho/features/ciclos/presentation/providers/cycle_providers.dart';
import 'package:rancho/features/ciclos/presentation/screens/finance_cycles_section.dart';
import 'package:rancho/features/model/catalogoItem/catalogo_item.dart';
import 'package:rancho/l10n/app_localizations.dart';

void main() {
  testWidgets('does not start V2 reads when locally ineligible', (
    tester,
  ) async {
    final repository = _EconomicsRepository();
    await _pumpSection(tester, repository: repository, role: CycleRole.viewer);
    await _flush(tester);

    expect(_key(AppWidgetKeys.financeCyclesUnavailable), findsOneWidget);
    expect(repository.accessCalls, 0);
    expect(repository.summaryCalls, 0);
  });

  testWidgets('does not start V2 reads when the build flag is disabled', (
    tester,
  ) async {
    final repository = _EconomicsRepository();
    await _pumpSection(
      tester,
      repository: repository,
      role: CycleRole.owner,
      isFeatureEnabled: false,
    );
    await _flush(tester);

    expect(_key(AppWidgetKeys.financeCyclesUnavailable), findsOneWidget);
    expect(repository.accessCalls, 0);
    expect(repository.summaryCalls, 0);
  });

  testWidgets(
    'renders access error, disabled, loading, empty, and retry states',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final repository = _EconomicsRepository()
        ..accessError = Exception('offline');
      await _pumpSection(tester, repository: repository, role: CycleRole.owner);
      await _flush(tester);
      expect(_key(AppWidgetKeys.financeCyclesError), findsOneWidget);

      repository
        ..accessError = null
        ..access = const EconomicsV2FarmAccess(
          farmId: 'farm-1',
          enabled: false,
          role: 'owner',
          canEdit: true,
        );
      await tester.tap(_key(AppWidgetKeys.financeCyclesRetry));
      await _flush(tester);
      expect(_key(AppWidgetKeys.financeCyclesDisabled), findsOneWidget);
      expect(repository.summaryCalls, 0);

      repository.access = const EconomicsV2FarmAccess(
        farmId: 'farm-1',
        enabled: true,
        role: 'owner',
        canEdit: true,
      );
      repository.summaryCompleter = Completer<List<EconomicsV2CycleSummary>>();
      await tester.tap(_key(AppWidgetKeys.financeCyclesRetry));
      await _flush(tester);
      expect(_key(AppWidgetKeys.financeCyclesLoading), findsOneWidget);
      expect(find.bySemanticsLabel('Cargando ciclos'), findsOneWidget);

      repository.summaryCompleter!.complete(const []);
      await _flush(tester);
      expect(_key(AppWidgetKeys.financeCyclesEmpty), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets('renders real aggregate metrics and cycle summary fields', (
    tester,
  ) async {
    final repository = _EconomicsRepository()..summaries = [_summary];
    await _pumpSection(tester, repository: repository, role: CycleRole.editor);
    await _flush(tester);

    expect(find.text('Ciclos'), findsWidgets);
    expect(find.text('Postura'), findsOneWidget);
    expect(find.text('Abierto'), findsOneWidget);
    expect(find.textContaining('Gallinero norte'), findsOneWidget);
    expect(find.textContaining(r'$42.50'), findsWidgets);
    expect(find.textContaining('4'), findsWidgets);
    expect(find.textContaining('1'), findsWidgets);
    expect(_key(AppWidgetKeys.financeCycleSummary('cycle-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses semantic cycle surfaces, metrics, actions, and status', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _EconomicsRepository()..summaries = [_summary];
    await _pumpSection(tester, repository: repository, role: CycleRole.editor);
    await _flush(tester);

    final theme = FinanceTheme.of(
      tester.element(_key(AppWidgetKeys.financeCycleSummary('cycle-1'))),
    );
    final summary = tester.widget<Material>(
      find
          .descendant(
            of: _key(AppWidgetKeys.financeCycleSummary('cycle-1')),
            matching: find.byType(Material),
          )
          .first,
    );
    final addButton = tester.widget<FloatingActionButton>(
      _key(AppWidgetKeys.financeCyclesAdd),
    );

    expect(summary.color, theme.cycleSurface);
    expect(addButton.backgroundColor, theme.cyclePositiveAction);
    expect(find.text('Ciclos totales'), findsOneWidget);
    expect(find.text('Ciclos abiertos'), findsOneWidget);
    expect(find.text('Animales activos'), findsOneWidget);
    expect(find.text('Gastos directos'), findsWidgets);
    expect(find.text('Animales'), findsOneWidget);
    expect(find.text('Alimentos'), findsOneWidget);
    expect(find.text('Ver detalle'), findsOneWidget);
    expect(find.text('Abierto'), findsOneWidget);
    expect(
      tester.getSize(_key(AppWidgetKeys.financeCycleOpen('cycle-1'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(_key(AppWidgetKeys.financeCycleOpen('cycle-1'))).width,
      greaterThanOrEqualTo(326),
    );
  });

  testWidgets('adapts dashboard to compact width and larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _EconomicsRepository()..summaries = [_summary];

    await _pumpSection(
      tester,
      repository: repository,
      role: CycleRole.editor,
      textScaler: const TextScaler.linear(2),
    );
    await _flush(tester);

    expect(
      tester.getSize(_key(AppWidgetKeys.financeCyclesAdd)).height,
      greaterThanOrEqualTo(48),
    );
    final summary = _key(AppWidgetKeys.financeCycleSummary('cycle-1'));
    await tester.scrollUntilVisible(
      summary,
      300,
      scrollable: find.byType(Scrollable),
    );
    final theme = FinanceTheme.of(tester.element(summary));
    final canvas = tester.widget<ColoredBox>(
      find.ancestor(of: summary, matching: find.byType(ColoredBox)).first,
    );
    expect(canvas.color, theme.cycleCanvas);
    expect(summary, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('adapts creation form to compact width and larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpSection(
      tester,
      repository: _EconomicsRepository(),
      role: CycleRole.owner,
      textScaler: const TextScaler.linear(2),
    );
    await _flush(tester);
    await tester.scrollUntilVisible(
      _key(AppWidgetKeys.financeCyclesAdd),
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(_key(AppWidgetKeys.financeCyclesAdd));
    await _flush(tester);

    expect(_key(AppWidgetKeys.financeCycleForm), findsOneWidget);
    expect(
      tester.getSize(_key(AppWidgetKeys.financeCycleCreate)).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(_key(AppWidgetKeys.financeCycleCreate)).width,
      greaterThanOrEqualTo(358),
    );
    expect(
      tester.getSize(_key(AppWidgetKeys.financeCycleCancel)).width,
      greaterThanOrEqualTo(358),
    );
    final theme = FinanceTheme.of(
      tester.element(_key(AppWidgetKeys.financeCycleForm)),
    );
    final canvas = tester.widget<ColoredBox>(
      find
          .ancestor(
            of: _key(AppWidgetKeys.financeCycleForm),
            matching: find.byType(ColoredBox),
          )
          .first,
    );
    expect(canvas.color, theme.cycleCanvas);
    for (final key in [
      AppWidgetKeys.financeCyclePurpose,
      AppWidgetKeys.financeCycleStartDate,
      AppWidgetKeys.financeCycleEndDate,
    ]) {
      final surface = tester.widget<Material>(_key(key));
      expect(surface.color, theme.cycleInputSurface);
      expect(tester.getSize(_key(key)).height, greaterThanOrEqualTo(48));
    }
    final create = tester.widget<FilledButton>(
      find.descendant(
        of: _key(AppWidgetKeys.financeCycleCreate),
        matching: find.byType(FilledButton),
      ),
    );
    expect(
      create.style?.backgroundColor?.resolve(const {}),
      theme.cyclePrimaryAction,
    );
    expect(
      find.text('El ciclo se creará abierto y listo para registrar actividad.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the cycle workspace hierarchy and close action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _EconomicsRepository()..summaries = [_summary];
    await _pumpSection(tester, repository: repository, role: CycleRole.editor);
    await _flush(tester);
    await _openCycle(tester);

    final theme = FinanceTheme.of(
      tester.element(_key(AppWidgetKeys.financeCycleOverview)),
    );
    final canvas = tester.widget<ColoredBox>(
      find
          .ancestor(
            of: _key(AppWidgetKeys.financeCycleOverview),
            matching: find.byType(ColoredBox),
          )
          .first,
    );
    expect(canvas.color, theme.cycleCanvas);
    final overview = tester.widget<Material>(
      find
          .descendant(
            of: _key(AppWidgetKeys.financeCycleOverview),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(overview.color, theme.cycleSurface);
    expect(find.text('Todos los ciclos'), findsOneWidget);
    expect(find.text('Detalle del ciclo'), findsOneWidget);
    expect(
      _key(AppWidgetKeys.financeCycleWorkspaceContextIndicator),
      findsOneWidget,
    );
    expect(
      _key(AppWidgetKeys.financeCycleWorkspaceDetailContext),
      findsOneWidget,
    );
    expect(find.text('Postura · Gallinero norte'), findsOneWidget);
    expect(find.text('Abierto'), findsOneWidget);
    expect(find.text('20 ago 2026 → actual'), findsOneWidget);
    expect(find.text('Última actualización: 22 ago 2026'), findsOneWidget);
    expect(find.text('Animales'), findsWidgets);
    expect(find.text('Gastos'), findsOneWidget);
    expect(find.text('Mezcla'), findsOneWidget);
    expect(find.text('Proyección'), findsWidgets);
    expect(find.text('Alimentación'), findsOneWidget);
    expect(find.text('Gastos del ciclo'), findsOneWidget);
    expect(find.text('Resultado final'), findsOneWidget);
    final overviewMetricKeys = [
      AppWidgetKeys.financeCycleOverviewAnimalsMetric,
      AppWidgetKeys.financeCycleOverviewExpensesMetric,
      AppWidgetKeys.financeCycleOverviewFeedMetric,
      AppWidgetKeys.financeCycleOverviewProjectionMetric,
    ];
    final overviewMetricRects = [
      for (final key in overviewMetricKeys) tester.getRect(_key(key)),
    ];
    final metricTop = overviewMetricRects.first.top;
    for (final rect in overviewMetricRects.skip(1)) {
      expect(rect.top, closeTo(metricTop, 1));
    }
    for (final (index, rect) in overviewMetricRects.indexed.skip(1)) {
      expect(rect.left, greaterThan(overviewMetricRects[index - 1].left));
    }
    expect(
      find.descendant(
        of: _key(AppWidgetKeys.financeCycleOverview),
        matching: find.byType(Icon),
      ),
      findsNothing,
    );
    final titleRect = tester.getRect(
      _key(AppWidgetKeys.financeCycleWorkspaceTitle),
    );
    final statusRect = tester.getRect(_key(AppWidgetKeys.financeCycleStatus));
    final overviewRect = tester.getRect(
      _key(AppWidgetKeys.financeCycleOverview),
    );
    expect(statusRect.left, greaterThan(titleRect.left));
    expect(statusRect.right, closeTo(overviewRect.right, 1));
    expect(statusRect.center.dy, closeTo(titleRect.center.dy, 2));
    expect(
      tester.getSize(_key(AppWidgetKeys.financeCycleWorkspaceBack)).height,
      greaterThanOrEqualTo(48),
    );
    for (final key in [
      AppWidgetKeys.financeCycleAnimalsTab,
      AppWidgetKeys.financeCycleFeedsTab,
      AppWidgetKeys.financeCycleExpensesTab,
      AppWidgetKeys.financeCycleProjectionsTab,
      AppWidgetKeys.financeCycleCloseTab,
    ]) {
      final row = tester.widget<Material>(_key(key));
      expect(row.color, theme.cycleSurface);
      expect(tester.getSize(_key(key)).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(_key(key)).width, greaterThanOrEqualTo(326));
    }
    await tester.scrollUntilVisible(
      _key(AppWidgetKeys.financeCycleCloseAction),
      200,
    );
    final closeAction = tester.widget<FilledButton>(
      find.descendant(
        of: _key(AppWidgetKeys.financeCycleCloseAction),
        matching: find.byType(FilledButton),
      ),
    );
    expect(
      closeAction.style?.backgroundColor?.resolve(const {}),
      theme.cycleDestructiveAction,
    );
    expect(
      tester.getSize(_key(AppWidgetKeys.financeCycleCloseAction)).width,
      greaterThanOrEqualTo(326),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'uses semantic animal and feeding sections with full-width actions',
    (tester) async {
      tester.view.physicalSize = const Size(390, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _EconomicsRepository()..summaries = [_summary];
      await _pumpSection(
        tester,
        repository: repository,
        role: CycleRole.editor,
      );
      await _flush(tester);
      await _openCycle(tester);

      await _tapVisible(tester, AppWidgetKeys.financeCycleAnimalsTab);
      await _flush(tester);
      final animalsTheme = FinanceTheme.of(
        tester.element(_key(AppWidgetKeys.financeCycleAnimalsSummary)),
      );
      for (final key in [
        AppWidgetKeys.financeCycleAnimalsSummary,
        AppWidgetKeys.financeCycleAnimalsAssigned,
        AppWidgetKeys.financeCycleAnimalsAvailable,
      ]) {
        expect(_surfaceMaterial(tester, key).color, animalsTheme.cycleSurface);
      }
      expect(find.text('Asignados al ciclo'), findsOneWidget);
      expect(find.text('Disponibles para asignar'), findsOneWidget);
      expect(
        tester
            .getSize(_key(AppWidgetKeys.financeCycleAssignAnimal('animal-2')))
            .width,
        greaterThanOrEqualTo(326),
      );
      expect(
        tester
            .getSize(_key(AppWidgetKeys.financeCycleAssignAnimal('animal-2')))
            .height,
        greaterThanOrEqualTo(48),
      );

      await _tapVisible(tester, AppWidgetKeys.financeCycleFeedsTab);
      await _flush(tester);
      final feedsTheme = FinanceTheme.of(
        tester.element(_key(AppWidgetKeys.financeCycleFeedsSummary)),
      );
      for (final key in [
        AppWidgetKeys.financeCycleFeedsSummary,
        AppWidgetKeys.financeCycleFeedsLinked,
        AppWidgetKeys.financeCycleFeedsAvailable,
      ]) {
        expect(_surfaceMaterial(tester, key).color, feedsTheme.cycleSurface);
      }
      expect(find.text('Alimentación vinculada'), findsOneWidget);
      expect(find.text('Mezclas disponibles'), findsOneWidget);
      expect(
        tester
            .getSize(_key(AppWidgetKeys.financeCycleLinkFeed('mixture-2')))
            .width,
        greaterThanOrEqualTo(326),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'uses semantic expense and projection summaries with real metrics',
    (tester) async {
      tester.view.physicalSize = const Size(390, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _EconomicsRepository()..summaries = [_summary];
      await _pumpSection(
        tester,
        repository: repository,
        role: CycleRole.editor,
      );
      await _flush(tester);
      await _openCycle(tester);

      await _tapVisible(tester, AppWidgetKeys.financeCycleExpensesTab);
      await _flush(tester);
      final expensesTheme = FinanceTheme.of(
        tester.element(_key(AppWidgetKeys.financeCycleExpensesSummary)),
      );
      expect(
        _surfaceMaterial(
          tester,
          AppWidgetKeys.financeCycleExpensesSummary,
        ).color,
        expensesTheme.cycleSurface,
      );
      expect(
        _surfaceMaterial(tester, AppWidgetKeys.financeCycleExpensesList).color,
        expensesTheme.cycleSurface,
      );
      expect(find.text('Total registrado'), findsOneWidget);
      expect(find.textContaining(r'$42.50'), findsWidgets);
      expect(
        tester.getSize(_key(AppWidgetKeys.financeCycleExpenseAdd)).width,
        greaterThanOrEqualTo(326),
      );

      await _tapVisible(tester, AppWidgetKeys.financeCycleProjectionsTab);
      await _flush(tester);
      final projectionKey = AppWidgetKeys.financeCycleProjectionCard(
        'projection-1',
      );
      final projectionTheme = FinanceTheme.of(
        tester.element(_key(projectionKey)),
      );
      expect(
        _surfaceMaterial(tester, projectionKey).color,
        projectionTheme.cycleSurface,
      );
      expect(find.text('Ingresos proyectados'), findsOneWidget);
      expect(find.text('Costo proyectado'), findsOneWidget);
      expect(find.text('Saldo proyectado'), findsOneWidget);
      expect(find.textContaining(r'$1,970.00'), findsOneWidget);
      expect(
        tester.getSize(_key(AppWidgetKeys.financeCycleProjectionAdd)).width,
        greaterThanOrEqualTo(326),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('renders close readiness and the refreshed final result', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _EconomicsRepository()..summaries = [_summary];
    await _pumpSection(tester, repository: repository, role: CycleRole.owner);
    await _flush(tester);
    await _openCycle(tester);
    await _tapVisible(tester, AppWidgetKeys.financeCycleCloseTab);
    await _flush(tester);

    final theme = FinanceTheme.of(
      tester.element(_key(AppWidgetKeys.financeCycleCloseReadiness)),
    );
    expect(
      _surfaceMaterial(tester, AppWidgetKeys.financeCycleCloseReadiness).color,
      theme.cycleSurface,
    );
    expect(find.text('Requisitos de cierre'), findsOneWidget);
    expect(
      tester.getSize(_key(AppWidgetKeys.financeCycleCloseProduction)).width,
      greaterThanOrEqualTo(326),
    );
    final closeButton = tester.widget<FilledButton>(
      find.descendant(
        of: _key(AppWidgetKeys.financeCycleCloseProduction),
        matching: find.byType(FilledButton),
      ),
    );
    expect(
      closeButton.style?.backgroundColor?.resolve(const {}),
      theme.cycleDestructiveAction,
    );

    await _tapVisible(tester, AppWidgetKeys.financeCycleCloseProduction);
    await _flush(tester);
    await _tapVisible(tester, AppWidgetKeys.financeCycleFinalize);
    await _flush(tester);
    await _flush(tester);

    expect(_key(AppWidgetKeys.financeCycleFinalResult), findsOneWidget);
    expect(find.text('Resultado final'), findsOneWidget);
    expect(find.text('Ingresos'), findsOneWidget);
    expect(find.text('Costo total'), findsOneWidget);
    expect(find.textContaining(r'$37.50'), findsWidgets);
    expect(repository.detail.status, EconomicsV2CycleStatus.settled);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'opens every responsive workspace view with localized semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _EconomicsRepository()..summaries = [_summary];

      await _pumpSection(
        tester,
        repository: repository,
        role: CycleRole.editor,
        textScaler: const TextScaler.linear(2),
      );
      await _flush(tester);

      await tester.scrollUntilVisible(
        _key(AppWidgetKeys.financeCycleOpen('cycle-1')),
        200,
      );
      await tester.ensureVisible(
        _key(AppWidgetKeys.financeCycleOpen('cycle-1')),
      );
      await tester.pump();
      expect(find.bySemanticsLabel('Abrir ciclo Postura'), findsOneWidget);
      await _openCycle(tester);

      expect(_key(AppWidgetKeys.financeCycleWorkspace), findsOneWidget);
      expect(
        tester.getSize(_key(AppWidgetKeys.financeCycleWorkspaceBack)).height,
        greaterThanOrEqualTo(48),
      );
      await tester.drag(
        _key(AppWidgetKeys.financeCycleWorkspace),
        const Offset(0, -300),
      );
      await tester.pump();
      expect(_key(AppWidgetKeys.financeCycleOverview), findsOneWidget);
      expect(tester.takeException(), isNull);

      final destinations =
          <
            ({
              String tabKey,
              String viewKey,
              List<String> inspectionKeys,
              Set<String> actionKeys,
            })
          >[
            (
              tabKey: AppWidgetKeys.financeCycleAnimalsTab,
              viewKey: AppWidgetKeys.financeCycleAnimals,
              inspectionKeys: [
                AppWidgetKeys.financeCycleAssignAnimal('animal-2'),
              ],
              actionKeys: {AppWidgetKeys.financeCycleAssignAnimal('animal-2')},
            ),
            (
              tabKey: AppWidgetKeys.financeCycleFeedsTab,
              viewKey: AppWidgetKeys.financeCycleFeeds,
              inspectionKeys: [AppWidgetKeys.financeCycleLinkFeed('mixture-2')],
              actionKeys: {AppWidgetKeys.financeCycleLinkFeed('mixture-2')},
            ),
            (
              tabKey: AppWidgetKeys.financeCycleExpensesTab,
              viewKey: AppWidgetKeys.financeCycleExpenses,
              inspectionKeys: [
                AppWidgetKeys.financeCycleExpenseAdd,
                AppWidgetKeys.financeCycleExpensesList,
              ],
              actionKeys: {AppWidgetKeys.financeCycleExpenseAdd},
            ),
            (
              tabKey: AppWidgetKeys.financeCycleProjectionsTab,
              viewKey: AppWidgetKeys.financeCycleProjections,
              inspectionKeys: [
                AppWidgetKeys.financeCycleProjectionAdd,
                AppWidgetKeys.financeCycleProjectionCard('projection-1'),
              ],
              actionKeys: {AppWidgetKeys.financeCycleProjectionAdd},
            ),
            (
              tabKey: AppWidgetKeys.financeCycleCloseTab,
              viewKey: AppWidgetKeys.financeCycleClose,
              inspectionKeys: [AppWidgetKeys.financeCycleCloseProduction],
              actionKeys: {AppWidgetKeys.financeCycleCloseProduction},
            ),
          ];
      for (final destination in destinations) {
        await _tapWorkspaceDestination(tester, destination.tabKey);
        await tester.pump();
        expect(_key(destination.viewKey), findsOneWidget);
        for (final inspectionKey in destination.inspectionKeys) {
          await tester.scrollUntilVisible(
            _key(inspectionKey),
            240,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pump();
          if (destination.actionKeys.contains(inspectionKey)) {
            final size = tester.getSize(_key(inspectionKey));
            expect(size.height, greaterThanOrEqualTo(48));
            expect(size.width, greaterThanOrEqualTo(256));
          }
        }
        expect(tester.takeException(), isNull);
      }

      await _tapWorkspaceDestination(
        tester,
        AppWidgetKeys.financeCycleWorkspaceBack,
      );
      await tester.pump();
      expect(_key(AppWidgetKeys.financeCyclesAdd), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets(
    'marks compatibility mode and disables unsupported workspace destinations',
    (tester) async {
      final repository = _EconomicsRepository()
        ..summaries = [_summary]
        ..detail = _compatibilityDetail;
      await _pumpSection(
        tester,
        repository: repository,
        role: CycleRole.editor,
      );
      await _flush(tester);
      await _openCycle(tester);

      expect(
        _key(AppWidgetKeys.financeCycleCompatibilityNotice),
        findsOneWidget,
      );
      for (final key in [
        AppWidgetKeys.financeCycleAnimalsTab,
        AppWidgetKeys.financeCycleFeedsTab,
        AppWidgetKeys.financeCycleExpensesTab,
        AppWidgetKeys.financeCycleProjectionsTab,
        AppWidgetKeys.financeCycleCloseTab,
      ]) {
        final ink = tester.widget<InkWell>(
          find.descendant(of: _key(key), matching: find.byType(InkWell)),
        );
        expect(ink.onTap, isNull);
      }
      expect(repository.memberCalls, 0);
      expect(repository.feedCalls, 0);
      expect(repository.expenseCalls, 0);
      expect(repository.projectionCalls, 0);
      expect(repository.readinessCalls, 0);
    },
  );

  testWidgets('submits typed workspace actions and refreshes focused reads', (
    tester,
  ) async {
    final repository = _EconomicsRepository()..summaries = [_summary];
    final lifecycle = _LifecycleRepository();
    await _pumpSection(
      tester,
      repository: repository,
      lifecycle: lifecycle,
      role: CycleRole.editor,
    );
    await _flush(tester);
    await _openCycle(tester);

    await tester.tap(_key(AppWidgetKeys.financeCycleAnimalsTab));
    await _flush(tester);
    await _tapVisible(
      tester,
      AppWidgetKeys.financeCycleAssignAnimal('animal-2'),
    );
    await _flush(tester);
    await _flush(tester);
    expect(lifecycle.assignRequests.single.animalId, 'animal-2');
    expect(repository.memberCalls, 2);

    await _tapWorkspaceDestination(tester, AppWidgetKeys.financeCycleFeedsTab);
    await _flush(tester);
    await _tapVisible(tester, AppWidgetKeys.financeCycleLinkFeed('mixture-2'));
    await _flush(tester);
    await _flush(tester);
    expect(lifecycle.feedRequests.single.mixtureId, 'mixture-2');
    expect(repository.feedCalls, 2);

    await _tapWorkspaceDestination(
      tester,
      AppWidgetKeys.financeCycleExpensesTab,
    );
    await _flush(tester);
    await _tapVisible(tester, AppWidgetKeys.financeCycleExpenseAdd);
    await tester.pump();
    await tester.enterText(
      _key(AppWidgetKeys.financeCycleExpenseCategory),
      'Veterinaria',
    );
    await tester.enterText(
      _key(AppWidgetKeys.financeCycleExpenseAmount),
      '18.75',
    );
    await tester.enterText(
      _key(AppWidgetKeys.financeCycleExpenseNote),
      'Control rutinario',
    );
    await tester.tap(_key(AppWidgetKeys.financeCycleExpenseConfirm));
    await _flush(tester);
    await _flush(tester);
    expect(lifecycle.expenseRequests.single.amount, 18.75);
    expect(lifecycle.expenseRequests.single.category, 'Veterinaria');
    expect(repository.expenseCalls, 2);

    await _tapWorkspaceDestination(
      tester,
      AppWidgetKeys.financeCycleProjectionsTab,
    );
    await _flush(tester);
    await _tapVisible(tester, AppWidgetKeys.financeCycleProjectionAdd);
    await tester.pump();
    final projectionFields = <String, String>{
      AppWidgetKeys.financeCycleProjectionUnitPrice: '3.5',
      AppWidgetKeys.financeCycleProjectionProductionPerDay: '20',
      AppWidgetKeys.financeCycleProjectionFeedPerDay: '4',
      AppWidgetKeys.financeCycleProjectionOtherCosts: '10',
      AppWidgetKeys.financeCycleProjectionHorizonDays: '30',
      AppWidgetKeys.financeCycleProjectionNote: 'Escenario conservador',
    };
    for (final MapEntry(:key, :value) in projectionFields.entries) {
      await tester.enterText(_key(key), value);
    }
    await tester.tap(_key(AppWidgetKeys.financeCycleProjectionConfirm));
    await _flush(tester);
    await _flush(tester);
    expect(repository.savedProjectionInputs.single.expectedUnitPrice, 3.5);
    expect(repository.savedProjectionInputs.single.horizonDays, 30);
    expect(repository.projectionCalls, 2);
  });

  testWidgets('closes production before settling and refreshes readiness', (
    tester,
  ) async {
    final repository = _EconomicsRepository()..summaries = [_summary];
    await _pumpSection(tester, repository: repository, role: CycleRole.owner);
    await _flush(tester);
    await _openCycle(tester);
    await _tapVisible(tester, AppWidgetKeys.financeCycleCloseTab);
    await _flush(tester);

    expect(
      find.textContaining('La producción aún no se ha cerrado.'),
      findsOneWidget,
    );
    expect(find.textContaining('production_not_closed'), findsNothing);
    await _tapVisible(tester, AppWidgetKeys.financeCycleCloseProduction);
    await _flush(tester);
    expect(repository.closedOn, DateTime(2026, 8, 20));
    expect(repository.readinessCalls, 2);
    expect(_key(AppWidgetKeys.financeCycleFinalize), findsOneWidget);

    await _tapVisible(tester, AppWidgetKeys.financeCycleFinalize);
    await _flush(tester);
    expect(repository.finalizeCalls, 1);
    expect(repository.readinessCalls, 3);
  });

  testWidgets(
    'validates, cancels, and refreshes source of truth after create',
    (tester) async {
      final repository = _EconomicsRepository();
      final lifecycle = _LifecycleRepository(
        onCreate: () {
          repository.summaries = [_summary];
        },
      );
      await _pumpSection(
        tester,
        repository: repository,
        lifecycle: lifecycle,
        role: CycleRole.owner,
      );
      await _flush(tester);

      await tester.tap(_key(AppWidgetKeys.financeCyclesAdd));
      await _flush(tester);
      expect(_key(AppWidgetKeys.financeCycleForm), findsOneWidget);

      await tester.tap(_key(AppWidgetKeys.financeCycleCreate));
      await tester.pump();
      expect(_key(AppWidgetKeys.financeCycleValidation), findsOneWidget);

      await tester.tap(_key(AppWidgetKeys.financeCycleCancel));
      await tester.pump();
      expect(_key(AppWidgetKeys.financeCyclesEmpty), findsOneWidget);
      expect(lifecycle.requests, isEmpty);

      await tester.tap(_key(AppWidgetKeys.financeCyclesAdd));
      await tester.pump();
      await tester.tap(_key(AppWidgetKeys.financeCyclePurpose));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Postura').last);
      await tester.pumpAndSettle();

      await tester.tap(_key(AppWidgetKeys.financeCycleStartDate));
      await tester.pumpAndSettle();
      await tester.tap(find.text('20').last);
      await tester.tap(find.byType(TextButton).last);
      await tester.pumpAndSettle();

      await tester.tap(_key(AppWidgetKeys.financeCycleEndDate));
      await tester.pumpAndSettle();
      await tester.tap(find.text('25').last);
      await tester.tap(find.byType(TextButton).last);
      await tester.pumpAndSettle();

      await tester.tap(_key(AppWidgetKeys.financeCycleCreate));
      await tester.pump();
      expect(_key(AppWidgetKeys.financeCyclePending), findsOneWidget);
      expect(lifecycle.requests, hasLength(1));

      lifecycle.complete();
      await _flush(tester);
      await _flush(tester);

      expect(lifecycle.requests.single.startsOn, DateTime(2026, 8, 20));
      expect(lifecycle.requests.single.endsOn, DateTime(2026, 8, 25));
      expect(repository.summaryCalls, 2);
      expect(_key(AppWidgetKeys.financeCycleForm), findsNothing);
      await tester.ensureVisible(
        _key(AppWidgetKeys.financeCycleOpen('cycle-1')),
      );
      await tester.pump();
      expect(
        _key(AppWidgetKeys.financeCycleSummary('cycle-1')),
        findsOneWidget,
      );
    },
  );
}

Finder _key(String value) => find.byKey(ValueKey(value));

Material _surfaceMaterial(WidgetTester tester, String key) =>
    tester.widget<Material>(
      find.descendant(of: _key(key), matching: find.byType(Material)).first,
    );

Future<void> _openCycle(WidgetTester tester) async {
  await _tapVisible(tester, AppWidgetKeys.financeCycleOpen('cycle-1'));
  await _flush(tester);
}

Future<void> _tapVisible(WidgetTester tester, String key) async {
  await tester.ensureVisible(_key(key));
  await tester.pump();
  await tester.tap(_key(key));
}

Future<void> _tapWorkspaceDestination(WidgetTester tester, String key) async {
  await tester.scrollUntilVisible(
    _key(key),
    -300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
  await tester.tap(_key(key));
}

Future<void> _pumpSection(
  WidgetTester tester, {
  required _EconomicsRepository repository,
  required CycleRole role,
  _LifecycleRepository? lifecycle,
  bool isFeatureEnabled = true,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  final container = ProviderContainer.test(
    overrides: [
      economicsV2RepositoryProvider.overrideWithValue(repository),
      economicsV2LifecycleRepositoryProvider.overrideWithValue(
        lifecycle ?? _LifecycleRepository(),
      ),
      cycleAccessProvider(
        'farm-1',
      ).overrideWithValue(AsyncData(CycleAccess(role))),
      propositosProvider('farm-1').overrideWithValue(
        const AsyncData([CatalogoItem(id: 'purpose-1', nombre: 'Postura')]),
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
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: Scaffold(
          body: FinanceCyclesSection(
            farmId: 'farm-1',
            isFeatureEnabled: isFeatureEnabled,
            now: () => DateTime(2026, 8, 1),
          ),
        ),
      ),
    ),
  );
}

Future<void> _flush(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

final _summary = EconomicsV2CycleSummary(
  cycleId: 'cycle-1',
  farmId: 'farm-1',
  status: 'open',
  startsOn: DateTime(2026, 8, 20),
  purposeId: 'purpose-1',
  purposeName: 'Postura',
  activeAnimalCount: 4,
  exitedAnimalCount: 1,
  directExpenseTotal: 42.5,
  linkedMixtureCount: 2,
  latestLinkedGroupName: 'Gallinero norte',
);

final class _EconomicsRepository extends Fake implements EconomicsV2Repository {
  EconomicsV2FarmAccess access = const EconomicsV2FarmAccess(
    farmId: 'farm-1',
    enabled: true,
    role: 'owner',
    canEdit: true,
  );
  Object? accessError;
  EconomicsV2CycleDetail detail = _detail;
  List<EconomicsV2CycleSummary> summaries = const [];
  Completer<List<EconomicsV2CycleSummary>>? summaryCompleter;
  var accessCalls = 0;
  var summaryCalls = 0;
  var memberCalls = 0;
  var feedCalls = 0;
  var expenseCalls = 0;
  var projectionCalls = 0;
  var readinessCalls = 0;
  var finalizeCalls = 0;
  var productionClosed = false;
  var settled = false;
  DateTime? closedOn;
  final savedProjectionInputs = <EconomicsV2ProjectionInput>[];

  @override
  Future<EconomicsV2FarmAccess> getAccess(String farmId) async {
    accessCalls++;
    if (accessError case final error?) throw error;
    return access;
  }

  @override
  Future<List<EconomicsV2CycleSummary>> getCycleSummaries(String farmId) {
    summaryCalls++;
    return summaryCompleter?.future ?? Future.value(summaries);
  }

  @override
  Future<EconomicsV2CycleDetail> getCycleDetail({
    required String farmId,
    required String cycleId,
  }) async => detail;

  @override
  Future<EconomicsV2CycleMembers> getCycleMembers({
    required String farmId,
    required String cycleId,
  }) async {
    memberCalls++;
    return EconomicsV2CycleMembers(
      members: [
        EconomicsV2CycleMember(
          animalId: 'animal-1',
          label: 'Ave #101',
          groupNameSnapshot: 'Gallinero norte',
          joinedOn: _startsOn,
          isActive: true,
        ),
      ],
      candidates: const [
        EconomicsV2AnimalCandidate(
          animalId: 'animal-2',
          label: 'Ave #102',
          groupName: 'Gallinero norte',
        ),
      ],
    );
  }

  @override
  Future<EconomicsV2CycleFeeds> getCycleFeeds({
    required String farmId,
    required String cycleId,
  }) async {
    feedCalls++;
    return EconomicsV2CycleFeeds(
      intervals: [
        EconomicsV2FeedInterval(
          feedId: 'feed-1',
          mixtureId: 'mixture-1',
          mixtureLabel: 'Mezcla 20/08/2026',
          groupNameSnapshot: 'Gallinero norte',
          startsOn: _startsOn,
          cost: 20,
        ),
      ],
      candidates: const [
        EconomicsV2FeedCandidate(
          mixtureId: 'mixture-2',
          mixtureLabel: 'Mezcla 21/08/2026',
          groupName: 'Gallinero norte',
        ),
      ],
    );
  }

  @override
  Future<List<EconomicsV2CycleExpense>> getCycleExpenses({
    required String farmId,
    required String cycleId,
  }) async {
    expenseCalls++;
    return [
      EconomicsV2CycleExpense(
        expenseId: 'expense-1',
        occurredOn: _startsOn,
        amount: 42.5,
        category: 'Veterinaria',
        note: 'Control preventivo',
      ),
    ];
  }

  @override
  Future<List<EconomicsV2SavedProjection>> getCycleProjections({
    required String farmId,
    required String cycleId,
  }) async {
    projectionCalls++;
    return [
      EconomicsV2SavedProjection(
        projectionId: 'projection-1',
        createdAt: DateTime(2026, 8, 21),
        calculationVersion: 'v2',
        input: const EconomicsV2ProjectionInput(
          expectedUnitPrice: 3.5,
          productionPerDay: 20,
          feedPerDay: 4,
          otherCosts: 10,
          horizonDays: 30,
        ),
        result: const EconomicsV2ProjectionResult(
          expectedUnits: 600,
          projectedRevenue: 2100,
          projectedTotalCost: 130,
          projectedBalance: 1970,
        ),
      ),
    ];
  }

  @override
  Future<EconomicsV2CycleReadiness> getCycleReadiness({
    required String farmId,
    required String cycleId,
  }) async {
    readinessCalls++;
    return EconomicsV2CycleReadiness(
      cycleId: cycleId,
      status: settled
          ? EconomicsV2CycleStatus.settled
          : productionClosed
          ? EconomicsV2CycleStatus.productionClosed
          : EconomicsV2CycleStatus.open,
      canCloseProduction: !productionClosed && !settled,
      canSettle: productionClosed && !settled,
      hasMembers: true,
      hasFeed: true,
      hasSaleableOutput: true,
      salesWithinOutput: true,
      openFeedCount: 1,
      reasons: productionClosed
          ? const []
          : const [EconomicsV2ReadinessReason.productionNotClosed],
    );
  }

  @override
  Future<EconomicsV2SavedProjection> saveProjection({
    required String farmId,
    required String cycleId,
    required EconomicsV2ProjectionInput input,
    String? note,
  }) async {
    savedProjectionInputs.add(input);
    return EconomicsV2SavedProjection(
      projectionId: 'projection-2',
      createdAt: DateTime(2026, 8, 22),
      calculationVersion: 'v2',
      input: input,
      result: const EconomicsV2ProjectionResult(
        expectedUnits: 600,
        projectedRevenue: 2100,
        projectedTotalCost: 130,
        projectedBalance: 1970,
      ),
      note: note,
    );
  }

  @override
  Future<EconomicsV2CycleDetail> closeProduction(
    EconomicsV2CloseProductionRequest request,
  ) async {
    closedOn = request.closedOn;
    productionClosed = true;
    _updateDetailStatus(
      EconomicsV2CycleStatus.productionClosed,
      productionClosedOn: request.closedOn,
    );
    return detail;
  }

  @override
  Future<EconomicsV2Finalization> finalize({
    required String farmId,
    required String cycleId,
  }) async {
    finalizeCalls++;
    settled = true;
    _updateDetailStatus(
      EconomicsV2CycleStatus.settled,
      productionClosedOn: closedOn,
      settledOn: DateTime(2026, 8, 20),
    );
    return EconomicsV2Finalization(
      cycleId: cycleId,
      status: EconomicsV2CycleStatus.settled,
      calculationVersion: 'v2',
      settledOn: DateTime(2026, 8, 20),
      result: const EconomicsV2Calculation(
        cycleId: 'cycle-1',
        purpose: EconomicsV2Purpose.postura,
        productionBasis: 'eggs',
        totalCost: 62.5,
        revenue: 100,
        margin: 37.5,
      ),
    );
  }

  void _updateDetailStatus(
    EconomicsV2CycleStatus status, {
    DateTime? productionClosedOn,
    DateTime? settledOn,
  }) {
    final current = detail;
    detail = EconomicsV2CycleDetail(
      cycleId: current.cycleId,
      farmId: current.farmId,
      name: current.name,
      status: status,
      startsOn: current.startsOn,
      plannedEndsOn: current.plannedEndsOn,
      productionClosedOn: productionClosedOn,
      settledOn: settledOn,
      purposeId: current.purposeId,
      purposeName: current.purposeName,
      purpose: current.purpose,
      activeAnimalCount: current.activeAnimalCount,
      exitedAnimalCount: current.exitedAnimalCount,
      feedCost: current.feedCost,
      directExpenseTotal: current.directExpenseTotal,
      revenue: current.revenue,
      totalCost: current.totalCost,
      profit: current.profit,
      marginPercentage: current.marginPercentage,
      unitCost: current.unitCost,
      breakEven: current.breakEven,
      latestGroupNameSnapshot: current.latestGroupNameSnapshot,
      updatedAt: current.updatedAt,
    );
  }
}

final _startsOn = DateTime(2026, 8, 20);

final _detail = EconomicsV2CycleDetail(
  cycleId: 'cycle-1',
  farmId: 'farm-1',
  name: 'Ciclo de postura',
  status: EconomicsV2CycleStatus.open,
  startsOn: _startsOn,
  purposeId: 'purpose-1',
  purposeName: 'Postura',
  purpose: EconomicsV2Purpose.postura,
  activeAnimalCount: 4,
  exitedAnimalCount: 1,
  feedCost: 20,
  directExpenseTotal: 42.5,
  revenue: 100,
  totalCost: 62.5,
  profit: 37.5,
  marginPercentage: 37.5,
  unitCost: 3.125,
  latestGroupNameSnapshot: 'Gallinero norte',
  updatedAt: DateTime(2026, 8, 22),
);

final _compatibilityDetail = EconomicsV2CycleDetail(
  cycleId: 'cycle-1',
  farmId: 'farm-1',
  name: null,
  status: EconomicsV2CycleStatus.productionClosed,
  startsOn: _startsOn,
  productionClosedOn: DateTime(2026, 8, 22),
  purposeId: 'purpose-1',
  purposeName: 'Postura',
  purpose: EconomicsV2Purpose.postura,
  activeAnimalCount: 4,
  exitedAnimalCount: 1,
  feedCost: 20,
  directExpenseTotal: 42.5,
  revenue: 100,
  totalCost: 62.5,
  profit: 37.5,
  marginPercentage: 37.5,
  unitCost: 3.125,
  latestGroupNameSnapshot: 'Gallinero norte',
  updatedAt: null,
  isCompatibilityMode: true,
);

final class _LifecycleRepository extends Fake
    implements EconomicsV2LifecycleRepository {
  _LifecycleRepository({this.onCreate});

  final VoidCallback? onCreate;
  final requests = <EconomicsV2CreateCycleRequest>[];
  final assignRequests = <EconomicsV2AssignAnimalRequest>[];
  final feedRequests = <EconomicsV2LinkFeedRequest>[];
  final expenseRequests = <EconomicsV2RecordExpenseRequest>[];
  final _completer = Completer<EconomicsV2CycleCreated>();

  @override
  Future<EconomicsV2CycleCreated> createCycle(
    EconomicsV2CreateCycleRequest request,
  ) {
    requests.add(request);
    onCreate?.call();
    return _completer.future;
  }

  @override
  Future<EconomicsV2AnimalAssigned> assignAnimal(
    EconomicsV2AssignAnimalRequest request,
  ) async {
    assignRequests.add(request);
    return EconomicsV2AnimalAssigned(
      cycleId: request.cycleId,
      animalId: request.animalId,
    );
  }

  @override
  Future<EconomicsV2FeedLinked> linkFeed(
    EconomicsV2LinkFeedRequest request,
  ) async {
    feedRequests.add(request);
    return const EconomicsV2FeedLinked(feedId: 'feed-2');
  }

  @override
  Future<EconomicsV2ExpenseRecorded> recordExpense(
    EconomicsV2RecordExpenseRequest request,
  ) async {
    expenseRequests.add(request);
    return const EconomicsV2ExpenseRecorded(expenseId: 'expense-2');
  }

  void complete() {
    _completer.complete(const EconomicsV2CycleCreated(cycleId: 'cycle-1'));
  }
}
