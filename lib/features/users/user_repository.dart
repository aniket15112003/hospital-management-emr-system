import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../core/auth/permissions.dart';
import '../../core/auth/user_admin_policy.dart';
import '../../core/data/memory_db.dart';
import '../../core/utils/error_text.dart';
import '../../core/utils/formatters.dart';

/// A `users/{uid}` profile. Passwords are never stored in Firestore; they
/// live only in Firebase Authentication.
class AppUserRecord {
  const AppUserRecord({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.role,
    required this.status,
    this.phone,
    this.createdAt,
    this.updatedAt,
  });

  factory AppUserRecord.fromMap(String uid, Map<String, dynamic> d) =>
      AppUserRecord(
        uid: uid,
        displayName: '${d['displayName'] ?? ''}',
        email: '${d['email'] ?? ''}',
        role: AppRole.fromId(d['role'] as String?),
        status: '${d['status'] ?? 'inactive'}',
        phone: d['phone'] as String?,
        createdAt: asDateTime(d['createdAt']),
        updatedAt: asDateTime(d['updatedAt']),
      );

  final String uid;
  final String displayName;
  final String email;
  final AppRole? role;
  final String status;
  final String? phone;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isActive => status == 'active';
}

class CreateUserResult {
  const CreateUserResult(this.uid, this.passwordSetupLink);

  final String uid;

  /// One-time password-setup link to share securely with the new user.
  final String? passwordSetupLink;
}

abstract class UserAdminRepository {
  Stream<List<AppUserRecord>> watchUsers();

  Future<CreateUserResult> createUser({
    required String displayName,
    required String email,
    required AppRole role,
    String? phone,
  });

  Future<void> setRole(String uid, AppRole role);

  Future<void> setActive(String uid, bool active);
}

/// Reads profiles from Firestore; every write goes through Cloud Functions
/// (Security Rules deny client writes to `users`).
class FirebaseUserAdminRepository implements UserAdminRepository {
  FirebaseUserAdminRepository(this._db, this._functions);

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  @override
  Stream<List<AppUserRecord>> watchUsers() => _db
      .collection('users')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (s) => [for (final d in s.docs) AppUserRecord.fromMap(d.id, d.data())],
      );

  @override
  Future<CreateUserResult> createUser({
    required String displayName,
    required String email,
    required AppRole role,
    String? phone,
  }) async {
    final res = await _functions.httpsCallable('adminCreateUser').call({
      'displayName': displayName,
      'email': email,
      'role': role.id,
      'phone': phone,
    });
    final data = Map<String, dynamic>.from(res.data as Map);
    return CreateUserResult(
      '${data['uid']}',
      data['passwordSetupLink'] as String?,
    );
  }

  @override
  Future<void> setRole(String uid, AppRole role) => _functions
      .httpsCallable('adminSetUserRole')
      .call({'uid': uid, 'role': role.id});

  @override
  Future<void> setActive(String uid, bool active) => _functions
      .httpsCallable('adminSetUserStatus')
      .call({'uid': uid, 'status': active ? 'active' : 'inactive'});
}

/// Demo-mode stand-in. Applies the same policy as the Cloud Functions but
/// creates no real accounts.
class MemoryUserAdminRepository implements UserAdminRepository {
  MemoryUserAdminRepository(this._db, this._caller);

  final MemoryDb _db;
  final ({AppRole role, String uid, PermissionMatrix perms}) Function() _caller;

  void _check(String action, {String? uid, AppRole? newRole}) {
    final c = _caller();
    final target = uid == null ? null : _db.get('users', uid);
    final denied = checkUserAdminAction(
      callerRole: c.role,
      callerUid: c.uid,
      callerPermissions: c.perms,
      action: action,
      targetUid: uid,
      targetCurrentRole: AppRole.fromId(target?['role'] as String?),
      newRole: newRole,
    );
    if (denied != null) throw ValidationException(denied);
  }

  @override
  Stream<List<AppUserRecord>> watchUsers() => _db
      .watch('users')
      .map(
        (rows) => [for (final r in rows) AppUserRecord.fromMap(r.key, r.value)]
          ..sort(
            (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
              a.createdAt ?? DateTime(0),
            ),
          ),
      );

  @override
  Future<CreateUserResult> createUser({
    required String displayName,
    required String email,
    required AppRole role,
    String? phone,
  }) async {
    _check(PermAction.create, newRole: role);
    final lower = email.trim().toLowerCase();
    if (_db.list('users').any((r) => r.value['email'] == lower)) {
      throw DuplicateValueException('A user with this email already exists.');
    }
    final uid = _db.newId();
    final now = DateTime.now();
    _db.put('users', uid, {
      'displayName': displayName.trim(),
      'email': lower,
      'role': role.id,
      'status': 'active',
      'phone': phone,
      'createdAt': now,
      'updatedAt': now,
      'createdBy': _db.actorUid,
    });
    _db.audit(
      action: 'create_user',
      module: Modules.users,
      collection: 'users',
      recordId: uid,
      recordLabel: lower,
      metadata: {'role': role.id},
    );
    return CreateUserResult(uid, null);
  }

  @override
  Future<void> setRole(String uid, AppRole role) async {
    _check(PermAction.edit, uid: uid, newRole: role);
    final d = _db.get('users', uid)!;
    _db.put('users', uid, {...d, 'role': role.id, 'updatedAt': DateTime.now()});
    _db.audit(
      action: 'change_role',
      module: Modules.users,
      collection: 'users',
      recordId: uid,
      recordLabel: d['email'] as String?,
      metadata: {'from': d['role'], 'to': role.id},
    );
  }

  @override
  Future<void> setActive(String uid, bool active) async {
    _check(PermAction.deactivate, uid: uid);
    final d = _db.get('users', uid)!;
    _db.put('users', uid, {
      ...d,
      'status': active ? 'active' : 'inactive',
      'updatedAt': DateTime.now(),
    });
    _db.audit(
      action: active ? 'activate_user' : 'deactivate_user',
      module: Modules.users,
      collection: 'users',
      recordId: uid,
      recordLabel: d['email'] as String?,
    );
  }
}
