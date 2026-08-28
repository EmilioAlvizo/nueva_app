import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rancho/core/testing/app_widget_keys.dart';
import 'package:rancho/features/animales/animales_provider.dart';
import 'package:rancho/features/ciclos/domain/cycle_models.dart';
import 'package:rancho/features/ciclos/domain/cycle_repository.dart';
import 'package:rancho/features/ciclos/domain/economics_v2_lifecycle_models.dart';
import 'package:rancho/features/ciclos/domain/economics_v2_lifecycle_repository.dart';
import 'package:rancho/features/ciclos/domain/economics_v2_models.dart';
import 'package:rancho/features/ciclos/domain/economics_v2_repository.dart';
import 'package:rancho/features/ciclos/presentation/providers/cycle_providers.dart';
import 'package:rancho/features/ciclos/presentation/screens/cycles_list_screen.dart';
import 'package:rancho/features/ciclos/presentation/widgets/economics_v2_lifecycle_panel.dart';
import 'package:rancho/features/comida/comida_models.dart';
import 'package:rancho/features/comida/comida_provider.dart';
import 'package:rancho/features/model/animal/animal.dart';
import 'package:rancho/features/model/catalogoItem/catalogo_item.dart';
import 'package:rancho/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets(
    'shows the localized empty V2 surface and confirms each lifecycle step only after V2 futures succeed',
    (tester) async {
      final lifecycle = _LifecycleRepository();
      final legacy = _RecordingLegacyCycleRepository();
      await _pump(tester, lifecycle, legacy);

      expect(find.byType(EconomicsV2LifecyclePanel), findsOneWidget);
      expect(
        find.byKey(const ValueKey(AppWidgetKeys.economicsV2LifecyclePanel)),
        findsOneWidget,
      );
      expect(find.text('Crear ciclo V2'), findsOneWidget);
      await _select(
        tester,
        AppWidgetKeys.economicsV2LifecyclePurpose,
        'Postura',
      );
      await _invoke(
        tester,
        AppWidgetKeys.economicsV2LifecycleCreate,
        lifecycle.createRequests,
        'Ciclo creado',
        () => lifecycle.create.complete(
          const EconomicsV2CycleCreated(cycleId: 'cycle-1'),
        ),
      );
      await _select(tester, AppWidgetKeys.economicsV2LifecycleAnimal, 'Ave 21');
      await _invoke(
        tester,
        AppWidgetKeys.economicsV2LifecycleAssignAnimal,
        lifecycle.assignRequests,
        'Animal asignado',
        () => lifecycle.assign.complete(
          const EconomicsV2AnimalAssigned(
            cycleId: 'cycle-1',
            animalId: 'animal-1',
          ),
        ),
      );
      await tester.enterText(
        find.byKey(
          const ValueKey(AppWidgetKeys.economicsV2LifecycleExpenseAmount),
        ),
        '24.50',
      );
      await _invoke(
        tester,
        AppWidgetKeys.economicsV2LifecycleRecordExpense,
        lifecycle.expenseRequests,
        'Gasto registrado',
        () => lifecycle.expense.complete(
          const EconomicsV2ExpenseRecorded(expenseId: 'expense-1'),
        ),
      );
      await tester.drag(find.byType(ListView), const Offset(0, -240));
      await tester.pump();
      await _select(
        tester,
        AppWidgetKeys.economicsV2LifecycleFeed,
        'Mezcla inicio',
      );
      await _invoke(
        tester,
        AppWidgetKeys.economicsV2LifecycleLinkFeed,
        lifecycle.feedRequests,
        'Alimento vinculado',
        () => lifecycle.feed.complete(
          const EconomicsV2FeedLinked(feedId: 'feed-1'),
        ),
      );
      expect(legacy.createCalls, 0);
    },
  );

  testWidgets(
    'retains the selected step without false success when PostgREST rejects it',
    (tester) async {
      final lifecycle = _LifecycleRepository()
        ..createError = PostgrestException(
          message: 'Farm access denied',
          code: '42501',
        );
      await _pump(tester, lifecycle, _RecordingLegacyCycleRepository());
      await _select(
        tester,
        AppWidgetKeys.economicsV2LifecyclePurpose,
        'Postura',
      );
      await tester.tap(
        find.byKey(const ValueKey(AppWidgetKeys.economicsV2LifecycleCreate)),
      );
      await tester.pump();
      expect(find.text('No se pudo completar el paso.'), findsOneWidget);
      expect(find.text('Ciclo creado'), findsNothing);
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(
              find.byKey(
                const ValueKey(AppWidgetKeys.economicsV2LifecyclePurpose),
              ),
            )
            .initialValue,
        'purpose-1',
      );
      expect(
        find.byKey(const ValueKey(AppWidgetKeys.economicsV2LifecycleCreate)),
        findsOneWidget,
      );
    },
  );
}

