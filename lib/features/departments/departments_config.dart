import '../../core/auth/permissions.dart';
import '../../core/data/master_entity.dart';

const departmentsConfig = MasterEntityConfig(
  collection: 'departments',
  module: Modules.departments,
  title: 'Departments',
  singular: 'Department',
  subtitle: 'Clinical and administrative departments of the hospital.',
  fields: [
    FieldDef(
      'code',
      'Department ID',
      required: true,
      uppercase: true,
      maxLength: 20,
      searchable: true,
      helper: 'Short unique code, e.g. CARD',
    ),
    FieldDef('name', 'Department name', required: true, searchable: true),
    FieldDef(
      'description',
      'Description',
      type: FieldType.multiline,
      maxLength: 500,
      searchable: true,
    ),
  ],
  uniqueRules: [
    UniqueRule(['code'], message: 'A department with this ID already exists.'),
    UniqueRule(
      ['name'],
      message:
          'A department with this name already exists (names are compared '
          'ignoring case and extra spaces).',
    ),
  ],
);
