# Admin Panel — Setup, Data Model and Security

This is module 1 of the Hospital Management & EMR system. It covers the
dashboard, master data, users/roles, settings, reports framework, audit
viewer and backup status. The Receptionist, Doctor EMR, Prescription,
Pharmacy, Lab, IPD and Billing workflows are **not** part of it.

## 1. Running the app

| Mode | How | Data |
|---|---|---|
| Firebase | Provide Firebase options (below) | Firestore / Auth / Functions |
| Demo | `flutter run --dart-define=DEMO_MODE=true`, or the button on the setup screen (debug builds only) | In-memory sample data, nothing saved, banner always shown |
| Unconfigured | No Firebase options | Setup instructions screen |

### Firebase configuration

No credentials are committed. Choose one:

1. **FlutterFire CLI**: `dart pub global activate flutterfire_cli` then
   `flutterfire configure`. This generates `lib/firebase_options.dart`;
   change `resolveBackendMode()` in `lib/core/config/app_config.dart` to call
   `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`.
2. **Build-time defines**: copy `firebase.env.example.json` to
   `firebase.env.json` (git-ignored), fill in the web-app values from the
   Firebase console, and run
   `flutter run -d chrome --dart-define-from-file=firebase.env.json`.
3. **Android/iOS native files**: `google-services.json` /
   `GoogleService-Info.plist` are picked up automatically.

Then, in the Firebase console: enable **Email/Password** sign-in, create a
**Firestore** database, and (optional) **Storage** for the logo.

### Deploy backend

```bash
firebase use <project-id>
cd functions && npm install && cd ..
firebase deploy --only firestore:rules,firestore:indexes,storage,functions
```

Cloud Functions require the Blaze plan. The region is `asia-south1`; if you
change it, change `FUNCTIONS_REGION` (dart-define) too. For web, configure
CORS on the Storage bucket so the logo `Image.network` loads.

### Create the first Super Admin

```bash
gcloud auth application-default login
cd functions
node scripts/bootstrap-super-admin.js <project-id> admin@hospital.example "Full Name"
```

This sets the `super_admin` claim, writes `users/{uid}`, seeds `roles/*`
from `default_roles.json` and prints a one-time password setup link.
`default_roles.json` is generated from the Dart matrix:
`dart run tool/export_default_roles.dart`.

## 2. Firestore structure

### Conventions

* **Document IDs**: Firestore auto IDs for master records. The human-facing
  identifier (Department ID, Doctor ID, …) is the `code` field, unique per
  collection. Settings use fixed IDs (`hospital_settings/profile`, …).
* **Timestamps**: `createdAt`, `updatedAt` are server timestamps; rules
  require `updatedAt == request.time`. `createdBy`, `updatedBy` hold the
  actor UID and must equal the caller.
* **Status**: `status` is `active` | `inactive`. Records are never deleted;
  deactivation hides them from selection lists. Rules deny deletes.
* **References**: store the referenced ID (`departmentId`) plus a
  denormalised label (`departmentName`) for display. Rules require the
  referenced record to be active when the reference is set or changed.
* **Uniqueness**: values are normalised (trim → collapse whitespace →
  lower-case; see `lib/core/utils/normalize.dart`). A reservation document
  `unique_keys/{collection|field|scope|value}` is written in the same
  transaction as the record. Because rules allow only *create* (not update)
  of a reservation, a concurrent duplicate fails atomically.

### Collections

