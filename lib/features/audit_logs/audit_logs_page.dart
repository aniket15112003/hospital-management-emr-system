import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/permissions.dart';
import '../../core/data/audit_repository.dart';
import '../../core/data/providers.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/normalize.dart';
import '../../shared/layout/page_body.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/feedback.dart';
import '../../shared/widgets/paged_table.dart';

final auditLogsProvider = StreamProvider.autoDispose
    .family<List<AuditEntry>, AuditQuery>(
      (ref, q) => ref.watch(auditRepositoryProvider).watch(q),
    );

/// Read-only audit viewer. Entries are written by backend code only.
class AuditLogsPage extends ConsumerStatefulWidget {
  const AuditLogsPage({super.key});

  @override
  ConsumerState<AuditLogsPage> createState() => _AuditLogsPageState();
}

class _AuditLogsPageState extends ConsumerState<AuditLogsPage> {
  String? _module;
  DateTimeRange? _range;
  int _limit = 100;
  String _q = '';

  AuditQuery get _query => AuditQuery(
    module: _module,
    from: _range?.start,
    to: _range?.end.add(const Duration(days: 1)),
    limit: _limit,
  );

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: _range,
    );
    if (r != null) setState(() => _range = r);
  }

  void _details(AuditEntry e) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '${e.action.replaceAll('_', ' ')} · ${e.module.replaceAll('_', ' ')}',
        ),
        content: SizedBox(
          width: 480,
          child: SelectableText(
            const JsonEncoder.withIndent('  ').convert({
              'timestamp': e.timestamp?.toIso8601String(),
              'actorUid': e.actorUid,
              'actorName': e.actorName,
              'collection': e.collection,
              'recordId': e.recordId,
              'recordLabel': e.recordLabel,
              'result': e.result,
              'metadata': e.metadata,
            }),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(auditLogsProvider(_query));
    final q = normalizeKey(_q);
    final rows = (async.value ?? const <AuditEntry>[])
        .where(
          (e) =>
              q.isEmpty ||
              normalizeKey(
                '${e.actor} ${e.action} ${e.recordLabel} ${e.recordId}',
              ).contains(q),
        )
        .toList();

    return PageBody(
      title: 'Audit Logs',
      subtitle: 'Read-only record of administrative and system actions.',
      module: Modules.auditLogs,
      children: [
        const InfoBanner(
          'Audit entries are written by trusted backend functions. They cannot '
          'be edited or deleted from the application.',
        ),
        const SizedBox(height: 16),
        AppCard(
          title: 'Activity',
          subtitle: async.isLoading
              ? 'Loading…'
              : 'Showing ${rows.length} of the latest $_limit entries matching filters',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 240,
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search, size: 20),
                        hintText: 'Search actor, action, record',
                      ),
                      onChanged: (v) => setState(() => _q = v),
                    ),
                  ),
                  SizedBox(
                    width: 230,
                    child: DropdownButtonFormField<String?>(
                      initialValue: _module,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Module'),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All modules'),
                        ),
                        for (final m in Modules.all)
                          DropdownMenuItem(value: m.id, child: Text(m.label)),
                      ],
                      onChanged: (v) => setState(() => _module = v),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _pickRange,
                    icon: const Icon(Icons.date_range, size: 18),
                    label: Text(
                      _range == null
                          ? 'Any date'
                          : '${formatDate(_range!.start)} – ${formatDate(_range!.end)}',
                    ),
                  ),
                  if (_range != null)
                    TextButton(
                      onPressed: () => setState(() => _range = null),
                      child: const Text('Clear dates'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              async.when(
                loading: () => const LoadingView(),
                error: (e, _) => ErrorView(
                  error: e,
                  onRetry: () => ref.invalidate(auditLogsProvider(_query)),
                ),
                data: (all) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PagedTable<AuditEntry>(
                      pageSize: 25,
                      rows: rows,
                      empty: const EmptyView(
                        icon: Icons.history,
                        title: 'No audit entries match these filters',
                      ),
                      columns: [
                        TableCol(
                          'Timestamp',
                          (e) => Text(formatDateTime(e.timestamp)),
                        ),
                        TableCol('Actor', (e) => Text(e.actor)),
                        TableCol(
                          'Action',
                          (e) => Text(e.action.replaceAll('_', ' ')),
                        ),
                        TableCol(
                          'Module',
                          (e) => Text(e.module.replaceAll('_', ' ')),
                        ),
                        TableCol(
                          'Record',
                          (e) => ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 220),
                            child: Text(
                              e.recordLabel ?? e.recordId ?? '—',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        TableCol('Result', (e) => StatusChip.status(e.result)),
                        TableCol(
                          'Details',
                          (e) => IconButton(
                            tooltip: 'View details',
                            icon: const Icon(
                              Icons.info_outline,
                              size: 20,
                              color: AppColors.primary,
                            ),
                            onPressed: () => _details(e),
                          ),
                        ),
                      ],
                    ),
                    if (all.length >= _limit)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Center(
                          child: OutlinedButton(
                            onPressed: () => setState(() => _limit += 100),
                            child: const Text('Load older entries'),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
