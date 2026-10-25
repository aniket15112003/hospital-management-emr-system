import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hes/app/router.dart';
import 'package:hes/core/auth/permissions.dart';
import 'package:hes/core/auth/session.dart';
import 'package:hes/core/auth/user_admin_policy.dart';
import 'package:hes/core/config/app_config.dart';
import 'package:hes/core/data/master_entity.dart';
import 'package:hes/core/data/master_repository.dart';
import 'package:hes/core/data/memory_db.dart';
import 'package:hes/core/utils/error_text.dart';
import 'package:hes/core/utils/normalize.dart';
import 'package:hes/core/utils/numbering.dart';
import 'package:hes/features/departments/departments_config.dart';
import 'package:hes/features/doctors/doctors_config.dart';
import 'package:hes/features/wards_rooms_beds/wards_rooms_beds_config.dart';

void main() {
  group('normalizeKey', () {
    test('trims, collapses whitespace and lower-cases', () {
      expect(normalizeKey('  General   Medicine '), 'general medicine');
      expect(normalizeKey('CARDIOLOGY'), normalizeKey('cardiology'));
      expect(normalizeKey(null), '');
    });

    test('unique keys are scoped', () {
      final a = roomsConfig.uniqueKeys({'roomNumber': '101', 'wardId': 'w1'});
      final b = roomsConfig.uniqueKeys({'roomNumber': '101', 'wardId': 'w2'});
      expect(a.intersection(b), isEmpty);
      final c = roomsConfig.uniqueKeys({'roomNumber': ' 101 ', 'wardId': 'w1'});
      expect(a, c);
    });
  });

  group('FieldDef validation', () {
    const email = FieldDef('email', 'Email', type: FieldType.email);
    const phone = FieldDef(
      'phone',
      'Phone',
      type: FieldType.phone,
      required: true,
    );
    const amount = FieldDef('amount', 'Amount', type: FieldType.number, min: 0);

    test('email/phone/number rules', () {
      expect(email.validate('x@y.com', {}), isNull);
      expect(email.validate('bad', {}), isNotNull);
      expect(email.validate(null, {}), isNull);
      expect(phone.validate(null, {}), contains('required'));
      expect(phone.validate('+91 98765-43210', {}), isNull);
      expect(phone.validate('12', {}), isNotNull);
      expect(amount.validate(-1, {}), isNotNull);
      expect(amount.validate(10.5, {}), isNull);
    });

    test('requiredWhen and visibleWhen', () {
      final f = FieldDef(
        'approverRole',
        'Approver',
        requiredWhen: (d) => d['requiresApproval'] == true,
        visibleWhen: (d) => d['requiresApproval'] == true,
      );
      expect(f.validate(null, {'requiresApproval': true}), isNotNull);
      expect(f.validate(null, {'requiresApproval': false}), isNull);
    });
  });

  group('MemoryMasterRepository', () {
    late MasterRepository repo;
    setUp(() => repo = MemoryMasterRepository(MemoryDb()));

    test('rejects duplicate names using the normalisation policy', () async {
      await repo.save(
        departmentsConfig,
        data: {'code': 'GM', 'name': 'General Medicine'},
      );
      expect(
        () => repo.save(
          departmentsConfig,
          data: {'code': 'GM2', 'name': '  general   medicine'},
        ),
        throwsA(isA<DuplicateValueException>()),
      );
    });

    test('allows an edit that keeps its own unique values', () async {
      final id = await repo.save(
        departmentsConfig,
        data: {'code': 'GM', 'name': 'General'},
      );
      await repo.save(
        departmentsConfig,
        id: id,
        data: {'code': 'GM', 'name': 'General', 'description': 'x'},
      );
      final rows = await repo.watch(departmentsConfig).first;
      expect(rows.single.data['description'], 'x');
    });

    test('deactivate and audit', () async {
      final db = MemoryDb();
      final r = MemoryMasterRepository(db);
      final id = await r.save(
        doctorsConfig,
        data: {'code': 'D1', 'fullName': 'Dr A'},
      );
      await r.setActive(doctorsConfig, id, false);
      expect((await r.watch(doctorsConfig).first).single.isActive, isFalse);
      final actions = db
          .list('audit_logs')
          .map((e) => e.value['action'])
          .toSet();
      expect(actions, containsAll(['create', 'deactivate']));
    });
  });

  group('user admin policy', () {
    final adminPerms = defaultPermissionsFor(AppRole.admin);

    test('nobody can change their own account', () {
      expect(
        checkUserAdminAction(
          callerRole: AppRole.superAdmin,
          callerUid: 'me',
          callerPermissions: const {},
          action: PermAction.edit,
          targetUid: 'me',
        ),
        isNotNull,
      );
    });

    test('admin cannot assign privileged roles or modify admins', () {
      expect(
        checkUserAdminAction(
          callerRole: AppRole.admin,
          callerUid: 'a',
          callerPermissions: adminPerms,
          action: PermAction.create,
          newRole: AppRole.superAdmin,
        ),
        isNotNull,
      );
      expect(
        checkUserAdminAction(
          callerRole: AppRole.admin,
          callerUid: 'a',
          callerPermissions: adminPerms,
          action: PermAction.edit,
          targetUid: 'b',
          targetCurrentRole: AppRole.admin,
          newRole: AppRole.doctor,
        ),
        isNotNull,
      );
      expect(
        checkUserAdminAction(
          callerRole: AppRole.admin,
          callerUid: 'a',
          callerPermissions: adminPerms,
          action: PermAction.edit,
          targetUid: 'b',
          targetCurrentRole: AppRole.receptionist,
          newRole: AppRole.doctor,
        ),
        isNull,
      );
    });

    test('roles without users permission are denied', () {
      expect(
        checkUserAdminAction(
          callerRole: AppRole.receptionist,
          callerUid: 'r',
          callerPermissions: defaultPermissionsFor(AppRole.receptionist),
          action: PermAction.create,
          newRole: AppRole.doctor,
        ),
        isNotNull,
      );
    });
  });

  group('numbering', () {
    test('formats with date and padding', () {
      const c = NumberFormatConfig(
        prefix: 'OPD',
        dateSegment: 'YYMM',
        padding: 5,
      );
      expect(
        formatDocumentNumber(c, 42, DateTime(2026, 3, 9)),
        'OPD-2603-00042',
      );
      const u = NumberFormatConfig(prefix: 'UHID', separator: '', padding: 4);
      expect(formatDocumentNumber(u, 7, DateTime(2026)), 'UHID0007');
    });

    test('periodic resets need a covering date segment', () {
      expect(validateResetPolicy('yearly', 'none'), isNotNull);
      expect(validateResetPolicy('yearly', 'YYYY'), isNull);
      expect(validateResetPolicy('daily', 'YYYYMM'), isNotNull);
      expect(validateResetPolicy('never', 'none'), isNull);
    });
  });

  group('router redirect', () {
    const active = AppSession(
      uid: 'u',
      displayName: 'U',
      email: 'u@x',
      role: AppRole.admin,
      status: 'active',
    );

    test('unconfigured goes to setup', () {
      expect(
        resolveRedirect(
          mode: BackendMode.unconfigured,
          session: const AsyncData(null),
          uri: Uri.parse('/users'),
        ),
        '/setup',
      );
    });

    test('signed out goes to login with return path', () {
      expect(
        resolveRedirect(
          mode: BackendMode.firebase,
          session: const AsyncData(null),
          uri: Uri.parse('/users'),
        ),
        '/login?from=%2Fusers',
      );
    });

    test('inactive user is blocked; active user leaves login', () {
      const inactive = AppSession(
        uid: 'u',
        displayName: 'U',
        email: '',
        role: AppRole.admin,
        status: 'inactive',
      );
      expect(
        resolveRedirect(
          mode: BackendMode.firebase,
          session: const AsyncData(inactive),
          uri: Uri.parse('/'),
        ),
        '/inactive',
      );
      expect(
        resolveRedirect(
          mode: BackendMode.firebase,
          session: const AsyncData(active),
          uri: Uri.parse('/login?from=/doctors'),
        ),
        '/doctors',
      );
      expect(
        resolveRedirect(
          mode: BackendMode.firebase,
          session: const AsyncData(active),
          uri: Uri.parse('/doctors'),
        ),
        isNull,
      );
    });
  });

  test('every role has a label and default matrix only uses known modules', () {
    final ids = Modules.all.map((m) => m.id).toSet();
    for (final r in AppRole.values) {
      final m = defaultPermissionsFor(r);
      expect(ids.containsAll(m.keys), isTrue, reason: r.id);
      for (final e in m.entries) {
        expect(
          Modules.byId(e.key).actions.toSet().containsAll(e.value),
          isTrue,
          reason: '${r.id}/${e.key}',
        );
      }
    }
    expect(AppRole.values, hasLength(8));
  });
}
