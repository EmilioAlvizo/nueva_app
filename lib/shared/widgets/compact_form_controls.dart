import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const _compactControlHeight = 50.0;
const _compactMenuMaxHeight = 320.0;

class CompactLabeledField extends StatelessWidget {
  const CompactLabeledField({
    super.key,
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

InputDecoration compactInputDecoration(
  BuildContext context, {
  String? hintText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  String? prefixText,
  String? suffixText,
  String? helperText,
  String? errorText,
  bool enabled = true,
}) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final decorationTheme = theme.inputDecorationTheme;
  const radius = BorderRadius.all(Radius.circular(12));

  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: color, width: width),
      );

  return InputDecoration(
    isDense: true,
    constraints: const BoxConstraints(minHeight: _compactControlHeight),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
    hintText: hintText,
    prefixIcon: prefixIcon,
    prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
    suffixIcon: suffixIcon,
    suffixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
    prefixText: prefixText,
    suffixText: suffixText,
    helperText: helperText,
    errorText: errorText,
    enabled: enabled,
    filled: decorationTheme.filled,
    fillColor: decorationTheme.fillColor ?? scheme.surfaceContainerHighest,
    hintStyle: decorationTheme.hintStyle?.copyWith(
      color: scheme.onSurfaceVariant,
    ),
    border: border(scheme.outline),
    enabledBorder: border(scheme.outlineVariant),
    focusedBorder: border(scheme.primary, 1.5),
    errorBorder: border(scheme.error),
    focusedErrorBorder: border(scheme.error, 1.5),
    disabledBorder: border(scheme.outlineVariant.withValues(alpha: 0.5)),
  );
}

class CompactDateField extends StatelessWidget {
  const CompactDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.placeholder = 'Selecciona una fecha',
    this.formatter,
    this.onClear,
    this.clearTooltip = 'Quitar fecha',
    this.helperText,
    this.errorText,
    this.enabled = true,
  });

  final String label;
  final DateTime? value;
  final VoidCallback? onTap;
  final String placeholder;
  final String Function(DateTime value)? formatter;
  final VoidCallback? onClear;
  final String clearTooltip;
  final String? helperText;
  final String? errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final effectiveEnabled = enabled && onTap != null;
    final text = value == null
        ? placeholder
        : formatter?.call(value!) ?? DateFormat('dd/MM/yyyy').format(value!);
    final theme = Theme.of(context);
    final valueStyle = theme.textTheme.bodyMedium?.copyWith(
      color: effectiveEnabled
          ? theme.colorScheme.onSurface
          : theme.colorScheme.onSurface.withValues(alpha: 0.38),
    );

    return CompactLabeledField(
      label: label,
      child: Semantics(
        button: true,
        enabled: effectiveEnabled,
        label: '$label: $text',
        child: InkWell(
          onTap: effectiveEnabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            isEmpty: value == null,
            decoration: compactInputDecoration(
              context,
              enabled: effectiveEnabled,
              helperText: helperText,
              errorText: errorText,
              prefixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
              suffixIcon: onClear == null
                  ? const Icon(Icons.keyboard_arrow_down_rounded)
                  : IconButton(
                      tooltip: clearTooltip,
                      onPressed: effectiveEnabled ? onClear : null,
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: value == null
                  ? theme.inputDecorationTheme.hintStyle
                  : valueStyle,
            ),
          ),
        ),
      ),
    );
  }
}

class CompactDropdownFormField<T> extends StatefulWidget {
  const CompactDropdownFormField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabelBuilder,
    required this.onChanged,
    this.hintText = 'Selecciona una opción',
    this.validator,
    this.helperText,
    this.prefixIcon,
    this.enabled = true,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
    this.dropdownKey,
    this.itemKeyBuilder,
  });

  final String label;
  final T? value;
  final List<T> items;
  final String Function(T item) itemLabelBuilder;
  final ValueChanged<T?>? onChanged;
  final String hintText;
  final FormFieldValidator<T>? validator;
  final String? helperText;
  final Widget? prefixIcon;
  final bool enabled;
  final AutovalidateMode autovalidateMode;
  final Key? dropdownKey;
  final Key? Function(T item)? itemKeyBuilder;

  @override
  State<CompactDropdownFormField<T>> createState() =>
      _CompactDropdownFormFieldState<T>();
}

class _CompactDropdownFormFieldState<T>
    extends State<CompactDropdownFormField<T>> {
  final _fieldKey = GlobalKey<FormFieldState<T>>();
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'Compact dropdown')
      ..addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(CompactDropdownFormField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      final nextValue = widget.value;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || widget.value != nextValue) return;
        final field = _fieldKey.currentState;
        if (field?.value != nextValue) field?.didChange(nextValue);
      });
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final effectiveEnabled = widget.enabled && widget.onChanged != null;
    return FormField<T>(
      key: _fieldKey,
      initialValue: widget.value,
      enabled: effectiveEnabled,
      autovalidateMode: widget.autovalidateMode,
      validator: widget.validator,
      builder: (field) {
        final hasMatchingItem = widget.items.any((item) => item == field.value);
        final theme = Theme.of(context);
        final textStyle = theme.textTheme.bodyMedium?.copyWith(
          color: effectiveEnabled
              ? theme.colorScheme.onSurface
              : theme.colorScheme.onSurface.withValues(alpha: 0.38),
        );

        Widget labelFor(T item) => Text(
          widget.itemLabelBuilder(item),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );

        return CompactLabeledField(
          label: widget.label,
          child: LayoutBuilder(
            builder: (context, constraints) => InputDecorator(
              isEmpty: !hasMatchingItem,
              isFocused: _focusNode.hasFocus,
              decoration: compactInputDecoration(
                context,
                enabled: effectiveEnabled,
                helperText: widget.helperText,
                errorText: field.errorText,
                prefixIcon: widget.prefixIcon,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<T>(
                  key: widget.dropdownKey,
                  value: hasMatchingItem ? field.value : null,
                  hint: Text(
                    widget.hintText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.inputDecorationTheme.hintStyle,
                  ),
                  disabledHint: hasMatchingItem
                      ? labelFor(
                          widget.items.firstWhere(
                            (item) => item == field.value,
                          ),
                        )
                      : Text(
                          widget.hintText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.inputDecorationTheme.hintStyle,
                        ),
                  isDense: true,
                  isExpanded: true,
                  itemHeight: kMinInteractiveDimension,
                  menuWidth: constraints.maxWidth,
                  menuMaxHeight: _compactMenuMaxHeight,
                  borderRadius: BorderRadius.circular(12),
                  padding: EdgeInsets.zero,
                  focusNode: _focusNode,
                  dropdownColor:
                      theme.inputDecorationTheme.fillColor ??
                      theme.colorScheme.surfaceContainer,
                  style: textStyle,
                  selectedItemBuilder: (_) => [
                    for (final item in widget.items) labelFor(item),
                  ],
                  items: [
                    for (final item in widget.items)
                      DropdownMenuItem<T>(
                        key: widget.itemKeyBuilder?.call(item),
                        value: item,
                        child: labelFor(item),
                      ),
                  ],
                  onChanged: effectiveEnabled
                      ? (value) {
                          field.didChange(value);
                          widget.onChanged?.call(value);
                        }
                      : null,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
