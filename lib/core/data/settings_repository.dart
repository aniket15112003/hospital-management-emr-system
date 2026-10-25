import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../utils/error_text.dart';
import 'memory_db.dart';

/// Location of a single settings document, plus the module whose `manage`
/// permission is required to change it.
class SettingsDoc {
  const SettingsDoc(this.collection, this.docId, this.module);

  final String collection;
  final String docId;
  final String module;

  @override
  bool operator ==(Object other) =>
      other is SettingsDoc &&
      other.collection == collection &&
      other.docId == docId &&
      other.module == module;

  @override
  int get hashCode => Object.hash(collection, docId, module);
}

abstract class SettingsRepository {
  Stream<Map<String, dynamic>?> watch(SettingsDoc doc);

  /// Merges [data] into the document.
  Future<void> save(SettingsDoc doc, Map<String, dynamic> data);

  /// Whether logo uploads can be performed.
  bool get storageAvailable;

  /// Uploads the hospital logo and returns its download URL.
  Future<String> uploadLogo(Uint8List bytes, String extension);
}

class FirestoreSettingsRepository implements SettingsRepository {
  FirestoreSettingsRepository(this._db, this._auth);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  @override
  Stream<Map<String, dynamic>?> watch(SettingsDoc doc) => _db
      .collection(doc.collection)
      .doc(doc.docId)
      .snapshots()
      .map((s) => s.data());

  @override
  Future<void> save(SettingsDoc doc, Map<String, dynamic> data) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw ValidationException('You are signed out.');
    return _db.collection(doc.collection).doc(doc.docId).set({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': uid,
    }, SetOptions(merge: true));
  }

  @override
  bool get storageAvailable =>
      (Firebase.app().options.storageBucket ?? '').isNotEmpty;

  @override
  Future<String> uploadLogo(Uint8List bytes, String extension) async {
    if (!storageAvailable) {
      throw ValidationException('Firebase Storage is not configured.');
    }
    final ext = extension.toLowerCase();
    final contentType = switch (ext) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      _ => throw ValidationException('Logo must be PNG, JPG or WEBP.'),
    };
    if (bytes.lengthInBytes > 2 * 1024 * 1024) {
      throw ValidationException('Logo must be smaller than 2 MB.');
    }
    final ref = FirebaseStorage.instance.ref('hospital/logo.$ext');
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }
}

class MemorySettingsRepository implements SettingsRepository {
  MemorySettingsRepository(this._db);

  final MemoryDb _db;

  @override
  Stream<Map<String, dynamic>?> watch(SettingsDoc doc) =>
      _db.watchDoc(doc.collection, doc.docId);

  @override
  Future<void> save(SettingsDoc doc, Map<String, dynamic> data) async {
    final existing = _db.get(doc.collection, doc.docId);
    _db.put(doc.collection, doc.docId, {
      ...?existing,
      ...data,
      'updatedAt': DateTime.now(),
      'updatedBy': _db.actorUid,
    });
    _db.audit(
      action: 'update',
      module: doc.module,
      collection: doc.collection,
      recordId: doc.docId,
      recordLabel: doc.docId,
      metadata: {'changedFields': data.keys.toList()},
    );
  }

  @override
  bool get storageAvailable => false;

  @override
  Future<String> uploadLogo(
    Uint8List bytes,
    String extension,
  ) => throw ValidationException(
    'Logo upload requires Firebase Storage and is unavailable in demo mode.',
  );
}
