import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../data/providers.dart';
import 'permissions.dart';
import 'roles_repository.dart';

/// The signed-in user as seen by the Admin Panel.
class AppSession {
  const AppSession({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.role,
    required this.status,
  });

  final String uid;
  final String displayName;
  final String email;

  /// Role from the Firebase Auth custom claim (what Security Rules see).
  final AppRole? role;

  /// `active`, `inactive`, or `unprovisioned` (no `users/{uid}` profile).
  final String status;

  bool get isActive => status == 'active' && role != null;

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    return parts.take(2).map((p) => p.isEmpty ? '' : p[0]).join().toUpperCase();
  }
}

/// Demo-mode session; the role can be switched from the profile menu to
/// preview what other roles can see.
class DemoSessionNotifier extends Notifier<AppSession> {
  @override
  AppSession build() => const AppSession(
    uid: 'demo-super-admin',
    displayName: 'Demo Administrator',
    email: 'demo@example.invalid',
    role: AppRole.superAdmin,
    status: 'active',
  );

  void switchRole(AppRole role) {
    state = AppSession(
      uid: state.uid,
      displayName: state.displayName,
      email: state.email,
      role: role,
      status: 'active',
    );
    ref.read(memoryDbProvider).actorName =
        '${state.displayName} (${role.label})';
  }
}

final demoSessionProvider = NotifierProvider<DemoSessionNotifier, AppSession>(
  DemoSessionNotifier.new,
);

final sessionProvider = StreamProvider<AppSession?>((ref) {
  switch (ref.watch(backendModeProvider)) {
    case BackendMode.unconfigured:
      return Stream.value(null);
    case BackendMode.demo:
      return Stream.value(ref.watch(demoSessionProvider));
    case BackendMode.firebase:
      return _firebaseSession();
  }
});

Stream<AppSession?> _firebaseSession() {
  return FirebaseAuth.instance.authStateChanges().asyncExpand((user) {
    if (user == null) return Stream<AppSession?>.value(null);
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .asyncMap((doc) async {
          final data = doc.data();
          var token = await user.getIdTokenResult();
          // A role change by an admin updates the profile first; refresh the
          // token so the custom claim (used by Security Rules) catches up.
          if (data != null && token.claims?['role'] != data['role']) {
            token = await user.getIdTokenResult(true);
          }
          return AppSession(
            uid: user.uid,
            displayName:
                '${data?['displayName'] ?? user.displayName ?? user.email ?? 'User'}',
            email: user.email ?? '',
            role: AppRole.fromId(token.claims?['role'] as String?),
            status: data == null
                ? 'unprovisioned'
                : '${data['status'] ?? 'inactive'}',
          );
        });
  });
}

final rolesProvider = StreamProvider<Map<AppRole, RoleDefinition>>(
  (ref) => ref.watch(rolesRepositoryProvider).watch(),
);

/// Effective permissions of the current user.
final currentPermissionsProvider = Provider<PermissionMatrix>((ref) {
  final session = ref.watch(sessionProvider).value;
  final role = session?.role;
  if (session == null || !session.isActive || role == null) return {};
  if (role == AppRole.superAdmin) return defaultPermissionsFor(role);
  final roles = ref.watch(rolesProvider).value;
  final def = roles?[role];
  // A role without a stored document has no server-side permissions.
  if (def == null || !def.stored) return {};
  return def.permissions;
});

/// Convenience check usable in widgets: `ref.watch(canProvider((m, a)))`.
final canProvider = Provider.family<bool, (String, String)>((ref, args) {
  final perms = ref.watch(currentPermissionsProvider);
  return perms[args.$1]?.contains(args.$2) ?? false;
});
