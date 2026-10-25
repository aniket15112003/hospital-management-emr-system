import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/formatters.dart';
import 'memory_db.dart';

/// `audit_logs` is append-only and written exclusively by trusted backend
/// code (Cloud Functions). Clients can only read it.
const auditCollection = 'audit_logs';

class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.timestamp,
    required this.actorUid,
    required this.actorName,
    required this.action,
    required this.module,
    required this.collection,
    required this.recordId,
    required this.recordLabel,
    required this.result,
    required this.metadata,
  });

  factory AuditEntry.fromMap(String id, Map<String, dynamic> d) => AuditEntry(
    id: id,
    timestamp: asDateTime(d['timestamp']),
    actorUid: d['actorUid'] as String?,
    actorName: d['actorName'] as String?,
    action: '${d['action'] ?? 'unknown'}',
    module: '${d['module'] ?? 'unknown'}',
    collection: d['collection'] as String?,
    recordId: d['recordId'] as String?,
    recordLabel: d['recordLabel'] as String?,
    result: '${d['result'] ?? 'success'}',
    metadata: Map<String, dynamic>.from(d['metadata'] as Map? ?? const {}),
  );

  final String id;
  final DateTime? timestamp;
  final String? actorUid;
  final String? actorName;
  final String action;
  final String module;
  final String? collection;
  final String? recordId;
  final String? recordLabel;
  final String result;
  final Map<String, dynamic> metadata;

  String get actor => actorName ?? actorUid ?? 'System';
}

class AuditQuery {
  const AuditQuery({this.module, this.from, this.to, this.limit = 50});

  final String? module;
  final DateTime? from;

  /// Exclusive upper bound.
  final DateTime? to;
  final int limit;

  @override
  bool operator ==(Object other) =>
      other is AuditQuery &&
      other.module == module &&
      other.from == from &&
      other.to == to &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(module, from, to, limit);
}

abstract class AuditRepository {
  Stream<List<AuditEntry>> watch(AuditQuery query);
}

class FirestoreAuditRepository implements AuditRepository {
  FirestoreAuditRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<List<AuditEntry>> watch(AuditQuery query) {
    // Requires composite index (module ASC, timestamp DESC) when filtering
    // by module; see firestore.indexes.json.
    Query<Map<String, dynamic>> q = _db.collection(auditCollection);
    if (query.module != null) q = q.where('module', isEqualTo: query.module);
    if (query.from != null) {
      q = q.where(
        'timestamp',
        isGreaterThanOrEqualTo: Timestamp.fromDate(query.from!),
      );
    }
    if (query.to != null) {
      q = q.where('timestamp', isLessThan: Timestamp.fromDate(query.to!));
    }
    return q
        .orderBy('timestamp', descending: true)
        .limit(query.limit)
        .snapshots()
        .map(
          (s) => [for (final d in s.docs) AuditEntry.fromMap(d.id, d.data())],
        );
  }
}

class MemoryAuditRepository implements AuditRepository {
  MemoryAuditRepository(this._db);

  final MemoryDb _db;

  @override
  Stream<List<AuditEntry>> watch(
    AuditQuery query,
  ) => _db.watch(auditCollection).map((rows) {
    final list = [for (final r in rows) AuditEntry.fromMap(r.key, r.value)]
        .where((e) {
          final t = e.timestamp;
          if (query.module != null && e.module != query.module) return false;
          if (query.from != null && (t == null || t.isBefore(query.from!))) {
            return false;
          }
          if (query.to != null && (t == null || !t.isBefore(query.to!))) {
            return false;
          }
          return true;
        })
        .toList();
    list.sort(
      (a, b) =>
          (b.timestamp ?? DateTime(0)).compareTo(a.timestamp ?? DateTime(0)),
    );
    return list.take(query.limit).toList();
  });
}
