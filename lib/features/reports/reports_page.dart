import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/permissions.dart';
import '../../core/data/providers.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../shared/layout/page_body.dart';
import '../../shared/master_data/master_providers.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/feedback.dart';
import '../../shared/widgets/paged_table.dart';
import '../admin_dashboard/dashboard_page.dart';
import '../admin_dashboard/dashboard_repository.dart';

/// A report in the operational reports framework. [source] is the module
/// that owns the data; null means the data lives in the Admin Panel.
class ReportDefinition {
  const ReportDefinition(
    this.id,
    this.title,
    this.description,
    this.icon, {
    this.source,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final SourceModule? source;

  bool get available => source == null || (implementedSources[source] ?? false);
}

const reportDefinitions = [
  ReportDefinition(
    'registrations',
    'Patient registrations',
    'New patient registrations per day.',
    Icons.person_add_alt,
    source: SourceModule.registration,
  ),
  ReportDefinition(
    'opd',
    'OPD encounters',
    'OPD visits by doctor and department.',
    Icons.groups_outlined,
    source: SourceModule.opd,
  ),
  ReportDefinition(
    'queue',
    'Doctor / department queue',
    'Waiting, in-consultation and completed counts.',
    Icons.queue_outlined,
    source: SourceModule.opd,
  ),
  ReportDefinition(
    'ipd',
    'IPD occupancy',
    'Bed status by ward from bed master data.',
    Icons.bed_outlined,
  ),
  ReportDefinition(
    'lab',
    'Pending lab orders',
    'Orders awaiting sample, processing or results.',
    Icons.biotech_outlined,
    source: SourceModule.lab,
  ),
  ReportDefinition(
    'pharmacy',
    'Pending pharmacy prescriptions',
    'Prescriptions awaiting dispensing.',
    Icons.medication_outlined,
    source: SourceModule.pharmacy,
  ),
  ReportDefinition(
    'collection',
    'Collection summary',
    'Collections by payment method.',
    Icons.payments_outlined,
    source: SourceModule.billing,
  ),
  ReportDefinition(
    'low_stock',
    'Low-stock alerts',
    'Medicines below their threshold.',
    Icons.inventory_2_outlined,
    source: SourceModule.pharmacy,
  ),
];

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  ReportDefinition _selected = reportDefinitions[3];

  @override
  Widget build(BuildContext context) {
    final isDemo = ref.watch(isDemoProvider);
    final wide = MediaQuery.sizeOf(context).width > 1000;
    final list = AppCard(
      title: 'Reports',
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          for (final r in reportDefinitions)
            ListTile(
              selected: r == _selected,
              selectedTileColor: AppColors.primaryLight.withValues(alpha: 0.5),
              leading: Icon(r.icon, color: AppColors.primary),
              title: Text(r.title),
              subtitle: Text(
                r.available
                    ? 'Available'
                    : isDemo
                    ? 'Demo data'
                    : 'Source not available yet',
                style: TextStyle(
                  color: r.available ? AppColors.success : AppColors.muted,
                  fontSize: 12,
                ),
              ),
              onTap: () => setState(() => _selected = r),
            ),
        ],
      ),
    );
    final body = AppCard(
      title: _selected.title,
      subtitle: _selected.description,
      child: _ReportBody(report: _selected, demo: isDemo),
    );
    return PageBody(
      title: 'Operational Reports',
      subtitle: 'Reports use actual available data only.',
      module: Modules.reports,
      children: [
        wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 320, child: list),
                  const SizedBox(width: 20),
                  Expanded(child: body),
                ],
              )
            : Column(children: [list, const SizedBox(height: 20), body]),
      ],
    );
  }
}

class _ReportBody extends ConsumerWidget {
  const _ReportBody({required this.report, required this.demo});

