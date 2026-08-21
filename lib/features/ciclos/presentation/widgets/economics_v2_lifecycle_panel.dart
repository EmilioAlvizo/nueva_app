import 'package:flutter/material.dart';

import '../../../../core/extensions/localization_extension.dart';
import '../../../../core/testing/app_widget_keys.dart';
import '../../../model/animal/animal.dart';
import '../../../comida/comida_models.dart';
import '../../../model/catalogoItem/catalogo_item.dart';
import '../../domain/economics_v2_lifecycle_models.dart';

class EconomicsV2LifecyclePanel extends StatefulWidget {
  const EconomicsV2LifecyclePanel({
    required this.farmId,
    required this.purposes,
    required this.animals,
    required this.mixtures,
    required this.onCreate,
    required this.onAssignAnimal,
    required this.onRecordExpense,
    required this.onLinkFeed,
    super.key,
  });

  final String farmId;
  final List<CatalogoItem> purposes;
  final List<Animal> animals;
  final List<FoodMixture> mixtures;
  final Future<EconomicsV2CycleCreated> Function(
    EconomicsV2CreateCycleRequest request,
  )
  onCreate;
  final Future<EconomicsV2AnimalAssigned> Function(
    EconomicsV2AssignAnimalRequest request,
  )
  onAssignAnimal;
  final Future<EconomicsV2ExpenseRecorded> Function(
    EconomicsV2RecordExpenseRequest request,
  )
  onRecordExpense;
  final Future<EconomicsV2FeedLinked> Function(
    EconomicsV2LinkFeedRequest request,
  )
  onLinkFeed;

  @override
  State<EconomicsV2LifecyclePanel> createState() =>
      _EconomicsV2LifecyclePanelState();
}

class _EconomicsV2LifecyclePanelState extends State<EconomicsV2LifecyclePanel> {
  final _expenseController = TextEditingController();
  String? _purposeId;
  String? _cycleId;
  String? _animalId;
  String? _mixtureId;
  var _assigned = false;
  var _expenseRecorded = false;
  var _feedLinked = false;
  var _submitting = false;
  String? _failure;

  List<Animal> get _eligibleAnimals => [
    for (final animal in widget.animals)
      if (animal.granjaId == widget.farmId &&
          animal.activo &&
          animal.propositoId == _purposeId)
        animal,
  ];

