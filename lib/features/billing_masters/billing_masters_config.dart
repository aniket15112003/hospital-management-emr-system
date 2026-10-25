import '../../core/auth/permissions.dart';
import '../../core/data/master_entity.dart';

/// All billing masters share the `billing_masters` collection and are told
/// apart by `type`. Uniqueness is scoped by type.
const _codeField = FieldDef(
  'code',
  'Code',
  required: true,
  uppercase: true,
  maxLength: 20,
  searchable: true,
);
const _nameField = FieldDef('name', 'Name', required: true, searchable: true);
const _descField = FieldDef(
  'description',
  'Description',
  type: FieldType.multiline,
  maxLength: 500,
  inTable: false,
);

List<UniqueRule> _rules(String what) => [
  UniqueRule(
    ['code'],
    scopeField: 'type',
    message: 'A $what with this code already exists.',
  ),
  UniqueRule(
    ['name'],
    scopeField: 'type',
    message: 'A $what with this name already exists.',
  ),
];

final chargeHeadsConfig = MasterEntityConfig(
  collection: 'billing_masters',
  module: Modules.billingMasters,
  title: 'Charge Heads',
  singular: 'Charge Head',
  fixedValues: const {'type': 'charge_head'},
  fields: const [
    _codeField,
    _nameField,
    FieldDef(
      'category',
      'Category',
      type: FieldType.select,
      required: true,
      filterable: true,
      options: [
        SelectOption('opd', 'OPD'),
        SelectOption('ipd', 'IPD'),
        SelectOption('lab', 'Laboratory'),
        SelectOption('pharmacy', 'Pharmacy'),
        SelectOption('procedure', 'Procedure'),
        SelectOption('other', 'Other'),
      ],
    ),
    FieldDef(
      'defaultAmount',
      'Default amount',
      type: FieldType.number,
      min: 0,
      money: true,
    ),
    FieldDef('taxPercent', 'Tax %', type: FieldType.number, min: 0),
    _descField,
  ],
  uniqueRules: _rules('charge head'),
);

final paymentMethodsConfig = MasterEntityConfig(
  collection: 'billing_masters',
  module: Modules.billingMasters,
  title: 'Payment Methods',
  singular: 'Payment Method',
  fixedValues: const {'type': 'payment_method'},
  fields: const [
    _codeField,
    _nameField,
    FieldDef(
      'requiresReference',
      'Requires transaction reference',
      type: FieldType.boolean,
      defaultValue: false,
    ),
    _descField,
  ],
  uniqueRules: _rules('payment method'),
);

final discountRulesConfig = MasterEntityConfig(
  collection: 'billing_masters',
  module: Modules.billingMasters,
  title: 'Discount Controls',
  singular: 'Discount Rule',
  fixedValues: const {'type': 'discount_rule'},
  fields: [
    _codeField,
    _nameField,
    const FieldDef(
      'discountType',
      'Discount type',
      type: FieldType.select,
      required: true,
      options: [
        SelectOption('percent', 'Percentage'),
        SelectOption('flat', 'Flat amount'),
      ],
    ),
    const FieldDef(
      'value',
      'Value',
      type: FieldType.number,
      required: true,
      min: 0,
    ),
    const FieldDef(
      'requiresApproval',
      'Requires approval',
      type: FieldType.boolean,
      defaultValue: true,
    ),
    FieldDef(
      'approverRole',
      'Approver role',
      type: FieldType.select,
      options: [
        for (final r in AppRole.values)
          if (r != AppRole.superAdmin) SelectOption(r.id, r.label),
      ],
      requiredWhen: (d) => d['requiresApproval'] == true,
      visibleWhen: (d) => d['requiresApproval'] == true,
    ),
    _descField,
  ],
  uniqueRules: _rules('discount rule'),
);
