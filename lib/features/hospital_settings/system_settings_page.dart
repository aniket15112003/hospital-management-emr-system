import 'package:flutter/material.dart';

import '../../core/auth/permissions.dart';
import '../../core/data/master_entity.dart';
import '../../shared/layout/page_body.dart';
import '../../shared/settings/settings_form.dart';
import 'settings_docs.dart';

const systemSettingsFields = [
  FieldDef(
    'timezone',
    'Time zone',
    type: FieldType.select,
    required: true,
    options: [
      SelectOption('Asia/Kolkata', 'India (Asia/Kolkata)'),
      SelectOption('Asia/Dubai', 'Gulf (Asia/Dubai)'),
      SelectOption('UTC', 'UTC'),
    ],
  ),
  FieldDef(
    'currency',
    'Currency',
    type: FieldType.select,
    required: true,
    options: [
      SelectOption('INR', 'Indian Rupee (₹)'),
      SelectOption('USD', 'US Dollar (\$)'),
      SelectOption('AED', 'UAE Dirham'),
    ],
  ),
  FieldDef(
    'dateFormat',
    'Date format',
    type: FieldType.select,
    required: true,
    options: [
      SelectOption('dd MMM yyyy', '25 Oct 2026'),
      SelectOption('dd/MM/yyyy', '25/10/2026'),
      SelectOption('yyyy-MM-dd', '2026-10-25'),
    ],
  ),
  FieldDef(
    'sessionTimeoutMinutes',
    'Idle session timeout (minutes)',
    type: FieldType.integer,
    required: true,
    min: 5,
  ),
  FieldDef(
    'defaultFollowUpDays',
    'Default follow-up validity (days)',
    type: FieldType.integer,
    min: 0,
  ),
  FieldDef(
    'labModuleEnabled',
    'Laboratory module enabled',
    type: FieldType.boolean,
    helper:
        'Optional module. Even when enabled, lab orders are never mandatory '
        'for prescriptions.',
  ),
  FieldDef(
    'requireDiscountApproval',
    'Require approval for discounts',
    type: FieldType.boolean,
    helper: 'Per-rule approvers are configured in Billing Masters.',
  ),
];

class SystemSettingsPage extends StatelessWidget {
  const SystemSettingsPage({super.key});

  @override
  Widget build(BuildContext context) => const PageBody(
    title: 'System Settings',
    subtitle: 'Regional preferences and global switches.',
    module: Modules.systemSettings,
    children: [
      SettingsFormCard(
        doc: systemSettingsDoc,
        title: 'General',
        fields: systemSettingsFields,
        defaults: {
          'timezone': 'Asia/Kolkata',
          'currency': 'INR',
          'dateFormat': 'dd MMM yyyy',
          'sessionTimeoutMinutes': 30,
          'defaultFollowUpDays': 7,
          'labModuleEnabled': true,
          'requireDiscountApproval': true,
        },
      ),
    ],
  );
}
