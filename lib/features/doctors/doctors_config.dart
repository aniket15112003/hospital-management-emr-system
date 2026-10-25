import '../../core/auth/permissions.dart';
import '../../core/data/master_entity.dart';

const doctorsConfig = MasterEntityConfig(
  collection: 'doctors',
  module: Modules.doctors,
  title: 'Doctors',
  singular: 'Doctor',
  subtitle: 'Doctor profiles, department assignment and consultation setup.',
  notice:
      'Only active departments can be assigned. Linking a doctor to a login '
      'account is done from Users.',
  fields: [
    FieldDef(
      'code',
      'Doctor ID',
      required: true,
      uppercase: true,
      maxLength: 20,
      searchable: true,
    ),
    FieldDef('fullName', 'Full name', required: true, searchable: true),
    FieldDef(
      'departmentId',
      'Department',
      type: FieldType.reference,
      refCollection: 'departments',
      required: true,
      filterable: true,
    ),
    FieldDef('qualification', 'Qualification', required: true, inTable: false),
    FieldDef('specialization', 'Specialization', searchable: true),
    FieldDef('phone', 'Phone', type: FieldType.phone, required: true),
    FieldDef('email', 'Email', type: FieldType.email, inTable: false),
    FieldDef(
      'consultationFee',
      'Consultation fee',
      type: FieldType.number,
      min: 0,
      money: true,
    ),
    FieldDef(
      'consultationMinutes',
      'Avg. consultation (min)',
      type: FieldType.integer,
      min: 1,
      inTable: false,
    ),
    FieldDef(
      'followUpValidityDays',
      'Follow-up validity (days)',
      type: FieldType.integer,
      min: 0,
      inTable: false,
    ),
  ],
  uniqueRules: [
    UniqueRule(['code'], message: 'A doctor with this ID already exists.'),
  ],
);
