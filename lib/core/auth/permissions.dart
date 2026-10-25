/// Roles, modules and actions used for authorisation.
///
/// The client uses these to decide what to show. The same model is enforced
/// server-side by `firestore.rules` and `functions/index.js`; the default
/// matrix below is mirrored in `functions/default_roles.json`.
library;

enum AppRole {
  superAdmin('super_admin', 'Super Admin'),
  admin('admin', 'Admin'),
  receptionist('receptionist', 'Receptionist'),
  doctor('doctor', 'Doctor'),
  labUser('lab_user', 'Lab User'),
  pharmacyUser('pharmacy_user', 'Medical/Pharmacy User'),
  nursingUser('nursing_user', 'IPD/Nursing User'),
  accountsUser('accounts_user', 'Accounts User');

  const AppRole(this.id, this.label);

  final String id;
  final String label;

  /// Roles that only a Super Admin may assign.
  bool get isPrivileged => this == superAdmin || this == admin;

  static AppRole? fromId(String? id) {
    for (final r in values) {
      if (r.id == id) return r;
    }
    return null;
  }
}

class PermAction {
  PermAction._();

  static const view = 'view';
  static const create = 'create';
  static const edit = 'edit';
  static const deactivate = 'deactivate';
  static const approve = 'approve';
  static const manage = 'manage';

  static const labels = {
    view: 'View',
    create: 'Create',
    edit: 'Edit',
    deactivate: 'Deactivate',
    approve: 'Approve',
    manage: 'Manage settings',
  };
}

/// A permission-controlled module and the actions that make sense for it.
class PermModule {
  const PermModule(this.id, this.label, this.actions);

  final String id;
  final String label;
  final List<String> actions;
}

class Modules {
  Modules._();

  static const dashboard = 'dashboard';
  static const departments = 'departments';
  static const doctors = 'doctors';
  static const users = 'users';
  static const opdCharges = 'opd_charges';
  static const labTests = 'lab_tests';
  static const medicines = 'medicines';
  static const wardsRoomsBeds = 'wards_rooms_beds';
  static const billingMasters = 'billing_masters';
  static const prescriptionTemplates = 'prescription_templates';
  static const roles = 'roles';
  static const numbering = 'numbering';
  static const hospitalProfile = 'hospital_profile';
  static const printSettings = 'print_settings';
  static const reports = 'reports';
  static const auditLogs = 'audit_logs';
  static const backup = 'backup';
  static const systemSettings = 'system_settings';

  static const _crud = [
    PermAction.view,
    PermAction.create,
    PermAction.edit,
    PermAction.deactivate,
  ];
  static const _settings = [PermAction.view, PermAction.manage];

  static const all = <PermModule>[
    PermModule(dashboard, 'Dashboard', [PermAction.view]),
    PermModule(departments, 'Departments', _crud),
    PermModule(doctors, 'Doctors', _crud),
    PermModule(users, 'Users', _crud),
    PermModule(opdCharges, 'OPD Charges', _crud),
    PermModule(labTests, 'Lab Tests', _crud),
    PermModule(medicines, 'Medicines', _crud),
    PermModule(wardsRoomsBeds, 'Wards, Rooms & Beds', _crud),
    PermModule(billingMasters, 'Billing Masters', [
      ..._crud,
      PermAction.approve,
    ]),
    PermModule(prescriptionTemplates, 'Prescription Templates', _crud),
    PermModule(roles, 'Roles & Permissions', _settings),
    PermModule(numbering, 'Numbering & Receipts', _settings),
    PermModule(hospitalProfile, 'Hospital Profile', _settings),
    PermModule(printSettings, 'Print Settings', _settings),
    PermModule(reports, 'Operational Reports', [PermAction.view]),
    PermModule(auditLogs, 'Audit Logs', [PermAction.view]),
    PermModule(backup, 'Backup & Recovery', _settings),
    PermModule(systemSettings, 'System Settings', _settings),
  ];

  static PermModule byId(String id) => all.firstWhere((m) => m.id == id);
}

typedef PermissionMatrix = Map<String, Set<String>>;

/// Default permissions per role, used to seed `roles/{roleId}` documents.
/// Super Admin is implicitly allowed everything and is not editable.
PermissionMatrix defaultPermissionsFor(AppRole role) {
  Set<String> crud() => {
    PermAction.view,
    PermAction.create,
    PermAction.edit,
    PermAction.deactivate,
  };
  const view = {PermAction.view};
  switch (role) {
    case AppRole.superAdmin:
      return {for (final m in Modules.all) m.id: m.actions.toSet()};
    case AppRole.admin:
      return {
        Modules.dashboard: view,
        Modules.departments: crud(),
        Modules.doctors: crud(),
        Modules.users: crud(),
        Modules.opdCharges: crud(),
        Modules.labTests: crud(),
        Modules.medicines: crud(),
        Modules.wardsRoomsBeds: crud(),
        Modules.billingMasters: {...crud(), PermAction.approve},
        Modules.prescriptionTemplates: crud(),
        Modules.roles: view,
        Modules.numbering: {PermAction.view, PermAction.manage},
        Modules.hospitalProfile: {PermAction.view, PermAction.manage},
        Modules.printSettings: {PermAction.view, PermAction.manage},
        Modules.reports: view,
        Modules.auditLogs: view,
        Modules.backup: view,
        Modules.systemSettings: {PermAction.view, PermAction.manage},
      };
    case AppRole.receptionist:
      return {
        Modules.dashboard: view,
        Modules.departments: view,
        Modules.doctors: view,
        Modules.opdCharges: view,
      };
    case AppRole.doctor:
      return {
        Modules.dashboard: view,
        Modules.departments: view,
        Modules.doctors: view,
        Modules.labTests: view,
        Modules.medicines: view,
        Modules.prescriptionTemplates: view,
      };
    case AppRole.labUser:
      return {Modules.dashboard: view, Modules.labTests: view};
    case AppRole.pharmacyUser:
      return {Modules.dashboard: view, Modules.medicines: view};
    case AppRole.nursingUser:
      return {Modules.dashboard: view, Modules.wardsRoomsBeds: view};
    case AppRole.accountsUser:
      return {
        Modules.dashboard: view,
        Modules.opdCharges: view,
        Modules.billingMasters: view,
        Modules.reports: view,
      };
  }
}

PermissionMatrix permissionsFromJson(Map<String, dynamic>? json) {
  if (json == null) return {};
  return {
    for (final e in json.entries)
      if (e.value is List) e.key: (e.value as List).map((a) => '$a').toSet(),
  };
}

Map<String, List<String>> permissionsToJson(PermissionMatrix m) => {
  for (final e in m.entries)
    if (e.value.isNotEmpty) e.key: (e.value.toList()..sort()),
};
