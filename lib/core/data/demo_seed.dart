import '../auth/permissions.dart';
import 'memory_db.dart';

/// Sample data for explicit demo mode only. Never used with Firebase.
MemoryDb seedDemoData(MemoryDb db) {
  final now = DateTime.now();
  DateTime ago(int days, [int hours = 0]) =>
      now.subtract(Duration(days: days, hours: hours));
  Map<String, dynamic> meta(int days) => {
    'status': 'active',
    'createdAt': ago(days + 1),
    'updatedAt': ago(days),
    'createdBy': db.actorUid,
    'updatedBy': db.actorUid,
  };

  void dep(String id, String code, String name, String desc, int d) => db.put(
    'departments',
    id,
    {...meta(d), 'code': code, 'name': name, 'description': desc},
  );
  dep('dep-gm', 'GM', 'General Medicine', 'Adult general medicine OPD', 9);
  dep('dep-card', 'CARD', 'Cardiology', 'Heart and vascular care', 8);
  dep('dep-ortho', 'ORTH', 'Orthopaedics', 'Bones, joints and trauma', 7);
  dep('dep-paed', 'PAED', 'Paediatrics', 'Child health', 6);

  void doc(
    String id,
    String code,
    String name,
    String depId,
    String depName,
    String spec,
    num fee,
  ) => db.put('doctors', id, {
    ...meta(5),
    'code': code,
    'fullName': name,
    'departmentId': depId,
    'departmentName': depName,
    'qualification': 'MBBS, MD',
    'specialization': spec,
    'phone': '9800000000',
    'consultationFee': fee,
    'consultationMinutes': 10,
    'followUpValidityDays': 7,
  });
  doc(
    'doc-1',
    'DR001',
    'Dr. Asha Rao',
    'dep-gm',
    'General Medicine',
    'Internal medicine',
    500,
  );
  doc(
    'doc-2',
    'DR002',
    'Dr. Vikram Shah',
    'dep-card',
    'Cardiology',
    'Interventional cardiology',
    800,
  );
  doc(
    'doc-3',
    'DR003',
    'Dr. Meera Iyer',
    'dep-ortho',
    'Orthopaedics',
    'Joint replacement',
    700,
  );
  doc(
    'doc-4',
    'DR004',
    'Dr. Karan Mehta',
    'dep-paed',
    'Paediatrics',
    'Neonatology',
    600,
  );

  db.put('opd_charges', 'chg-1', {
    ...meta(4),
    'code': 'REG',
    'name': 'New registration',
    'serviceType': 'registration',
    'amount': 100,
  });
  db.put('opd_charges', 'chg-2', {
    ...meta(4),
    'code': 'CONS-GM',
    'name': 'Consultation',
    'serviceType': 'consultation',
    'departmentId': 'dep-gm',
    'departmentName': 'General Medicine',
    'amount': 500,
  });
  db.put('opd_charges', 'chg-3', {
    ...meta(4),
    'code': 'FU-GM',
    'name': 'Follow-up',
    'serviceType': 'follow_up',
    'departmentId': 'dep-gm',
    'departmentName': 'General Medicine',
    'amount': 250,
  });

  db.put('lab_tests', 'lab-1', {
    ...meta(3),
    'code': 'CBC',
    'name': 'Complete Blood Count',
    'category': 'haematology',
    'sampleType': 'blood',
    'unit': '',
    'referenceRange': 'See report',
    'charge': 350,
    'turnaroundHours': 6,
  });
  db.put('lab_tests', 'lab-2', {
    ...meta(3),
    'code': 'FBS',
    'name': 'Fasting Blood Sugar',
    'category': 'biochemistry',
    'sampleType': 'blood',
    'unit': 'mg/dL',
    'referenceRange': '70–110',
    'charge': 120,
    'turnaroundHours': 4,
  });
  db.put('lab_tests', 'lab-3', {
    ...meta(3),
    'code': 'URM',
    'name': 'Urine Routine',
    'category': 'pathology',
    'sampleType': 'urine',
    'unit': '',
    'referenceRange': 'See report',
    'charge': 150,
    'turnaroundHours': 4,
  });

  void med(
    String id,
    String code,
    String name,
    String strength,
    String form,
    String unit,
    num price,
    int low,
  ) => db.put('medicines', id, {
    ...meta(2),
    'code': code,
    'name': name,
    'strength': strength,
    'dosageForm': form,
    'unit': unit,
    'salePrice': price,
    'taxPercent': 12,
    'lowStockThreshold': low,
  });
  med('med-1', 'PCM500', 'Paracetamol', '500 mg', 'tablet', 'strip', 20, 50);
  med('med-2', 'AMX250', 'Amoxicillin', '250 mg', 'capsule', 'strip', 65, 30);
  med('med-3', 'ORS', 'ORS Powder', '21 g', 'other', 'piece', 22, 40);
  med(
    'med-4',
    'CTZ',
    'Cetirizine Syrup',
    '5 mg/5 ml',
    'syrup',
    'bottle',
    58,
    20,
  );

  db.put('wards', 'ward-g', {
    ...meta(6),
    'code': 'GW1',
    'name': 'General Ward 1',
    'wardType': 'general',
    'floor': '1',
    'dailyCharge': 1200,
  });
  db.put('wards', 'ward-icu', {
    ...meta(6),
    'code': 'ICU',
    'name': 'Intensive Care Unit',
    'wardType': 'icu',
    'floor': '2',
    'dailyCharge': 6000,
  });
  db.put('rooms', 'room-101', {
    ...meta(6),
    'wardId': 'ward-g',
    'wardName': 'General Ward 1',
    'roomNumber': '101',
    'roomType': 'shared',
  });
  db.put('rooms', 'room-102', {
    ...meta(6),
    'wardId': 'ward-g',
    'wardName': 'General Ward 1',
    'roomNumber': '102',
    'roomType': 'shared',
  });
  db.put('rooms', 'room-icu1', {
    ...meta(6),
    'wardId': 'ward-icu',
    'wardName': 'Intensive Care Unit',
    'roomNumber': 'ICU-A',
    'roomType': 'isolation',
  });
  const beds = [
    (
      'room-101',
      '101',
      'ward-g',
      'General Ward 1',
      ['available', 'occupied', 'occupied', 'cleaning'],
    ),
    (
      'room-102',
      '102',
      'ward-g',
      'General Ward 1',
      ['available', 'available', 'maintenance'],
    ),
    (
      'room-icu1',
      'ICU-A',
      'ward-icu',
      'Intensive Care Unit',
      ['occupied', 'reserved', 'available'],
    ),
  ];
  for (final b in beds) {
    for (var i = 0; i < b.$5.length; i++) {
      db.put('beds', '${b.$1}-$i', {
        ...meta(5),
        'roomId': b.$1,
        'roomName': b.$2,
        'wardId': b.$3,
        'wardName': b.$4,
        'bedNumber': '${b.$2}-${String.fromCharCode(65 + i)}',
        'bedStatus': b.$5[i],
      });
    }
  }

  db.put('billing_masters', 'bm-1', {
    ...meta(4),
    'type': 'charge_head',
    'code': 'CONS',
    'name': 'Consultation',
    'category': 'opd',
    'defaultAmount': 500,
    'taxPercent': 0,
  });
  db.put('billing_masters', 'bm-2', {
    ...meta(4),
    'type': 'charge_head',
    'code': 'BED',
    'name': 'Bed charges',
    'category': 'ipd',
    'taxPercent': 0,
  });
  db.put('billing_masters', 'bm-3', {
    ...meta(4),
    'type': 'payment_method',
    'code': 'CASH',
    'name': 'Cash',
    'requiresReference': false,
  });
  db.put('billing_masters', 'bm-4', {
    ...meta(4),
    'type': 'payment_method',
    'code': 'UPI',
    'name': 'UPI',
    'requiresReference': true,
  });
  db.put('billing_masters', 'bm-5', {
    ...meta(4),
    'type': 'discount_rule',
    'code': 'STAFF',
    'name': 'Staff discount',
    'discountType': 'percent',
    'value': 20,
    'requiresApproval': true,
    'approverRole': 'admin',
  });

  db.put('prescription_templates', 'tpl-1', {
    ...meta(3),
    'name': 'Viral fever (adult)',
    'description': 'Common OPD template',
    'sharingScope': 'all_doctors',
  });
  db.put('prescription_templates', 'tpl-2', {
    ...meta(3),
    'name': 'Post-op knee',
    'description': 'Orthopaedic follow-up',
    'sharingScope': 'owner_only',
    'ownerDoctorId': 'doc-3',
    'ownerDoctorName': 'Dr. Meera Iyer',
  });

  void user(
    String uid,
    String name,
    String email,
    AppRole role,
    String status,
    int d,
  ) => db.put('users', uid, {
    'displayName': name,
    'email': email,
    'role': role.id,
    'status': status,
    'createdAt': ago(d),
    'updatedAt': ago(d),
  });
  user(
    db.actorUid,
    'Demo Administrator',
    'demo@example.invalid',
    AppRole.superAdmin,
    'active',
    30,
  );
  user(
    'u-2',
    'Priya Nair',
    'priya@example.invalid',
    AppRole.admin,
    'active',
    20,
  );
  user(
    'u-3',
    'Rahul Verma',
    'rahul@example.invalid',
    AppRole.receptionist,
    'active',
    15,
  );
  user(
    'u-4',
    'Dr. Asha Rao',
    'asha@example.invalid',
    AppRole.doctor,
    'active',
    12,
  );
  user(
    'u-5',
    'Sunil Das',
    'sunil@example.invalid',
    AppRole.accountsUser,
    'inactive',
    10,
  );

  for (final r in AppRole.values) {
    if (r == AppRole.superAdmin) continue;
    db.put('roles', r.id, {
      'name': r.label,
      'permissions': permissionsToJson(defaultPermissionsFor(r)),
    });
  }

  db.put('hospital_settings', 'profile', {
    'name': 'Demo Multispeciality Hospital',
    'addressLine1': '12 Example Road',
    'city': 'Pune',
    'state': 'Maharashtra',
    'postalCode': '411001',
    'phone': '02000000000',
    'email': 'info@example.invalid',
  });

  db.audit(
    action: 'create',
    module: Modules.departments,
    collection: 'departments',
    recordId: 'dep-paed',
    recordLabel: 'Paediatrics',
  );
  db.audit(
    action: 'create_user',
    module: Modules.users,
    collection: 'users',
    recordId: 'u-5',
    recordLabel: 'sunil@example.invalid',
    metadata: {'role': 'accounts_user'},
  );
  db.audit(
    action: 'deactivate_user',
    module: Modules.users,
    collection: 'users',
    recordId: 'u-5',
    recordLabel: 'sunil@example.invalid',
  );
  return db;
}
