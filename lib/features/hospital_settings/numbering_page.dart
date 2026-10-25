import 'package:flutter/material.dart';

import '../../core/auth/permissions.dart';
import '../../core/data/master_entity.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/numbering.dart';
import '../../shared/layout/page_body.dart';
import '../../shared/settings/settings_form.dart';
import '../../shared/widgets/feedback.dart';
import 'settings_docs.dart';

const _numberingFields = [
  FieldDef('prefix', 'Prefix', required: true, uppercase: true, maxLength: 10),
  FieldDef(
    'separator',
    'Separator',
    type: FieldType.select,
    required: true,
    options: [
      SelectOption('-', 'Hyphen (-)'),
      SelectOption('/', 'Slash (/)'),
      SelectOption('', 'None'),
    ],
  ),
  FieldDef(
    'dateSegment',
    'Date segment',
    type: FieldType.select,
    required: true,
    options: [
      SelectOption('none', 'None'),
      SelectOption('YYYY', 'Year (2026)'),
      SelectOption('YYMM', 'Year+month (2610)'),
      SelectOption('YYYYMM', 'Year+month (202610)'),
      SelectOption('YYYYMMDD', 'Full date (20261025)'),
    ],
  ),
  FieldDef(
    'padding',
    'Sequence digits',
    type: FieldType.integer,
    required: true,
    min: 1,
  ),
  FieldDef(
    'resetPolicy',
    'Reset sequence',
    type: FieldType.select,
    required: true,
    options: [
      SelectOption('never', 'Never'),
      SelectOption('yearly', 'Every year'),
      SelectOption('monthly', 'Every month'),
      SelectOption('daily', 'Every day'),
    ],
  ),
  FieldDef(
    'startAt',
    'Start at',
    type: FieldType.integer,
    required: true,
    min: 1,
  ),
];

class NumberingPage extends StatelessWidget {
  const NumberingPage({super.key});

  @override
  Widget build(BuildContext context) => PageBody(
    title: 'Numbering & Receipt Settings',
    subtitle:
        'Formats for UHIDs, encounter numbers, receipts and other documents.',
    module: Modules.numbering,
    children: [
      const InfoBanner(
        'Only the format is configured here. Actual numbers are issued by a '
        'trusted backend transaction (allocateDocumentNumber Cloud Function) '
        'when the related workflows are implemented — never by a client-side '
        'counter. Changing a format does not renumber existing documents.',
      ),
      const SizedBox(height: 20),
      for (final t in numberedDocTypes) ...[
        _NumberingCard(id: t.$1, label: t.$2, prefix: t.$3),
        const SizedBox(height: 20),
      ],
    ],
  );
}

class _NumberingCard extends StatefulWidget {
  const _NumberingCard({
    required this.id,
    required this.label,
    required this.prefix,
  });

  final String id;
  final String label;
  final String prefix;

  @override
  State<_NumberingCard> createState() => _NumberingCardState();
}

class _NumberingCardState extends State<_NumberingCard> {
  Map<String, dynamic>? _live;

  @override
  Widget build(BuildContext context) {
    final cfg = NumberFormatConfig.fromMap(_live, widget.prefix);
    final now = DateTime.now();
    String preview;
    try {
      preview = formatDocumentNumber(cfg, cfg.startAt, now);
    } catch (_) {
      preview = '—';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsFormCard(
          doc: numberingDoc(widget.id),
          title: widget.label,
          fields: _numberingFields,
          defaults: {
            'prefix': widget.prefix,
            'separator': '-',
            'dateSegment': 'none',
            'padding': 6,
            'resetPolicy': 'never',
            'startAt': 1,
          },
          extraValidator: (d) =>
              validateResetPolicy('${d['resetPolicy']}', '${d['dateSegment']}'),
          onDataChanged: (d) => setState(() => _live = d),
        ),
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Preview of first number: '),
                TextSpan(
                  text: preview,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
                if (validateResetPolicy(cfg.resetPolicy, cfg.dateSegment)
                    case final e?)
                  TextSpan(
                    text: '   ⚠ $e',
                    style: const TextStyle(color: AppColors.danger),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
