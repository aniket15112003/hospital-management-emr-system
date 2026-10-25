import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/memory_db.dart';
import '../utils/error_text.dart';
import 'permissions.dart';

class RoleDefinition {
  const RoleDefinition(this.role, this.permissions, {required this.stored});

  final AppRole role;
  final PermissionMatrix permissions;

  /// False when no `roles/{id}` document exists yet. Security Rules deny
  /// everything for a role without a document (except Super Admin), so the
  /// UI flags these and shows defaults that will be written on save.
  final bool stored;
}

abstract class RolesRepository {
  Stream<Map<AppRole, RoleDefinition>> watch();

  /// Saves a role's permission matrix. Super Admin is never editable.
  Future<void> save(AppRole role, PermissionMatrix permissions);
}

Map<AppRole, RoleDefinition> _merge(Map<String, Map<String, dynamic>> docs) => {
  for (final r in AppRole.values)
    r: r == AppRole.superAdmin
        ? RoleDefinition(r, defaultPermissionsFor(r), stored: true)
        : docs[r.id] == null
        ? RoleDefinition(r, defaultPermissionsFor(r), stored: false)
        : RoleDefinition(
            r,
            permissionsFromJson(
              Map<String, dynamic>.from(
                docs[r.id]!['permissions'] as Map? ?? {},
              ),
            ),
            stored: true,
          ),
};

class FirestoreRolesRepository implements RolesRepository {
  FirestoreRolesRepository(this._db, this._auth);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  @override
  Stream<Map<AppRole, RoleDefinition>> watch() => _db
      .collection('roles')
      .snapshots()
      .map((s) => _merge({for (final d in s.docs) d.id: d.data()}));

  @override
  Future<void> save(AppRole role, PermissionMatrix permissions) {
    if (role == AppRole.superAdmin) {
      throw ValidationException('Super Admin permissions cannot be changed.');
    }
    return _db.collection('roles').doc(role.id).set({
      'name': role.label,
      'permissions': permissionsToJson(permissions),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': _auth.currentUser?.uid,
    });
  }
}

class MemoryRolesRepository implements RolesRepository {
  MemoryRolesRepository(this._db);

  final MemoryDb _db;

  @override
  Stream<Map<AppRole, RoleDefinition>> watch() => _db
      .watch('roles')
      .map((rows) => _merge({for (final r in rows) r.key: r.value}));

  @override
  Future<void> save(AppRole role, PermissionMatrix permissions) async {
    if (role == AppRole.superAdmin) {
      throw ValidationException('Super Admin permissions cannot be changed.');
    }
    _db.put('roles', role.id, {
      'name': role.label,
      'permissions': permissionsToJson(permissions),
      'updatedAt': DateTime.now(),
      'updatedBy': _db.actorUid,
    });
    _db.audit(
      action: 'update_permissions',
      module: Modules.roles,
      collection: 'roles',
      recordId: role.id,
      recordLabel: role.label,
    );
  }
}
