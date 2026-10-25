import 'dart:async';
import 'dart:math';

/// In-memory document store used ONLY in explicit demo mode.
/// Nothing here is persisted; data resets when the app restarts.
class MemoryDb {
  final _collections = <String, Map<String, Map<String, dynamic>>>{};
  final _changes = StreamController<String>.broadcast();
  final _rand = Random();

  /// Demo actor, kept in sync with the demo session.
  String actorUid = 'demo-super-admin';
  String actorName = 'Demo Administrator';

  Map<String, Map<String, dynamic>> _col(String c) =>
      _collections.putIfAbsent(c, () => {});

  List<MapEntry<String, Map<String, dynamic>>> list(String collection) => [
    for (final e in _col(collection).entries)
      MapEntry(e.key, Map<String, dynamic>.of(e.value)),
  ];

  Map<String, dynamic>? get(String collection, String id) {
    final d = _col(collection)[id];
    return d == null ? null : Map<String, dynamic>.of(d);
  }

  Stream<List<MapEntry<String, Map<String, dynamic>>>> watch(
    String collection,
  ) async* {
    yield list(collection);
    yield* _changes.stream
        .where((c) => c == collection)
        .map((_) => list(collection));
  }

  Stream<Map<String, dynamic>?> watchDoc(String collection, String id) async* {
    yield get(collection, id);
    yield* _changes.stream
        .where((c) => c == collection)
        .map((_) => get(collection, id));
  }

  String newId() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
    return List.generate(20, (_) => chars[_rand.nextInt(chars.length)]).join();
  }

  void put(String collection, String id, Map<String, dynamic> data) {
    _col(collection)[id] = Map<String, dynamic>.of(data);
    _changes.add(collection);
  }

  void remove(String collection, String id) {
    _col(collection).remove(id);
    _changes.add(collection);
  }

  /// Mirrors what the Cloud Function audit triggers do in Firebase mode.
  void audit({
    required String action,
    required String module,
    required String collection,
    String? recordId,
    String? recordLabel,
    String result = 'success',
    Map<String, dynamic> metadata = const {},
  }) {
    put('audit_logs', newId(), {
      'timestamp': DateTime.now(),
      'actorUid': actorUid,
      'actorName': actorName,
      'action': action,
      'module': module,
      'collection': collection,
      'recordId': recordId,
      'recordLabel': recordLabel,
      'result': result,
      'metadata': metadata,
    });
  }
}
