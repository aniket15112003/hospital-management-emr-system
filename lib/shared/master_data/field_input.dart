import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/master_entity.dart';
import 'master_providers.dart';

/// Renders the input for one [FieldDef]. Holds no state itself: the value
/// lives in the parent's data map and changes are reported via [onChanged].
class FieldInput extends ConsumerWidget {
  const FieldInput({
    super.key,
    required this.field,
    required this.data,
    required this.onChanged,
    this.controller,
    this.readOnly = false,
  });

  final FieldDef field;
  final Map<String, dynamic> data;

  /// Called with a map of updated keys (references update several keys).
  final void Function(Map<String, dynamic> changes) onChanged;

  /// Required for text-like fields.
  final TextEditingController? controller;
  final bool readOnly;

  String get _label =>
      field.isRequired(data) ? '${field.label} *' : field.label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (field.type) {
      case FieldType.boolean:
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(field.label),
          subtitle: field.helper == null ? null : Text(field.helper!),
          value: data[field.key] == true,
          onChanged: readOnly ? null : (v) => onChanged({field.key: v}),
        );
      case FieldType.select:
        return _select();
      case FieldType.reference:
        return _reference(ref);
      default:
        return _text();
    }
  }

  Widget _text() {
    final numeric =
        field.type == FieldType.number || field.type == FieldType.integer;
    return TextFormField(
      controller: controller,
      readOnly: readOnly || field.derived,
      maxLines: field.type == FieldType.multiline ? 3 : 1,
      keyboardType: switch (field.type) {
        FieldType.number => const TextInputType.numberWithOptions(
          decimal: true,
        ),
        FieldType.integer => TextInputType.number,
        FieldType.email => TextInputType.emailAddress,
        FieldType.phone => TextInputType.phone,
        FieldType.multiline => TextInputType.multiline,
        _ => TextInputType.text,
      },
      inputFormatters: [
        if (field.type == FieldType.integer)
          FilteringTextInputFormatter.digitsOnly,
        if (field.type == FieldType.number)
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
        if (field.uppercase) _UpperCaseFormatter(),
      ],
      decoration: InputDecoration(labelText: _label, helperText: field.helper),
      validator: (_) =>
          field.validate(parseFieldText(field, controller!.text), data),
      onChanged: (_) {
        if (!numeric) return;
        onChanged({field.key: parseFieldText(field, controller!.text)});
      },
    );
  }

  Widget _select() {
    final current = data[field.key] as String?;
    final locked = current != null && field.lockedOptions.contains(current);
    final options = [
      for (final o in field.options)
        if (!field.lockedOptions.contains(o.value) || o.value == current) o,
    ];
    return DropdownButtonFormField<String>(
      initialValue: options.any((o) => o.value == current) ? current : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: _label,
        helperText: locked
            ? 'Set by another module workflow; cannot be changed here'
            : field.helper,
      ),
      items: [
        for (final o in options)
          DropdownMenuItem(value: o.value, child: Text(o.label)),
      ],
      onChanged: readOnly || locked ? null : (v) => onChanged({field.key: v}),
      validator: (v) => field.validate(v, data),
    );
  }

  Widget _reference(WidgetRef ref) {
    final async = ref.watch(collectionRecordsProvider(field.refCollection!));
    final current = data[field.key] as String?;
    final records = async.value ?? const <MasterRecord>[];
    // Offer active records only, plus the current value so it stays visible.
    final options = records.where((r) => r.isActive || r.id == current).toList()
      ..sort(
        (a, b) =>
            '${a[field.refLabelField]}'.compareTo('${b[field.refLabelField]}'),
      );
    String label(MasterRecord r) {
      final base = '${r[field.refLabelField] ?? r.id}';
      final ward = r['wardName'];
      final withParent = field.refCollection == 'rooms' && ward != null
          ? '$base · $ward'
          : base;
      return r.isActive ? withParent : '$withParent (inactive)';
    }

    final known = options.any((r) => r.id == current);
    if (field.derived || readOnly) {
      return TextFormField(
        key: ValueKey('${field.key}-$current'),
        initialValue: '${data[field.refNameKey] ?? ''}',
        readOnly: true,
        decoration: InputDecoration(
          labelText: field.label,
          helperText: field.helper,
        ),
      );
    }
    return DropdownButtonFormField<String>(
      key: ValueKey('${field.key}-${options.length}-$known'),
      initialValue: known ? current : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: _label,
        helperText: async.isLoading ? 'Loading…' : field.helper,
        errorText: async.hasError ? 'Could not load options' : null,
      ),
      items: [
        if (!field.isRequired(data))
          const DropdownMenuItem<String>(value: '', child: Text('— None —')),
        for (final r in options)
          DropdownMenuItem(value: r.id, child: Text(label(r))),
      ],
      onChanged: (id) {
        final rec = options.where((r) => r.id == id).firstOrNull;
        onChanged({
          field.key: (id == null || id.isEmpty) ? null : id,
          field.refNameKey: rec?[field.refLabelField],
          for (final e in field.refCopy.entries) e.key: rec?[e.value],
        });
      },
      validator: (v) {
        final base = field.validate(v == '' ? null : v, data);
        if (base != null) return base;
        final rec = records.where((r) => r.id == v).firstOrNull;
        if (rec != null && !rec.isActive) {
          return 'The selected ${field.label.toLowerCase()} is inactive';
        }
        return null;
      },
    );
  }
}

Object? parseFieldText(FieldDef f, String text) {
  final t = text.trim();
  if (t.isEmpty) return null;
  switch (f.type) {
    case FieldType.number:
      return num.tryParse(t) ?? t;
    case FieldType.integer:
      return int.tryParse(t) ?? t;
    case FieldType.email:
      return t.toLowerCase();
    default:
      return t.replaceAll(RegExp(r'[ \t]+'), ' ');
  }
}

bool isTextField(FieldDef f) => switch (f.type) {
  FieldType.select || FieldType.reference || FieldType.boolean => false,
  _ => true,
};

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(text: newValue.text.toUpperCase());
}