  final ReportDefinition report;
  final bool demo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (report.id == 'ipd') return const _IpdReport();
    if (!report.available && !demo) {
      return UnavailableSourceView(
        reason:
            '${report.source!.label} is not implemented yet. This report '
            'will show real data once that module records it.',
      );
    }
    // Today's figures from the dashboard sources (demo or live).
    Widget metric<T>(
      AsyncValue<Metric<T>> v,
      Widget Function(T) build,
    ) => v.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(error: e),
      data: (m) => !m.isAvailable
          ? UnavailableSourceView(reason: m.reason!)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Today · ${formatDate(DateTime.now())}${m.demo ? ' · demo data' : ''}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                build(m.value as T),
              ],
            ),
    );
    Widget count(int n, String label) =>
        Text('$n $label', style: Theme.of(context).textTheme.headlineSmall);

    return switch (report.id) {
      'registrations' => metric(
        ref.watch(registrationsTodayProvider),
        (int n) => count(n, 'registrations'),
      ),
      'opd' => metric(
        ref.watch(opdTodayProvider),
        (int n) => count(n, 'encounters'),
      ),
      'queue' => metric(
        ref.watch(queueProvider),
        (List<QueueRow> rows) => PagedTable<QueueRow>(
          rows: rows,
          empty: const EmptyView(title: 'No queue data'),
          columns: [
            TableCol('Doctor', (r) => Text(r.doctor)),
            TableCol('Department', (r) => Text(r.department)),
            TableCol('Waiting', (r) => Text('${r.waiting}'), numeric: true),
            TableCol(
              'In consultation',
              (r) => Text('${r.inProgress}'),
              numeric: true,
            ),
            TableCol('Completed', (r) => Text('${r.completed}'), numeric: true),
          ],
        ),
      ),
      'lab' || 'pharmacy' => metric(
        ref.watch(report.id == 'lab' ? pendingLabProvider : pendingRxProvider),
        (List<PendingRow> rows) => PagedTable<PendingRow>(
          rows: rows,
          empty: const EmptyView(title: 'Nothing pending'),
          columns: [
            TableCol('Number', (r) => Text(r.number)),
            TableCol('Patient', (r) => Text(r.patient)),
            TableCol('Detail', (r) => Text(r.detail)),
            TableCol('Since', (r) => Text(formatDateTime(r.at))),
            TableCol('Status', (r) => StatusChip.status(r.status)),
          ],
        ),
      ),
      'collection' => metric(
        ref.watch(collectionTodayProvider),
        (CollectionSummary c) => PagedTable<MapEntry<String, num>>(
          rows: c.byMethod.entries.toList(),
          empty: const EmptyView(title: 'No collections'),
          columns: [
            TableCol('Payment method', (e) => Text(e.key)),
            TableCol(
              'Amount',
              (e) => Text(formatMoney(e.value)),
              numeric: true,
            ),
          ],
        ),
      ),
      'low_stock' => metric(
        ref.watch(lowStockProvider),
        (List<LowStockRow> rows) => PagedTable<LowStockRow>(
          rows: rows,
          empty: const EmptyView(title: 'No low-stock items'),
          columns: [
            TableCol('Medicine', (r) => Text(r.medicine)),
            TableCol('Stock', (r) => Text('${r.stock}'), numeric: true),
            TableCol('Threshold', (r) => Text('${r.threshold}'), numeric: true),
          ],
        ),
      ),
      _ => const SizedBox(),
    };
  }
}

class _IpdReport extends ConsumerWidget {
  const _IpdReport();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final beds = ref.watch(collectionRecordsProvider('beds'));
    return beds.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(error: e),
      data: (list) {
        final active = list.where((b) => b.isActive).toList();
        final wards = <String, Map<String, int>>{};
        for (final b in active) {
          final w = wards.putIfAbsent(
            '${b['wardName'] ?? 'Unassigned'}',
            () => {},
          );
          final s = '${b['bedStatus'] ?? 'available'}';
          w[s] = (w[s] ?? 0) + 1;
        }
        const statuses = [
          'available',
          'occupied',
          'reserved',
          'cleaning',
          'maintenance',
        ];
        final rows = wards.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${active.length} active beds across ${wards.length} wards · as of ${formatDateTime(DateTime.now())}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            PagedTable<MapEntry<String, Map<String, int>>>(
              rows: rows,
              empty: const EmptyView(title: 'No beds configured'),
              columns: [
                TableCol('Ward', (e) => Text(e.key)),
                for (final s in statuses)
                  TableCol(
                    s[0].toUpperCase() + s.substring(1),
                    (e) => Text('${e.value[s] ?? 0}'),
                    numeric: true,
                  ),
                TableCol(
                  'Total',
                  (e) => Text('${e.value.values.fold(0, (a, b) => a + b)}'),
                  numeric: true,
                ),
                TableCol('Occupancy', (e) {
                  final total = e.value.values.fold(0, (a, b) => a + b);
                  final occ = e.value['occupied'] ?? 0;
                  return Text(
                    total == 0
                        ? '—'
                        : '${(occ * 100 / total).toStringAsFixed(0)}%',
                  );
                }, numeric: true),
              ],
            ),
          ],
        );
      },
    );
  }
}
