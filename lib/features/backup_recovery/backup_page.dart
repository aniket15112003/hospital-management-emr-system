import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/permissions.dart';
import '../../core/config/app_config.dart';
import '../../core/data/master_entity.dart';
import '../../core/data/providers.dart';
import '../../core/utils/formatters.dart';
import '../../shared/layout/page_body.dart';
import '../../shared/settings/settings_form.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/feedback.dart';
import '../../shared/widgets/paged_table.dart';
import '../hospital_settings/settings_docs.dart';

/// A backup run recorded by backend automation in `backup_runs`.
/// Clients can read but never write this collection.
class BackupRun {
  const BackupRun(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;

  DateTime? get startedAt => asDateTime(data['startedAt']);
  DateTime? get completedAt => asDateTime(data['completedAt']);
  String get status => '${data['status'] ?? 'unknown'}';
  String get type => '${data['type'] ?? 'firestore_export'}';
  String get location => '${data['location'] ?? '—'}';
}

final backupRunsProvider = StreamProvider.autoDispose<List<BackupRun>?>((ref) {
  // Demo mode has no backup infrastructure; report "not configured".
  if (ref.watch(backendModeProvider) != BackendMode.firebase) {
    return Stream.value(null);
  }
  return FirebaseFirestore.instance
      .collection('backup_runs')
      .orderBy('startedAt', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => [for (final d in s.docs) BackupRun(d.id, d.data())]);
});

const _backupConfigFields = [
  FieldDef(
    'retentionDays',
    'Retention (days)',
    type: FieldType.integer,
    required: true,
    min: 1,
  ),
  FieldDef(
    'schedule',
    'Schedule description',
    maxLength: 120,
    helper: 'e.g. Daily at 02:00 IST',
  ),
  FieldDef(
    'exportLocation',
    'Export location',
    maxLength: 200,
    helper: 'e.g. gs://<bucket>/firestore-backups (no credentials)',
  ),
  FieldDef('recoveryContact', 'Recovery contact person', maxLength: 120),
  FieldDef(
    'recoveryNotes',
    'Recovery procedure notes',
    type: FieldType.multiline,
    maxLength: 2000,
  ),
];

class BackupPage extends ConsumerWidget {
  const BackupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runs = ref.watch(backupRunsProvider);
    return PageBody(
      title: 'Backup & Recovery',
      subtitle: 'Backup status, history, retention and recovery documentation.',
      module: Modules.backup,
      children: [
        runs.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(error: e),
          data: (list) {
            final success =
                list?.where((r) => r.status == 'success').toList() ?? [];
            final configured = list != null && list.isNotEmpty;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!configured)
                  const InfoBanner(
                    'Backups are NOT configured. Firebase does not automatically '
                    'provide a complete backup solution for this project. Set up '
                    'scheduled Firestore backups or exports and a backend job that '
                    'records each run in backup_runs (see docs/ADMIN_PANEL.md).',
                    kind: BannerKind.danger,
                  ),
                const SizedBox(height: 20),
                ResponsiveGrid(
                  children: [
                    MetricCard(
                      icon: Icons.backup_outlined,
                      label: 'Backup status',
                      value: configured ? 'Configured' : 'Not configured',
                      unavailable: !configured,
                    ),
                    MetricCard(
                      icon: Icons.check_circle_outline,
                      label: 'Last successful backup',
                      value: success.isEmpty
                          ? '—'
                          : formatDate(success.first.completedAt),
                      caption: success.isEmpty
                          ? 'No successful run recorded'
                          : formatTime(success.first.completedAt),
                      unavailable: success.isEmpty,
                    ),
                    MetricCard(
                      icon: Icons.history,
                      label: 'Runs recorded',
                      value: '${list?.length ?? 0}',
                      unavailable: !configured,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                AppCard(
                  title: 'Backup history',
                  child: PagedTable<BackupRun>(
                    rows: list ?? const [],
                    empty: const EmptyView(
                      icon: Icons.cloud_off,
                      title: 'No backup runs recorded',
                    ),
                    columns: [
                      TableCol(
                        'Started',
                        (r) => Text(formatDateTime(r.startedAt)),
                      ),
                      TableCol(
                        'Completed',
                        (r) => Text(formatDateTime(r.completedAt)),
                      ),
                      TableCol(
                        'Type',
                        (r) => Text(r.type.replaceAll('_', ' ')),
                      ),
                      TableCol('Location', (r) => Text(r.location)),
                      TableCol('Status', (r) => StatusChip.status(r.status)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        const SettingsFormCard(
          doc: backupConfigDoc,
          title: 'Retention & recovery documentation',
          fields: _backupConfigFields,
          defaults: {'retentionDays': 30},
        ),
        const SizedBox(height: 20),
        const AppCard(
          title: 'Restore',
          child: InfoBanner(
            'Restores cannot be started from the application. A restore must be '
            'performed by an authorised operator using Google Cloud tooling '
            '(gcloud firestore import / backups restore) following the documented '
            'procedure, ideally into a separate database first for verification.',
            kind: BannerKind.warning,
          ),
        ),
      ],
    );
  }
}
