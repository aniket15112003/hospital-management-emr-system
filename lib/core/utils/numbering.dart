/// Document-number format configuration (`numbering_settings/{docType}`).
///
/// This is only the FORMAT. Sequence values are allocated by the
/// `allocateDocumentNumber` Cloud Function inside a Firestore transaction on
/// `counters/{docType}`; clients can never write counters. The same
/// formatting logic is implemented in `functions/index.js`.
class NumberFormatConfig {
  const NumberFormatConfig({
    required this.prefix,
    this.separator = '-',
    this.dateSegment = 'none',
    this.padding = 6,
    this.resetPolicy = 'never',
    this.startAt = 1,
  });

  factory NumberFormatConfig.fromMap(
    Map<String, dynamic>? m,
    String fallbackPrefix,
  ) => NumberFormatConfig(
    prefix: '${m?['prefix'] ?? fallbackPrefix}',
    separator: '${m?['separator'] ?? '-'}',
    dateSegment: '${m?['dateSegment'] ?? 'none'}',
    padding: (m?['padding'] as num?)?.toInt() ?? 6,
    resetPolicy: '${m?['resetPolicy'] ?? 'never'}',
    startAt: (m?['startAt'] as num?)?.toInt() ?? 1,
  );

  final String prefix;
  final String separator;

  /// none | YYYY | YYMM | YYYYMM | YYYYMMDD
  final String dateSegment;
  final int padding;

  /// never | yearly | monthly | daily
  final String resetPolicy;
  final int startAt;
}

String _two(int n) => n.toString().padLeft(2, '0');

String formatDocumentNumber(NumberFormatConfig c, int sequence, DateTime date) {
  final date_ = switch (c.dateSegment) {
    'YYYY' => '${date.year}',
    'YYMM' => '${_two(date.year % 100)}${_two(date.month)}',
    'YYYYMM' => '${date.year}${_two(date.month)}',
    'YYYYMMDD' => '${date.year}${_two(date.month)}${_two(date.day)}',
    _ => '',
  };
  final seq = sequence.toString().padLeft(c.padding, '0');
  return [c.prefix, date_, seq].where((p) => p.isNotEmpty).join(c.separator);
}

/// A counter that resets periodically must include a date segment covering
/// that period, otherwise numbers would repeat. Returns an error or null.
String? validateResetPolicy(String resetPolicy, String dateSegment) {
  const covers = {
    'yearly': {'YYYY', 'YYMM', 'YYYYMM', 'YYYYMMDD'},
    'monthly': {'YYMM', 'YYYYMM', 'YYYYMMDD'},
    'daily': {'YYYYMMDD'},
  };
  final allowed = covers[resetPolicy];
  if (allowed == null || allowed.contains(dateSegment)) return null;
  return 'A $resetPolicy reset needs a date segment of ${allowed.join(', ')}; '
      'otherwise numbers would repeat.';
}
