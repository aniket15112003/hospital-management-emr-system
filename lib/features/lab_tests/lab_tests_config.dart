import '../../core/auth/permissions.dart';
import '../../core/data/master_entity.dart';

const labTestsConfig = MasterEntityConfig(
  collection: 'lab_tests',
  module: Modules.labTests,
  title: 'Lab Tests',
  singular: 'Lab Test',
  subtitle: 'Laboratory test catalogue.',
  notice:
      'The laboratory module is optional. Defining tests here never makes a '
      'lab order mandatory for a prescription.',
  fields: [
    FieldDef(
      'code',
      'Test ID',
      required: true,
      uppercase: true,
      maxLength: 20,
      searchable: true,
    ),
    FieldDef('name', 'Test name', required: true, searchable: true),
    FieldDef(
      'category',
      'Category',
      type: FieldType.select,
      required: true,
      filterable: true,
      options: [
        SelectOption('haematology', 'Haematology'),
        SelectOption('biochemistry', 'Biochemistry'),
        SelectOption('microbiology', 'Microbiology'),
        SelectOption('pathology', 'Pathology'),
        SelectOption('serology', 'Serology'),
        SelectOption('radiology', 'Radiology'),
        SelectOption('other', 'Other'),
      ],
    ),
    FieldDef(
      'sampleType',
      'Sample type',
      type: FieldType.select,
      inTable: false,
      options: [
        SelectOption('blood', 'Blood'),
        SelectOption('urine', 'Urine'),
        SelectOption('stool', 'Stool'),
        SelectOption('swab', 'Swab'),
        SelectOption('tissue', 'Tissue'),
        SelectOption('none', 'Not applicable'),
      ],
    ),
    FieldDef('unit', 'Unit', maxLength: 30, helper: 'e.g. mg/dL'),
    FieldDef(
      'referenceRange',
      'Reference range',
      maxLength: 200,
      helper: 'e.g. 70–110 (fasting)',
    ),
    FieldDef(
      'charge',
      'Charge',
      type: FieldType.number,
      required: true,
      min: 0,
      money: true,
    ),
    FieldDef(
      'turnaroundHours',
      'Turnaround (hours)',
      type: FieldType.integer,
      min: 0,
      inTable: false,
    ),
  ],
  uniqueRules: [
    UniqueRule(['code'], message: 'A test with this ID already exists.'),
    UniqueRule(['name'], message: 'A test with this name already exists.'),
  ],
);
