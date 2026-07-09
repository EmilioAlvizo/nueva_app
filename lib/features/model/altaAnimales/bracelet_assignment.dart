class BraceletAssignment {
  static const int maxBraceletValue = 32767;

  BraceletAssignment({
    required this.totalCount,
    Iterable<int> available = const [],
    Iterable<int> selected = const [],
  }) : _available = _normalize(available, field: 'available'),
       _selected = _normalize(selected, field: 'selected') {
    if (totalCount <= 0) {
      throw ArgumentError.value(
        totalCount,
        'totalCount',
        'must be greater than 0',
      );
    }

    if (_selected.length > totalCount) {
      throw ArgumentError.value(
        selected,
        'selected',
        'must not contain more bracelets than totalCount',
      );
    }
  }

  final int totalCount;
  final Set<int> _available;
  final Set<int> _selected;

  List<int> get available {
    final values = _available.difference(_selected).toList()..sort();
    return values;
  }

  List<int> get selected {
    final values = _selected.toList()..sort();
    return values;
  }

  int get missingCount => totalCount - _selected.length;

  bool get hasSelectionRoom => _selected.length < totalCount;

  bool isSelected(int bracelet) => _selected.contains(bracelet);

  BraceletAssignment autoAssign() {
    if (missingCount <= 0) {
      return this;
    }

    final nextSelected = {..._selected};
    for (final bracelet in available) {
      if (nextSelected.length >= totalCount) {
        break;
      }
      nextSelected.add(bracelet);
    }

    return BraceletAssignment(
      totalCount: totalCount,
      available: _available,
      selected: nextSelected,
    );
  }

  BraceletAssignment manualAdd(int bracelet) {
    _validateBracelet(bracelet, field: 'bracelet');

    if (_selected.contains(bracelet)) {
      throw ArgumentError.value(bracelet, 'bracelet', 'must not be duplicated');
    }

    if (_selected.length >= totalCount) {
      throw ArgumentError.value(
        bracelet,
        'bracelet',
        'cannot exceed totalCount',
      );
    }

    return BraceletAssignment(
      totalCount: totalCount,
      available: _available,
      selected: {..._selected, bracelet},
    );
  }

  BraceletAssignment remove(int bracelet) {
    if (!_selected.contains(bracelet)) {
      return this;
    }

    final nextSelected = {..._selected}..remove(bracelet);
    return BraceletAssignment(
      totalCount: totalCount,
      available: _available,
      selected: nextSelected,
    );
  }

  BraceletAssignment clear() =>
      BraceletAssignment(totalCount: totalCount, available: _available);

  static Set<int> _normalize(Iterable<int> values, {required String field}) {
    final normalized = <int>{};
    for (final value in values) {
      _validateBracelet(value, field: field);
      if (!normalized.add(value)) {
        throw ArgumentError.value(values, field, 'must not contain duplicates');
      }
    }
    return normalized;
  }

  static void _validateBracelet(int value, {required String field}) {
    if (value <= 0 || value > maxBraceletValue) {
      throw ArgumentError.value(
        value,
        field,
        'must be a positive small integer',
      );
    }
  }
}
