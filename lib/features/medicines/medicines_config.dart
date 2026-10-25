import '../../core/auth/permissions.dart';
import '../../core/data/master_entity.dart';

const medicinesConfig = MasterEntityConfig(
  collection: 'medicines',
  module: Modules.medicines,
  title: 'Medicines',
  singular: 'Medicine',
  subtitle: 'Medicine master data. Stock and dispensing belong to Pharmacy.',
  notice:
      'Inventory and dispensing are part of the future Pharmacy module. The '
      'low-stock threshold is stored here for use by that module.',
  fields: [
    FieldDef(
      'code',
      'Medicine ID',
      required: true,
      uppercase: true,
      maxLength: 20,
      searchable: true,
    ),
    FieldDef('name', 'Medicine name', required: true, searchable: true),
    FieldDef('genericName', 'Generic name', searchable: true, inTable: false),
    FieldDef('strength', 'Strength', maxLength: 40, helper: 'e.g. 500 mg'),
    FieldDef(
      'dosageForm',
      'Dosage form',
      type: FieldType.select,
      required: true,
      filterable: true,
      options: [
        SelectOption('tablet', 'Tablet'),
        SelectOption('capsule', 'Capsule'),
        SelectOption('syrup', 'Syrup'),
        SelectOption('injection', 'Injection'),
        SelectOption('ointment', 'Ointment'),
        SelectOption('drops', 'Drops'),
        SelectOption('inhaler', 'Inhaler'),
        SelectOption('other', 'Other'),
      ],
    ),
    FieldDef(
      'unit',
      'Unit',
      type: FieldType.select,
      required: true,
      options: [
        SelectOption('strip', 'Strip'),
        SelectOption('bottle', 'Bottle'),
        SelectOption('vial', 'Vial'),
        SelectOption('ampoule', 'Ampoule'),
        SelectOption('tube', 'Tube'),
        SelectOption('piece', 'Piece'),
      ],
    ),
    FieldDef(
      'salePrice',
      'Sale price / unit',
      type: FieldType.number,
      min: 0,
      money: true,
    ),
    FieldDef(
      'taxPercent',
      'Tax %',
      type: FieldType.number,
      min: 0,
      inTable: false,
    ),
    FieldDef('hsnCode', 'HSN code', maxLength: 20, inTable: false),
    FieldDef(
      'lowStockThreshold',
      'Low-stock threshold',
      type: FieldType.integer,
      min: 0,
    ),
  ],
  uniqueRules: [
    UniqueRule(['code'], message: 'A medicine with this ID already exists.'),
    UniqueRule(
      ['name', 'strength', 'dosageForm'],
      message: 'This medicine with the same strength and form already exists.',
    ),
  ],
);
