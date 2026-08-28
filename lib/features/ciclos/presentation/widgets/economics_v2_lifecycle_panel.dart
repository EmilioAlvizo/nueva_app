import 'package:flutter/material.dart';

import '../../../../core/extensions/localization_extension.dart';
import '../../../../core/testing/app_widget_keys.dart';
import '../../../comida/comida_models.dart';
import '../../../model/animal/animal.dart';
import '../../../model/catalogoItem/catalogo_item.dart';
import '../../domain/economics_v2_lifecycle_models.dart';
import '../../../../l10n/app_localizations.dart';

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
  final Future<EconomicsV2CycleCreated> Function(EconomicsV2CreateCycleRequest)
  onCreate;
  final Future<EconomicsV2AnimalAssigned> Function(
    EconomicsV2AssignAnimalRequest,
  )
  onAssignAnimal;
  final Future<EconomicsV2ExpenseRecorded> Function(
    EconomicsV2RecordExpenseRequest,
  )
  onRecordExpense;
  final Future<EconomicsV2FeedLinked> Function(EconomicsV2LinkFeedRequest)
  onLinkFeed;

  @override
  State<EconomicsV2LifecyclePanel> createState() =>
      _EconomicsV2LifecyclePanelState();
}

class _EconomicsV2LifecyclePanelState extends State<EconomicsV2LifecyclePanel> {
  final _expenseController = TextEditingController();
  String? _purposeId, _cycleId, _animalId, _mixtureId, _failure;
  var _step = 0;
  var _submitting = false;

  List<Animal> get _animals => [
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
              _label(l10n, 'title'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            _choice(
              AppWidgetKeys.economicsV2LifecyclePurpose,
              _label(l10n, 'purpose'),
              _purposeId,
              [for (final item in widget.purposes) _item(item.id, item.nombre)],
              (value) => setState(() {
                _purposeId = value;
                _animalId = null;
              }),
            ),
            _action(
              AppWidgetKeys.economicsV2LifecycleCreate,
              _label(l10n, 'create'),
              _purposeId == null ? null : () => _create(today),
            ),
            if (_step >= 1) ...[
              _choice(
                AppWidgetKeys.economicsV2LifecycleAnimal,
                _label(l10n, 'animal'),
                _animalId,
                [
                  for (final animal in _animals)
                    _item(animal.id, 'Ave ${animal.brazalete ?? animal.id}'),
                ],
                (value) => setState(() => _animalId = value),
              ),
              _action(
                AppWidgetKeys.economicsV2LifecycleAssignAnimal,
                _label(l10n, 'assign'),
                _animalId == null ? null : () => _assign(today),
              ),
            ],
            if (_step >= 2) ...[
              TextField(
                key: const ValueKey(
                  AppWidgetKeys.economicsV2LifecycleExpenseAmount,
                ),
                controller: _expenseController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(labelText: _label(l10n, 'expense')),
              ),
              _action(
                AppWidgetKeys.economicsV2LifecycleRecordExpense,
                _label(l10n, 'record'),
                () => _expense(today),
              ),
            ],
            if (_step >= 3) ...[
              _choice(
                AppWidgetKeys.economicsV2LifecycleFeed,
                _label(l10n, 'feed'),
                _mixtureId,
                [
                  for (final mixture in widget.mixtures)
                    _item(mixture.id, mixture.groupName),
                ],
                (value) => setState(() => _mixtureId = value),
              ),
              _action(
                AppWidgetKeys.economicsV2LifecycleLinkFeed,
                _label(l10n, 'link'),
                _mixtureId == null ? null : () => _feed(today),
              ),
            ],
            if (_step > 0) Text(_progress(l10n)),
            if (_failure != null)
              Text(
                _failure!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    );
  }

  DropdownMenuItem<String> _item(String value, String label) =>
      DropdownMenuItem(value: value, child: Text(label));

  Widget _choice(
    String key,
    String label,
    String? value,
    List<DropdownMenuItem<String>> items,
    ValueChanged<String?> changed,
  ) => DropdownButtonFormField<String>(
    key: ValueKey(key),
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    items: items,
    onChanged: _submitting ? null : changed,
  );

  Widget _action(String key, String label, VoidCallback? pressed) =>
      FilledButton(
        key: ValueKey(key),
        onPressed: _submitting ? null : pressed,
        child: Text(label),
      );

  String _progress(AppLocalizations l10n) => switch (_step) {
    1 => _label(l10n, 'created'),
    2 => _label(l10n, 'assigned'),
    3 => _label(l10n, 'recorded'),
    _ => _label(l10n, 'linked'),
  };

  Future<void> _create(DateTime day) {
    final purposeId = _purposeId;
    return purposeId == null
        ? Future.value()
        : _run(() async {
            _cycleId = (await widget.onCreate(
              EconomicsV2CreateCycleRequest(
                farmId: widget.farmId,
                purposeId: purposeId,
                startsOn: day,
              ),
            )).cycleId;
          }, 1);
  }

  Future<void> _assign(DateTime day) {
    final (cycleId, animalId) = (_cycleId, _animalId);
    return cycleId == null || animalId == null
        ? Future.value()
        : _run(
            () => widget.onAssignAnimal(
              EconomicsV2AssignAnimalRequest(
                farmId: widget.farmId,
                cycleId: cycleId,
                animalId: animalId,
                joinedOn: day,
              ),
            ),
            2,
          );
  }

  Future<void> _expense(DateTime day) {
    final amount = double.tryParse(_expenseController.text);
    if (_cycleId == null || amount == null || amount < 0) {
      setState(() => _failure = _label(context.l10n, 'invalid'));
      return Future.value();
    }
    return _run(
      () => widget.onRecordExpense(
        EconomicsV2RecordExpenseRequest(
          farmId: widget.farmId,
          cycleId: _cycleId!,
          occurredOn: day,
          amount: amount,
        ),
      ),
      3,
    );
  }

  Future<void> _feed(DateTime day) {
    final (cycleId, mixtureId) = (_cycleId, _mixtureId);
    return cycleId == null || mixtureId == null
        ? Future.value()
        : _run(
            () => widget.onLinkFeed(
              EconomicsV2LinkFeedRequest(
                farmId: widget.farmId,
                cycleId: cycleId,
                mixtureId: mixtureId,
                startsOn: day,
              ),
            ),
            4,
          );
  }

  Future<void> _run(Future<void> Function() action, int completeStep) async {
    setState(() {
      _submitting = true;
      _failure = null;
    });
    try {
      await action();
      if (mounted) {
        setState(() {
          _step = completeStep;
          _submitting = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _failure = _label(context.l10n, 'failure');
        });
      }
    }
  }

  String _label(AppLocalizations l10n, String step) =>
      l10n.economicsV2LifecycleStep(step);
}
