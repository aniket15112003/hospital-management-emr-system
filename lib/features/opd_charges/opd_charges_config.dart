import '../../core/auth/permissions.dart';
import '../../core/data/master_entity.dart';

const opdChargesConfig = MasterEntityConfig(
  collection: 'opd_charges',
  module: Modules.opdCharges,
  title: 'OPD Charges',
  singular: 'OPD Charge',
  subtitle: 'Charge definitions used by OPD registration and billing.',
  fields: [
    FieldDef(
      'code',
      'Charge ID',
      required: true,
      uppercase: true,
      maxLength: 20,
      searchable: true,
    ),
    FieldDef('name', 'Charge name', required: true, searchable: true),
    FieldDef(
      'serviceType',
      'Service type',
      type: FieldType.select,
      required: true,
      filterable: true,
      options: [
        SelectOption('registration', 'Registration'),
        SelectOption('consultation', 'Consultation'),
        SelectOption('follow_up', 'Follow-up'),
        SelectOption('procedure', 'Procedure'),
        SelectOption('other', 'Other'),
      ],
    ),
    FieldDef(
      'departmentId',
      'Department',
      type: FieldType.reference,
      refCollection: 'departments',
      filterable: true,
      helper: 'Leave empty for hospital-wide charges',
    ),
    FieldDef(
      'amount',
      'Amount',
      type: FieldType.number,
      required: true,
      min: 0,
      money: true,
    ),
    FieldDef(
      'description',
      'Description',
      type: FieldType.multiline,
      maxLength: 500,
      inTable: false,
    ),
  ],
  uniqueRules: [
    UniqueRule(['code'], message: 'A charge with this ID already exists.'),
    UniqueRule(
      ['name'],
      scopeField: 'departmentId',
      message: 'A charge with this name already exists for this department.',
    ),
  ],
);
