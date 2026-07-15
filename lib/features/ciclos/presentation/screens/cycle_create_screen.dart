import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/cycle_models.dart';
import '../providers/cycle_providers.dart';

class CycleCreateScreen extends ConsumerWidget {
  const CycleCreateScreen({super.key, required this.farmId});

  final String farmId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(cycleAccessProvider(farmId));
    final catalogs = ref.watch(cycleCatalogsProvider);
    final groups = ref.watch(cycleGroupsProvider(farmId));
    final candidates = ref.watch(eligibleCycleMembersProvider(farmId));

    final loadError =
        access.error ?? catalogs.error ?? groups.error ?? candidates.error;
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo ciclo')),
      body: loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No se pudo cargar la configuración del ciclo: $loadError',
                ),
              ),
            )
          : access.isLoading ||
                catalogs.isLoading ||
                groups.isLoading ||
                candidates.isLoading
          ? const Center(child: CircularProgressIndicator())
          : access.requireValue.canEdit
          ? _CycleCreateForm(
              farmId: farmId,
              catalogs: catalogs.requireValue,
              groups: groups.requireValue,
              candidates: candidates.requireValue,
            )
          : const _ReadOnlyCreate(),
    );
  }
}

class _CycleCreateForm extends ConsumerStatefulWidget {
  const _CycleCreateForm({
    required this.farmId,
    required this.catalogs,
    required this.groups,
    required this.candidates,
  });

  final String farmId;
  final CycleCatalogs catalogs;
  final List<CycleGroup> groups;
  final List<CycleMemberCandidate> candidates;

  @override
  ConsumerState<_CycleCreateForm> createState() => _CycleCreateFormState();
}

class _CycleCreateFormState extends ConsumerState<_CycleCreateForm> {
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  final _memberIds = <String>{};
  String? _productCode;
  String? _animalTypeId;
  String? _groupId;
  DateTime _startedAt = DateTime.now();
  String? _error;
  var _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  List<CycleMemberCandidate> get _filteredCandidates => [
    for (final candidate in widget.candidates)
      if (candidate.animalTypeId == _animalTypeId) candidate,
  ];

  Future<void> _submit() async {
    if (_productCode == null || _animalTypeId == null || _memberIds.isEmpty) {
      setState(
        () => _error =
            'Elige un producto, un tipo de animal y al menos un integrante.',
      );
      return;
    }
    setState(() {
      _error = null;
      _submitting = true;
    });
    try {
      await ref
          .read(cycleMutationsProvider.notifier)
          .create(
            CycleCreationInput(
              farmId: widget.farmId,
              productCode: _productCode!,
              animalTypeId: _animalTypeId!,
              animalIds: _memberIds.toList(growable: false),
              startedAt: _startedAt,
              name: _nameController.text,
              notes: _notesController.text,
            ),
          );
      ref.invalidate(cyclesProvider(widget.farmId));
      if (mounted) {
        context.pop();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final animalTypes = <String, String>{
      for (final candidate in widget.candidates)
        candidate.animalTypeId: candidate.animalTypeName,
    };
    final groups = [
      for (final group in widget.groups)
        if (group.animalTypeId == _animalTypeId) group,
    ];

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Configura el ciclo y confirma sus integrantes explícitos.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del ciclo (opcional)',
                  hintText: 'Ej. Ponedoras de primavera',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _productCode,
                decoration: const InputDecoration(labelText: 'Producto'),
                items: [
                  for (final product in widget.catalogs.products)
                    DropdownMenuItem(
                      value: product.code,
                      child: Text(product.name),
                    ),
                ],
                onChanged: _submitting
                    ? null
                    : (value) => setState(() => _productCode = value),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _animalTypeId,
                decoration: const InputDecoration(labelText: 'Tipo de animal'),
                items: [
                  for (final entry in animalTypes.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: _submitting
                    ? null
                    : (value) => setState(() {
                        _animalTypeId = value;
                        _groupId = null;
                        _memberIds.clear();
                      }),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _groupId,
                decoration: const InputDecoration(
                  labelText: 'Incluir integrantes desde un grupo (opcional)',
                ),
                items: [
                  for (final group in groups)
                    DropdownMenuItem(value: group.id, child: Text(group.name)),
                ],
                onChanged: _animalTypeId == null || _submitting
                    ? null
                    : (value) => setState(() {
                        _groupId = value;
                        if (value != null) {
                          _memberIds.addAll([
                            for (final candidate in _filteredCandidates)
                              if (candidate.groupId == value) candidate.id,
                          ]);
                        }
                      }),
              ),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Fecha de inicio'),
                subtitle: Text(DateFormat.yMMMd().format(_startedAt)),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: _submitting
                    ? null
                    : () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _startedAt,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (date != null && mounted) {
                          setState(() => _startedAt = date);
                        }
                      },
              ),
              const Divider(),
              Text(
                'Integrantes (${_memberIds.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              const Text(
                'Los integrantes del grupo son solo un punto de partida. Edita esta lista antes de crear el ciclo.',
              ),
              const SizedBox(height: 8),
              if (_animalTypeId == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Elige un tipo de animal para ver los integrantes disponibles.',
                  ),
                )
              else if (_filteredCandidates.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No hay animales activos disponibles para este tipo.',
                  ),
                )
              else
                ..._filteredCandidates.map(
                  (candidate) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _memberIds.contains(candidate.id),
                    title: Text(candidate.label),
                    subtitle: Text(candidate.groupName ?? 'Sin grupo'),
                    onChanged: _submitting
                        ? null
                        : (selected) => setState(() {
                            if (selected ?? false) {
                              _memberIds.add(candidate.id);
                            } else {
                              _memberIds.remove(candidate.id);
                            }
                          }),
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notas (opcional)',
                  alignLabelWithHint: true,
                ),
                minLines: 2,
                maxLines: 4,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: const Text('Crear ciclo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyCreate extends StatelessWidget {
  const _ReadOnlyCreate();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text(
        'Los usuarios con acceso de visualización pueden consultar los ciclos, pero no crearlos.',
      ),
    ),
  );
}
