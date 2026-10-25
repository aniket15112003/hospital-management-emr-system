import '../utils/formatters.dart';
import '../utils/normalize.dart';

enum FieldType {
  text,
  multiline,
  number,
  integer,
  email,
  phone,
  select,
  reference,
  boolean,
}

class SelectOption {
  const SelectOption(this.value, this.label);
  final String value;
  final String label;
}

/// Declarative definition of one field of a master-data entity. Drives the
/// form, table, search, filters, and validation.
class FieldDef {
  const FieldDef(
    this.key,
    this.label, {
    this.type = FieldType.text,
    this.required = false,
    this.options = const [],
    this.refCollection,
    this.refLabelField = 'name',
    this.refCopy = const {},
    this.min,
    this.maxLength = 120,
    this.uppercase = false,
    this.inTable = true,
    this.filterable = false,
    this.searchable = false,
    this.helper,
    this.requiredWhen,
    this.visibleWhen,
    this.defaultValue,
    this.money = false,
    this.derived = false,
    this.lockedOptions = const {},
  });

  final String key;
  final String label;
  final FieldType type;
  final bool required;

  /// For [FieldType.select].
  final List<SelectOption> options;

  /// For [FieldType.reference]: the collection referenced. The record stores
  /// the referenced document ID under [key] and a denormalised display label
  /// under [refNameKey].
  final String? refCollection;
  final String refLabelField;

  /// Extra fields copied from the referenced record on selection,
  /// as `{targetKey: sourceKey}` (e.g. a bed copies its room's ward).
  final Map<String, String> refCopy;

  final num? min;
  final int maxLength;
  final bool uppercase;
  final bool inTable;
  final bool filterable;
  final bool searchable;
  final String? helper;
  final bool Function(Map<String, dynamic> data)? requiredWhen;
  final bool Function(Map<String, dynamic> data)? visibleWhen;
  final Object? defaultValue;
  final bool money;

  /// Not editable in the form; filled from another field (see [refCopy]).
  final bool derived;

  /// Select values shown but not selectable by administrators (set only by
  /// another module's workflow). A record holding one is read-only here.
  final Set<String> lockedOptions;

  String get refNameKey => key.endsWith('Id')
      ? '${key.substring(0, key.length - 2)}Name'
      : '${key}Name';

  bool isRequired(Map<String, dynamic> data) =>
      required || (requiredWhen?.call(data) ?? false);

  bool isVisible(Map<String, dynamic> data) => visibleWhen?.call(data) ?? true;

  /// Returns an error message or null.
  String? validate(Object? value, Map<String, dynamic> data) {
    if (!isVisible(data)) return null;
    final empty = value == null || (value is String && value.trim().isEmpty);
    if (empty) return isRequired(data) ? '$label is required' : null;
    switch (type) {
      case FieldType.number:
      case FieldType.integer:
        if (value is! num) return '$label must be a number';
        if (type == FieldType.integer && value != value.roundToDouble()) {
          return '$label must be a whole number';
        }
        if (min != null && value < min!) return '$label must be at least $min';
        return null;
      case FieldType.email:
        final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch('$value');
        return ok ? null : 'Enter a valid email address';
      case FieldType.phone:
        final digits = '$value'.replaceAll(RegExp(r'[\s\-()+]'), '');
        final ok = RegExp(r'^\d{7,15}$').hasMatch(digits);
        return ok ? null : 'Enter a valid phone number (7–15 digits)';
      case FieldType.select:
        if (options.isNotEmpty && !options.any((o) => o.value == value)) {
          return 'Select a valid $label';
        }
        return null;
      default:
        if (value is String && value.trim().length > maxLength) {
          return '$label must be at most $maxLength characters';
        }
        return null;
    }
  }

  /// Display text for tables and detail views.
  String display(Map<String, dynamic> data) {
    final v = data[key];
    switch (type) {
      case FieldType.reference:
        return '${data[refNameKey] ?? (v == null || v == '' ? '—' : v)}';
      case FieldType.select:
        for (final o in options) {
          if (o.value == v) return o.label;
        }
        return v == null ? '—' : '$v';
      case FieldType.boolean:
        return v == true ? 'Yes' : 'No';
      case FieldType.number:
        if (money) return formatMoney(v);
        return v == null ? '—' : '$v';
      default:
        return v == null || '$v'.isEmpty ? '—' : '$v';
    }
  }
}

/// Uniqueness constraint over one or more fields, optionally scoped by
/// another field (e.g. bed number unique within a room).
class UniqueRule {
  const UniqueRule(this.fields, {this.scopeField, required this.message});

  final List<String> fields;
  final String? scopeField;
  final String message;

  /// Returns the `unique_keys` doc ID reserving this rule's value in [data],
  /// or null when all fields are empty.
  String? keyFor(String collection, Map<String, dynamic> data) {
    final parts = fields.map((f) => normalizeKey(data[f])).toList();
    if (parts.every((p) => p.isEmpty)) return null;
    final scope = scopeField == null ? '_' : '${data[scopeField] ?? '_'}';
    return uniqueKeyId(
      collection: collection,
      field: fields.join('+'),
      scope: scope,
      normalizedValue: parts.join('|'),
    );
  }
}

class MasterEntityConfig {
  const MasterEntityConfig({
    required this.collection,
    required this.module,
    required this.title,
    required this.singular,
    required this.fields,
    this.uniqueRules = const [],
    this.fixedValues = const {},
    this.subtitle,
    this.notice,
  });

  final String collection;
  final String module;
  final String title;
  final String singular;
  final List<FieldDef> fields;
  final List<UniqueRule> uniqueRules;

  /// Values always written and used to filter (e.g. billing master `type`).
  final Map<String, Object> fixedValues;
  final String? subtitle;
  final String? notice;

  List<FieldDef> get searchFields =>
      fields.where((f) => f.searchable).toList(growable: false);

  List<FieldDef> get filterFields =>
      fields.where((f) => f.filterable).toList(growable: false);

  Set<String> uniqueKeys(Map<String, dynamic> data) => {
    for (final r in uniqueRules) ?r.keyFor(collection, data),
  };

  /// Returns the message of the rule matching [keyId].
  String messageForKey(String keyId, Map<String, dynamic> data) {
    for (final r in uniqueRules) {
      if (r.keyFor(collection, data) == keyId) return r.message;
    }
    return 'A record with the same value already exists.';
  }

  bool matchesFixed(Map<String, dynamic> data) =>
      fixedValues.entries.every((e) => data[e.key] == e.value);
}

/// A master-data document.
class MasterRecord {
  const MasterRecord(this.id, this.data);

  final String id;
  final Map<String, dynamic> data;

  Object? operator [](String key) => data[key];
  String get status => '${data['status'] ?? 'active'}';
  bool get isActive => status == 'active';
  DateTime? get updatedAt => asDateTime(data['updatedAt']);
  DateTime? get createdAt => asDateTime(data['createdAt']);
}