  @override
  void dispose() {
    _expenseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final today = DateUtils.dateOnly(DateTime.now());

    return Card(
      key: const ValueKey(AppWidgetKeys.economicsV2LifecyclePanel),
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.economicsV2LifecycleTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const ValueKey(AppWidgetKeys.economicsV2LifecyclePurpose),
              initialValue: _purposeId,
              decoration: InputDecoration(
                labelText: l10n.economicsV2LifecyclePurpose,
              ),
              items: [
                for (final purpose in widget.purposes)
                  DropdownMenuItem(
                    value: purpose.id,
                    child: Text(purpose.nombre),
                  ),
              ],
              onChanged: _submitting
                  ? null
                  : (value) => setState(() {
                      _purposeId = value;
                      _animalId = null;
                    }),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey(AppWidgetKeys.economicsV2LifecycleCreate),
              onPressed: _purposeId == null || _submitting
                  ? null
                  : () => _create(today),
              child: Text(l10n.economicsV2LifecycleCreate),
            ),
            if (_cycleId != null) ...[
              const SizedBox(height: 8),
              Text(l10n.economicsV2LifecycleCreated),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const ValueKey(AppWidgetKeys.economicsV2LifecycleAnimal),
                initialValue: _animalId,
                decoration: InputDecoration(
                  labelText: l10n.economicsV2LifecycleAnimal,
                ),
                items: [
                  for (final animal in _eligibleAnimals)
                    DropdownMenuItem(
                      value: animal.id,
                      child: Text('Ave ${animal.brazalete ?? animal.id}'),
                    ),
                ],
                onChanged: _submitting
                    ? null
                    : (value) => setState(() => _animalId = value),
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const ValueKey(
                  AppWidgetKeys.economicsV2LifecycleAssignAnimal,
                ),
                onPressed: _animalId == null || _submitting
                    ? null
                    : () => _assignAnimal(today),
                child: Text(l10n.economicsV2LifecycleAssignAnimal),
              ),
            ],
            if (_assigned) ...[
              const SizedBox(height: 8),
              Text(l10n.economicsV2LifecycleAnimalAssigned),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey(
                  AppWidgetKeys.economicsV2LifecycleExpenseAmount,
                ),
                controller: _expenseController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l10n.economicsV2LifecycleExpense,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const ValueKey(
                  AppWidgetKeys.economicsV2LifecycleRecordExpense,
                ),
                onPressed: _submitting ? null : () => _recordExpense(today),
                child: Text(l10n.economicsV2LifecycleRecordExpense),
              ),
            ],
            if (_expenseRecorded) ...[
              const SizedBox(height: 8),
              Text(l10n.economicsV2LifecycleExpenseRecorded),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const ValueKey(AppWidgetKeys.economicsV2LifecycleFeed),
                initialValue: _mixtureId,
                decoration: InputDecoration(
                  labelText: l10n.economicsV2LifecycleFeed,
                ),
                items: [
                  for (final mixture in widget.mixtures)
                    DropdownMenuItem(
                      value: mixture.id,
                      child: Text(mixture.groupName),
                    ),
                ],
                onChanged: _submitting
                    ? null
                    : (value) => setState(() => _mixtureId = value),
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const ValueKey(AppWidgetKeys.economicsV2LifecycleLinkFeed),
                onPressed: _mixtureId == null || _submitting
                    ? null
                    : () => _linkFeed(today),
                child: Text(l10n.economicsV2LifecycleLinkFeed),
              ),
            ],
            if (_feedLinked) ...[
              const SizedBox(height: 8),
              Text(l10n.economicsV2LifecycleFeedLinked),
            ],
            if (_failure != null) ...[
              const SizedBox(height: 12),
              Text(
                _failure!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _create(DateTime today) async {
    final purposeId = _purposeId;
    if (purposeId == null) return;
    await _submit(() async {
      final result = await widget.onCreate(
        EconomicsV2CreateCycleRequest(
          farmId: widget.farmId,
          purposeId: purposeId,
          startsOn: today,
        ),
      );
      _cycleId = result.cycleId;
    });
  }

  Future<void> _assignAnimal(DateTime today) async {
    final cycleId = _cycleId;
    final animalId = _animalId;
    if (cycleId == null || animalId == null) return;
    await _submit(() async {
      await widget.onAssignAnimal(
        EconomicsV2AssignAnimalRequest(
          farmId: widget.farmId,
          cycleId: cycleId,
          animalId: animalId,
          joinedOn: today,
        ),
      );
      _assigned = true;
    });
  }

  Future<void> _recordExpense(DateTime today) async {
    final cycleId = _cycleId;
    final amount = double.tryParse(_expenseController.text);
    if (cycleId == null || amount == null || amount < 0) {
      setState(
        () => _failure = context.l10n.economicsV2LifecycleInvalidExpense,
      );
      return;
    }
    await _submit(() async {
      await widget.onRecordExpense(
        EconomicsV2RecordExpenseRequest(
          farmId: widget.farmId,
          cycleId: cycleId,
          occurredOn: today,
          amount: amount,
        ),
      );
      _expenseRecorded = true;
    });
  }

  Future<void> _linkFeed(DateTime today) async {
    final cycleId = _cycleId;
    final mixtureId = _mixtureId;
    if (cycleId == null || mixtureId == null) return;
    await _submit(() async {
      await widget.onLinkFeed(
        EconomicsV2LinkFeedRequest(
          farmId: widget.farmId,
          cycleId: cycleId,
          mixtureId: mixtureId,
          startsOn: today,
        ),
      );
      _feedLinked = true;
    });
  }

  Future<void> _submit(Future<void> Function() operation) async {
    setState(() {
      _submitting = true;
      _failure = null;
    });
    try {
      await operation();
      if (!mounted) return;
      setState(() => _submitting = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _failure = context.l10n.economicsV2LifecycleFailure;
      });
    }
  }
}