Future<void> _pump(
  WidgetTester tester,
  _LifecycleRepository lifecycle,
  _RecordingLegacyCycleRepository legacy,
) async {
  final container = ProviderContainer.test(
    overrides: [
      cycleRepositoryProvider.overrideWithValue(legacy),
      economicsV2RepositoryProvider.overrideWithValue(_EmptyV2Repository()),
      economicsV2LifecycleRepositoryProvider.overrideWithValue(lifecycle),
      propositosProvider('farm-1').overrideWith((_) async => _purposes),
      animalesProvider('farm-1').overrideWith((_) async => _animals),
      foodMixturesProvider('farm-1').overrideWith((_) async => _mixtures),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        locale: Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CyclesListScreen(farmId: 'farm-1'),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _select(WidgetTester tester, String key, String value) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pump();
  await tester.tap(find.text(value).last);
  await tester.pump();
}

Future<void> _invoke(
  WidgetTester tester,
  String key,
  List<dynamic> requests,
  String progress,
  void Function() complete,
) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pump();
  expect(requests, hasLength(1));
  expect(find.text(progress), findsNothing);
  complete();
  await tester.pump();
  expect(find.text(progress), findsOneWidget);
}

const _purposes = [CatalogoItem(id: 'purpose-1', nombre: 'Postura')];
final _animals = [
  Animal(
    id: 'animal-1',
    granjaId: 'farm-1',
    tipoAnimalId: 'type-1',
    fechaAdquisicion: DateTime(2026),
    activo: true,
    tipoNombre: 'Gallina',
    grupoNombre: 'Grupo A',
    brazalete: 21,
    propositoId: 'purpose-1',
  ),
];
final _mixtures = [
  FoodMixture(
    id: 'mixture-1',
    farmId: 'farm-1',
    groupId: 'group-1',
    groupName: 'Mezcla inicio',
    startDate: DateTime(2026),
    updatedAt: DateTime(2026),
    ingredients: const [],
  ),
];

final class _EmptyV2Repository extends Fake implements EconomicsV2Repository {
  @override
  Future<List<EconomicsV2Cycle>> getCycles(String farmId) async => const [];
}

final class _LifecycleRepository implements EconomicsV2LifecycleRepository {
  final create = Completer<EconomicsV2CycleCreated>(),
      assign = Completer<EconomicsV2AnimalAssigned>(),
      expense = Completer<EconomicsV2ExpenseRecorded>(),
      feed = Completer<EconomicsV2FeedLinked>();
  final createRequests = <EconomicsV2CreateCycleRequest>[],
      assignRequests = <EconomicsV2AssignAnimalRequest>[],
      expenseRequests = <EconomicsV2RecordExpenseRequest>[],
      feedRequests = <EconomicsV2LinkFeedRequest>[];
  Object? createError;
  Future<T> _record<T, R>(R request, List<R> requests, Completer<T> pending) {
    requests.add(request);
    return pending.future;
  }

  @override
  Future<EconomicsV2CycleCreated> createCycle(
    EconomicsV2CreateCycleRequest request,
  ) => createError == null
      ? _record(request, createRequests, create)
      : Future.error(createError!);
  @override
  Future<EconomicsV2AnimalAssigned> assignAnimal(
    EconomicsV2AssignAnimalRequest request,
  ) => _record(request, assignRequests, assign);
  @override
  Future<EconomicsV2ExpenseRecorded> recordExpense(
    EconomicsV2RecordExpenseRequest request,
  ) => _record(request, expenseRequests, expense);
  @override
  Future<EconomicsV2FeedLinked> linkFeed(EconomicsV2LinkFeedRequest request) =>
      _record(request, feedRequests, feed);
}

final class _RecordingLegacyCycleRepository extends Mock
    implements CycleRepository {
  var createCalls = 0;
  @override
  Future<Cycle> createCycle(CycleCreationInput input) {
    createCalls++;
    throw StateError('Legacy cycle creation must not be invoked.');
  }
}
