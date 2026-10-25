/// Normalisation policy for uniqueness checks on master data.
///
/// A value is normalised by:
///   1. trimming leading/trailing whitespace,
///   2. collapsing internal runs of whitespace to a single space,
///   3. lower-casing (case-insensitive comparison).
///
/// So "  General   Medicine " and "general medicine" are duplicates, while
/// "Cardiology" and "Cardiology-2" are not. Punctuation is preserved.
String normalizeKey(Object? value) =>
    '${value ?? ''}'.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

/// Firestore document IDs cannot contain '/'. Replace it and other
/// characters that make IDs awkward, keeping the result deterministic.
String keySafe(String s) => s.replaceAll(RegExp(r'[/\\#?\[\]]'), '_');

/// Deterministic ID of the `unique_keys` document that reserves a value.
///
/// [scope] narrows uniqueness, e.g. a room number is only unique within its
/// ward, so the ward ID is the scope.
String uniqueKeyId({
  required String collection,
  required String field,
  required String scope,
  required String normalizedValue,
}) => keySafe('$collection|$field|$scope|$normalizedValue');
