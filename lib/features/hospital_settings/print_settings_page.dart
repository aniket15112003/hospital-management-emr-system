import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/permissions.dart';
import '../../core/data/master_entity.dart';
import '../../core/theme/app_tokens.dart';
import '../../shared/layout/page_body.dart';
import '../../shared/settings/settings_form.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/feedback.dart';
import 'settings_docs.dart';

const _paperSizes = [
  SelectOption('a4', 'A4'),
  SelectOption('a5', 'A5'),
  SelectOption('letter', 'Letter'),
  SelectOption('thermal_80', 'Thermal 80 mm'),
  SelectOption('thermal_58', 'Thermal 58 mm'),
];

const printSettingsFields = [
  FieldDef(
    'showLogo',
    'Show hospital logo in header',
    type: FieldType.boolean,
    defaultValue: true,
  ),
  FieldDef(
    'showAddress',
    'Show hospital address and contacts',
    type: FieldType.boolean,
    defaultValue: true,
  ),
  FieldDef(
    'headerText',
    'Header text (below hospital name)',
    type: FieldType.multiline,
    maxLength: 300,
  ),
  FieldDef(
    'receiptFooterText',
    'Receipt footer text',
    type: FieldType.multiline,
    maxLength: 300,
  ),
  FieldDef(
    'documentFooterText',
    'Clinical document footer text',
    type: FieldType.multiline,
    maxLength: 300,
  ),
  FieldDef(
    'receiptPaperSize',
    'Receipt paper size',
    type: FieldType.select,
    required: true,
    options: _paperSizes,
  ),
  FieldDef(
    'documentPaperSize',
    'Document paper size',
    type: FieldType.select,
    required: true,
    options: _paperSizes,
  ),
  FieldDef(
    'marginMm',
    'Page margin (mm)',
    type: FieldType.integer,
    required: true,
    min: 0,
  ),
  FieldDef(
    'fontScale',
    'Font size',
    type: FieldType.select,
    required: true,
    options: [
      SelectOption('small', 'Small'),
      SelectOption('normal', 'Normal'),
      SelectOption('large', 'Large'),
    ],
  ),
  FieldDef(
    'receiptCopies',
    'Receipt copies',
    type: FieldType.integer,
    required: true,
    min: 1,
  ),
];

class PrintSettingsPage extends ConsumerStatefulWidget {
  const PrintSettingsPage({super.key});

  @override
  ConsumerState<PrintSettingsPage> createState() => _PrintSettingsPageState();
}

class _PrintSettingsPageState extends ConsumerState<PrintSettingsPage> {
  Map<String, dynamic> _live = const {};

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(settingsDocProvider(hospitalProfileDoc)).value;
    return PageBody(
      title: 'Print Settings',
      subtitle: 'Header, footer and paper preferences for printed documents.',
      module: Modules.printSettings,
      children: [
        const InfoBanner(
          'These settings will be applied by receipt and clinical document '
          'templates as those modules are built. Templates themselves are not '
          'part of this phase.',
        ),
        const SizedBox(height: 20),
        SettingsFormCard(
          doc: printSettingsDoc,
          title: 'Print layout',
          fields: printSettingsFields,
          defaults: const {
            'showLogo': true,
            'showAddress': true,
            'receiptPaperSize': 'thermal_80',
            'documentPaperSize': 'a4',
            'marginMm': 10,
            'fontScale': 'normal',
            'receiptCopies': 1,
          },
          onDataChanged: (d) => setState(() => _live = d),
        ),
        const SizedBox(height: 20),
        AppCard(
          title: 'Header / footer preview',
          child: Center(
            child: Container(
              width: 420,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      if (_live['showLogo'] == true)
                        Container(
                          width: 44,
                          height: 44,
                          margin: const EdgeInsets.only(right: 12),
                          color: AppColors.background,
                          child: profile?['logoUrl'] == null
                              ? const Icon(
                                  Icons.image_outlined,
                                  color: AppColors.muted,
                                )
                              : Image.network(
                                  '${profile!['logoUrl']}',
                                  errorBuilder: (_, _, _) => const SizedBox(),
                                ),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${profile?['name'] ?? 'Hospital name (set in Hospital Profile)'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.heading,
                              ),
                            ),
                            if (_live['showAddress'] == true)
                              Text(
                                [
                                      profile?['addressLine1'],
                                      profile?['city'],
                                      profile?['phone'],
                                    ]
                                    .where((e) => e != null && '$e'.isNotEmpty)
                                    .join(' · '),
                                style: const TextStyle(fontSize: 11),
                              ),
                            if ((_live['headerText'] ?? '')
                                .toString()
                                .isNotEmpty)
                              Text(
                                '${_live['headerText']}',
                                style: const TextStyle(fontSize: 11),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  const Text(
                    'Document body',
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const Divider(height: 32),
                  Text(
                    '${_live['receiptFooterText'] ?? 'Receipt footer'}',
                    style: const TextStyle(fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
