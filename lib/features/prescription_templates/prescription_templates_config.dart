import '../../core/auth/permissions.dart';
import '../../core/data/master_entity.dart';

/// Template METADATA only. Clinical content (medicines, dosage, advice) is
/// edited by doctors in the future Prescription module; Security Rules
/// reject clinical fields written from the Admin Panel.
final prescriptionTemplatesConfig = MasterEntityConfig(
  collection: 'prescription_templates',
  module: Modules.prescriptionTemplates,
  title: 'Prescription Templates',
  singular: 'Template',
  subtitle: 'Template catalogue, ownership and sharing scope.',
  notice:
      'Only template metadata is managed here. Clinical template content and '
      'prescription confirmation belong to the Prescription module.',
  fields: [
    const FieldDef('name', 'Template name', required: true, searchable: true),
    const FieldDef(
      'description',
      'Description',
      type: FieldType.multiline,
      maxLength: 500,
      searchable: true,
    ),
    const FieldDef(
      'sharingScope',
      'Sharing scope',
      type: FieldType.select,
      required: true,
      filterable: true,
      options: [
        SelectOption('owner_only', 'Owner only'),
        SelectOption('department', 'Department'),
        SelectOption('all_doctors', 'All doctors'),
      ],
    ),
    FieldDef(
      'ownerDoctorId',
      'Owner doctor',
      type: FieldType.reference,
      refCollection: 'doctors',
      refLabelField: 'fullName',
      requiredWhen: (d) => d['sharingScope'] == 'owner_only',
      helper: 'Required for owner-only templates',
    ),
    FieldDef(
      'departmentId',
      'Department',
      type: FieldType.reference,
      refCollection: 'departments',
      requiredWhen: (d) => d['sharingScope'] == 'department',
      visibleWhen: (d) => d['sharingScope'] == 'department',
    ),
  ],
  uniqueRules: const [
    UniqueRule(
      ['name'],
      scopeField: 'ownerDoctorId',
      message: 'A template with this name already exists for this owner.',
    ),
  ],
);
