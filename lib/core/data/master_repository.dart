import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../utils/error_text.dart';
import 'master_entity.dart';
import 'memory_db.dart';

/// Collection reserving normalised unique values (see `normalize.dart`).
const uniqueKeysCollection = 'unique_keys';

abstract class MasterRepository {
  /// Streams every record of [config]'s collection matching its fixed values.
  /// Master data sets are small (hundreds of rows), so search, filtering and
  /// pagination happen on the client.
  Stream<List<MasterRecord>> watch(MasterEntityConfig config);

  /// Creates ([id] == null) or updates a record, enforcing unique rules
  /// atomically. Returns the record ID.
  Future<String> save(
    MasterEntityConfig config, {
    String? id,
    required Map<String, dynamic> data,
  });

  Future<void> setActive(MasterEntityConfig config, String id, bool active);
}

List<MasterRecord> _sorted(List<MasterRecord> list) => list
  ..sort((a, b) {
    final x = (b.updatedAt ?? DateTime(0)).compareTo(
      a.updatedAt ?? DateTime(0),
    );
    return x != 0 ? x : a.id.compareTo(b.id);
  });

class FirestoreMasterRepository implements MasterRepository {
  FirestoreMasterRepository(this._db, this._auth);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String get _uid {
    final u = _auth.currentUser;
    if (u == null) throw ValidationException('You are signed out.');
    return u.uid;
  }

  @override
  Stream<List<MasterRecord>> watch(MasterEntityConfig config) {
    Query<Map<String, dynamic>> q = _db.collection(config.collection);
    for (final e in config.fixedValues.entries) {
      q = q.where(e.key, isEqualTo: e.value);
    }
    return q.snapshots().map(
      (s) => _sorted([for (final d in s.docs) MasterRecord(d.id, d.data())]),
    );
  }

  @override
  Future<String> save(
    MasterEntityConfig config, {
    String? id,
    required Map<String, dynamic> data,
  }) async {
    final uid = _uid;
    final col = _db.collection(config.collection);
    final keys = _db.collection(uniqueKeysCollection);
    final ref = id == null ? col.doc() : col.doc(id);
    final payload = {...data, ...config.fixedValues};

    await _db.runTransaction((tx) async {
      Map<String, dynamic>? existing;
      if (id != null) {
        final snap = await tx.get(ref);
        if (!snap.exists) throw ValidationException('Record no longer exists.');
        existing = snap.data();
      }
      final newKeys = config.uniqueKeys(payload);
      final oldKeys = existing == null
          ? <String>{}
          : config.uniqueKeys(existing);

      // All reads must happen before any writes in a transaction.
      for (final k in newKeys.difference(oldKeys)) {
        final snap = await tx.get(keys.doc(k));
        if (snap.exists && snap.data()?['recordId'] != ref.id) {
          throw DuplicateValueException(config.messageForKey(k, payload));
        }
      }
      for (final k in oldKeys.difference(newKeys)) {
        tx.delete(keys.doc(k));
      }
      for (final k in newKeys.difference(oldKeys)) {
        tx.set(keys.doc(k), {
          'collection': config.collection,
          'recordId': ref.id,
          'createdBy': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      tx.set(ref, {
        ...payload,
        'status': existing?['status'] ?? payload['status'] ?? 'active',
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': uid,
        if (existing == null) ...{
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': uid,
        },
      }, SetOptions(merge: true));
    });
    return ref.id;
  }

  @override
  Future<void> setActive(MasterEntityConfig config, String id, bool active) {
    return _db.collection(config.collection).doc(id).update({
      'status': active ? 'active' : 'inactive',
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': _uid,
    });
  }
}

class MemoryMasterRepository implements MasterRepository {
  MemoryMasterRepository(this._db);

  final MemoryDb _db;

  @override
  Stream<List<MasterRecord>> watch(MasterEntityConfig config) => _db
      .watch(config.collection)
      .map(
        (rows) => _sorted([
          for (final r in rows)
            if (config.matchesFixed(r.value)) MasterRecord(r.key, r.value),
        ]),
      );

  @override
  Future<String> save(
    MasterEntityConfig config, {
    String? id,
    required Map<String, dynamic> data,
  }) async {
    final payload = {...data, ...config.fixedValues};
    final existing = id == null ? null : _db.get(config.collection, id);
    final newKeys = config.uniqueKeys(payload);
    for (final r in _db.list(config.collection)) {
      if (r.key == id) continue;
      final clash = config.uniqueKeys(r.value).intersection(newKeys);
      if (clash.isNotEmpty) {
        throw DuplicateValueException(
          config.messageForKey(clash.first, payload),
        );
      }
    }
    final docId = id ?? _db.newId();
    final now = DateTime.now();
    _db.put(config.collection, docId, {
      ...?existing,
      ...payload,
      'status': existing?['status'] ?? payload['status'] ?? 'active',
      'updatedAt': now,
      'updatedBy': _db.actorUid,
      'createdAt': existing?['createdAt'] ?? now,
      'createdBy': existing?['createdBy'] ?? _db.actorUid,
    });
    _db.audit(
      action: existing == null ? 'create' : 'update',
      module: config.module,
      collection: config.collection,
      recordId: docId,
      recordLabel: _label(payload),
      metadata: {
        if (existing != null)
          'changedFields': [
            for (final k in payload.keys)
              if ('${existing[k]}' != '${payload[k]}') k,
          ],
      },
    );
    return docId;
  }

  @override
  Future<void> setActive(
    MasterEntityConfig config,
    String id,
    bool active,
  ) async {
    final existing = _db.get(config.collection, id);
    if (existing == null) throw ValidationException('Record not found.');
    _db.put(config.collection, id, {
      ...existing,
      'status': active ? 'active' : 'inactive',
      'updatedAt': DateTime.now(),
      'updatedBy': _db.actorUid,
    });
    _db.audit(
      action: active ? 'activate' : 'deactivate',
      module: config.module,
      collection: config.collection,
      recordId: id,
      recordLabel: _label(existing),
    );
  }

  static String? _label(Map<String, dynamic> d) =>
      (d['name'] ??
              d['fullName'] ??
              d['roomNumber'] ??
              d['bedNumber'] ??
              d['code'])
          ?.toString();
}
