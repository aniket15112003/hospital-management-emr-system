import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/users/user_repository.dart';
import '../auth/roles_repository.dart';
import '../auth/session.dart';
import '../config/app_config.dart';
import 'audit_repository.dart';
import 'demo_seed.dart';
import 'master_repository.dart';
import 'memory_db.dart';
import 'settings_repository.dart';

class BackendState {
  const BackendState(this.mode, {this.error});
  final BackendMode mode;

  /// Why Firebase could not be initialised, when [mode] is unconfigured.
  final String? error;
}

/// Overridden in `main()` with the result of [resolveBackendMode].
final initialBackendProvider = Provider<BackendState>(
  (ref) => const BackendState(BackendMode.unconfigured),
);

class BackendNotifier extends Notifier<BackendState> {
  @override
  BackendState build() => ref.watch(initialBackendProvider);

  /// Explicitly switches an unconfigured app into demo mode.
  void enterDemoMode() {
    if (state.mode == BackendMode.unconfigured && AppConfig.demoModeAllowed) {
      state = const BackendState(BackendMode.demo);
    }
  }
}

final backendProvider = NotifierProvider<BackendNotifier, BackendState>(
  BackendNotifier.new,
);

final backendModeProvider = Provider<BackendMode>(
  (ref) => ref.watch(backendProvider).mode,
);

final isDemoProvider = Provider<bool>(
  (ref) => ref.watch(backendModeProvider) == BackendMode.demo,
);

final memoryDbProvider = Provider<MemoryDb>((ref) => seedDemoData(MemoryDb()));

bool _firebase(Ref ref) =>
    ref.watch(backendModeProvider) == BackendMode.firebase;

final masterRepositoryProvider = Provider<MasterRepository>(
  (ref) => _firebase(ref)
      ? FirestoreMasterRepository(
          FirebaseFirestore.instance,
          FirebaseAuth.instance,
        )
      : MemoryMasterRepository(ref.watch(memoryDbProvider)),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => _firebase(ref)
      ? FirestoreSettingsRepository(
          FirebaseFirestore.instance,
          FirebaseAuth.instance,
        )
      : MemorySettingsRepository(ref.watch(memoryDbProvider)),
);

final auditRepositoryProvider = Provider<AuditRepository>(
  (ref) => _firebase(ref)
      ? FirestoreAuditRepository(FirebaseFirestore.instance)
      : MemoryAuditRepository(ref.watch(memoryDbProvider)),
);

final rolesRepositoryProvider = Provider<RolesRepository>(
  (ref) => _firebase(ref)
      ? FirestoreRolesRepository(
          FirebaseFirestore.instance,
          FirebaseAuth.instance,
        )
      : MemoryRolesRepository(ref.watch(memoryDbProvider)),
);

final userAdminRepositoryProvider = Provider<UserAdminRepository>((ref) {
  if (_firebase(ref)) {
    return FirebaseUserAdminRepository(
      FirebaseFirestore.instance,
      FirebaseFunctions.instanceFor(region: AppConfig.functionsRegion),
    );
  }
  return MemoryUserAdminRepository(ref.watch(memoryDbProvider), () {
    final s = ref.read(demoSessionProvider);
    return (
      role: s.role!,
      uid: s.uid,
      perms: ref.read(currentPermissionsProvider),
    );
  });
});