| Collection | Key fields | Notes |
|---|---|---|
| `users/{uid}` | displayName, email, phone, role, status, createdAt | Written only by Cloud Functions. No passwords. |
| `roles/{roleId}` | name, permissions `{module: [actions]}` | Super Admin only; `super_admin` has no doc (implicit all). |
| `departments` | code, name, description | Unique: code, name |
| `doctors` | code, fullName, departmentId/Name, qualification, specialization, phone, email, consultationFee, consultationMinutes, followUpValidityDays | Department must be active |
| `opd_charges` | code, name, serviceType, departmentId/Name?, amount, description | Unique name per department |
| `lab_tests` | code, name, category, sampleType, unit, referenceRange, charge, turnaroundHours | Lab is optional; never mandatory for prescriptions |
| `medicines` | code, name, genericName, strength, dosageForm, unit, salePrice, taxPercent, hsnCode, lowStockThreshold | Unique: code; name+strength+form. No stock here. |
| `wards` | code, name, wardType, floor, dailyCharge | |
| `rooms` | wardId/Name, roomNumber, roomType, notes | Room number unique per ward |
| `beds` | roomId/Name, wardId/Name (derived), bedNumber, bedStatus, dailyChargeOverride | Bed number unique per room. `occupied` is reserved for the IPD module. |
| `billing_masters` | type (`charge_head`, `payment_method`, `discount_rule`), code, name, … | Unique per type |
| `prescription_templates` | name, description, sharingScope, ownerDoctorId/Name, departmentId/Name | Metadata only; rules reject clinical fields |
| `hospital_settings/profile` | name, address…, phone, email, logoUrl, … | |
| `numbering_settings/{docType}` | prefix, separator, dateSegment, padding, resetPolicy, startAt | Format only |
| `counters/{docType}` | value, period | Backend only (`allocateDocumentNumber`) |
| `print_settings/default` | showLogo, header/footer text, paper sizes, margin, fontScale, receiptCopies | |
| `system_settings/general` | timezone, currency, dateFormat, sessionTimeoutMinutes, labModuleEnabled, … | |
| `system_settings/backup` | retentionDays, schedule, exportLocation, recovery notes | No credentials |
| `backup_runs` | startedAt, completedAt, status, type, location | Written by backup automation only |
| `audit_logs` | timestamp, actorUid, actorName, action, module, collection, recordId, recordLabel, result, metadata | Backend only; field names, never values |
| `unique_keys` | collection, recordId, createdBy | Uniqueness reservations |

### Indexes

`firestore.indexes.json`: `audit_logs (module ↑, timestamp ↓)` for the
filtered audit viewer, plus indexes for the future dashboard queries on
`lab_orders`, `pharmacy_prescriptions` and `payments`.

## 3. Authorisation

* Role = Firebase Auth custom claim `role`, set only by Cloud Functions.
* Every rule requires an `active` `users/{uid}` profile.
* Module permissions: `roles/{role}.permissions[module]` contains the action
  (`view`, `create`, `edit`, `deactivate`, `approve`, `manage`).
* Edits need `edit`; status toggles need `deactivate` and may change nothing
  else; settings need `manage`.
* Users: nobody can change their own role/status; only Super Admin can
  assign or modify `admin`/`super_admin` (enforced in `functions/index.js`,
  mirrored in `lib/core/auth/user_admin_policy.dart` for the UI).
* Master/reference data is readable by any active staff member, since
  operational modules need it. Admin Panel pages additionally check `view`.
* Collections not in `firestore.rules` are denied — future modules must
  add their own rules.

## 4. Audit

`functions/index.js` has `onDocumentWritten` triggers for every master and
settings collection plus `roles`. User-management functions write their own
entries, including **denied** attempts. Clients cannot write `audit_logs`.

## 5. Dashboard data contracts for future modules

Flip the flag in `implementedSources`
(`lib/features/admin_dashboard/dashboard_repository.dart`) once a module
writes these:

| Metric | Collection | Fields used |
|---|---|---|
| Registrations today | `patients` | `registeredAt` |
| OPD encounters / queue / recent | `opd_encounters` | `encounterAt`, `encounterNumber`, `patientName`, `doctorId`, `doctorName`, `departmentName`, `queueStatus` (`waiting`, `in_consultation`, `completed`) |
| Pending lab orders | `lab_orders` | `status` (`ordered`, `sample_collected`, `in_progress`), `orderedAt`, `orderNumber`, `patientName`, `testSummary` |
| Pending prescriptions | `pharmacy_prescriptions` | `status` (`pending`, `partially_dispensed`), `createdAt`, `prescriptionNumber`, `patientName`, `doctorName` |
| Collection today | `payments` | `receivedAt`, `status == completed`, `amount`, `paymentMethodName` |
| Low stock | `medicine_stock` | `belowThreshold`, `medicineName`, `quantity`, `threshold` |

## 6. Backup & recovery (not configured by default)

Firebase does **not** back this project up automatically. Recommended:

```bash
gcloud firestore backups schedules create --database='(default)' \
  --recurrence=daily --retention=14d
# and/or enable point-in-time recovery
gcloud firestore databases update --database='(default)' --enable-pitr
```

Have the backup job (e.g. a scheduled function or Cloud Workflow) append a
document to `backup_runs` (`startedAt`, `completedAt`, `status`,
`type`, `location`). The Admin Panel shows "Not configured" until runs exist.
Restores are operator-only (`gcloud firestore backups restore` /
`gcloud firestore import`), ideally into a separate database first.
