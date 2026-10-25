import '../../core/auth/permissions.dart';
import '../../core/data/master_entity.dart';

const wardsConfig = MasterEntityConfig(
  collection: 'wards',
  module: Modules.wardsRoomsBeds,
  title: 'Wards',
  singular: 'Ward',
  subtitle: 'Inpatient wards.',
  fields: [
    FieldDef(
      'code',
      'Ward ID',
      required: true,
      uppercase: true,
      maxLength: 20,
      searchable: true,
    ),
    FieldDef('name', 'Ward name', required: true, searchable: true),
    FieldDef(
      'wardType',
      'Ward type',
      type: FieldType.select,
      required: true,
      filterable: true,
      options: [
        SelectOption('general', 'General'),
        SelectOption('semi_private', 'Semi-private'),
        SelectOption('private', 'Private'),
        SelectOption('icu', 'ICU'),
        SelectOption('nicu', 'NICU'),
        SelectOption('emergency', 'Emergency'),
        SelectOption('other', 'Other'),
      ],
    ),
    FieldDef('floor', 'Floor', maxLength: 20),
    FieldDef(
      'dailyCharge',
      'Daily bed charge',
      type: FieldType.number,
      min: 0,
      money: true,
    ),
  ],
  uniqueRules: [
    UniqueRule(['code'], message: 'A ward with this ID already exists.'),
    UniqueRule(['name'], message: 'A ward with this name already exists.'),
  ],
);

const roomsConfig = MasterEntityConfig(
  collection: 'rooms',
  module: Modules.wardsRoomsBeds,
  title: 'Rooms',
  singular: 'Room',
  subtitle: 'Rooms belong to a ward.',
  fields: [
    FieldDef(
      'wardId',
      'Ward',
      type: FieldType.reference,
      refCollection: 'wards',
      required: true,
      filterable: true,
    ),
    FieldDef(
      'roomNumber',
      'Room number',
      required: true,
      uppercase: true,
      maxLength: 20,
      searchable: true,
    ),
    FieldDef(
      'roomType',
      'Room type',
      type: FieldType.select,
      options: [
        SelectOption('shared', 'Shared'),
        SelectOption('single', 'Single'),
        SelectOption('deluxe', 'Deluxe'),
        SelectOption('isolation', 'Isolation'),
      ],
    ),
    FieldDef('notes', 'Notes', type: FieldType.multiline, inTable: false),
  ],
  uniqueRules: [
    UniqueRule(
      ['roomNumber'],
      scopeField: 'wardId',
      message: 'This room number already exists in the selected ward.',
    ),
  ],
);

/// Bed statuses. `occupied` is set only by the future IPD admission
/// workflow; administrators cannot select it.
const bedStatusOptions = [
  SelectOption('available', 'Available'),
  SelectOption('reserved', 'Reserved'),
  SelectOption('cleaning', 'Cleaning'),
  SelectOption('maintenance', 'Maintenance'),
];

const bedsConfig = MasterEntityConfig(
  collection: 'beds',
  module: Modules.wardsRoomsBeds,
  title: 'Beds',
  singular: 'Bed',
  subtitle: 'Beds belong to a room; the ward is taken from the room.',
  notice:
      'Bed occupancy is managed by the future IPD module. Admission is not '
      'possible from the Admin Panel.',
  fields: [
    FieldDef(
      'roomId',
      'Room',
      type: FieldType.reference,
      refCollection: 'rooms',
      refLabelField: 'roomNumber',
      refCopy: {'wardId': 'wardId', 'wardName': 'wardName'},
      required: true,
      filterable: true,
    ),
    FieldDef(
      'wardId',
      'Ward',
      type: FieldType.reference,
      refCollection: 'wards',
      filterable: true,
      derived: true,
      helper: 'Derived from room',
    ),
    FieldDef(
      'bedNumber',
      'Bed number',
      required: true,
      uppercase: true,
      maxLength: 20,
      searchable: true,
    ),
    FieldDef(
      'bedStatus',
      'Bed status',
      type: FieldType.select,
      required: true,
      filterable: true,
      defaultValue: 'available',
      options: [...bedStatusOptions, SelectOption('occupied', 'Occupied')],
      lockedOptions: {'occupied'},
    ),
    FieldDef(
      'dailyChargeOverride',
      'Daily charge override',
      type: FieldType.number,
      min: 0,
      money: true,
      inTable: false,
      helper: 'Leave empty to use the ward charge',
    ),
  ],
  uniqueRules: [
    UniqueRule(
      ['bedNumber'],
      scopeField: 'roomId',
      message: 'This bed number already exists in the selected room.',
    ),
  ],
);
