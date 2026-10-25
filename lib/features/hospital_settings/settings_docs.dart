import '../../core/auth/permissions.dart';
import '../../core/data/settings_repository.dart';

/// Singleton settings documents. Their IDs are fixed so every module reads
/// the same place.
const hospitalProfileDoc = SettingsDoc(
  'hospital_settings',
  'profile',
  Modules.hospitalProfile,
);
const printSettingsDoc = SettingsDoc(
  'print_settings',
  'default',
  Modules.printSettings,
);
const systemSettingsDoc = SettingsDoc(
  'system_settings',
  'general',
  Modules.systemSettings,
);
const backupConfigDoc = SettingsDoc(
  'system_settings',
  'backup',
  Modules.backup,
);

/// Document types with configurable numbering, `numbering_settings/{id}`.
const numberedDocTypes = <(String id, String label, String prefix)>[
  ('uhid', 'UHID (patient ID)', 'UHID'),
  ('opd_encounter', 'OPD encounter', 'OPD'),
  ('receipt', 'Receipt', 'RCPT'),
  ('invoice', 'Invoice / bill', 'INV'),
  ('ipd_admission', 'IPD admission', 'IPD'),
  ('lab_order', 'Lab order', 'LAB'),
  ('pharmacy_bill', 'Pharmacy bill', 'PH'),
];

SettingsDoc numberingDoc(String docType) =>
    SettingsDoc('numbering_settings', docType, Modules.numbering);
