import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/permissions.dart';
import '../../core/auth/session.dart';
import '../../core/data/audit_repository.dart';
import '../../core/data/master_entity.dart';
import '../../core/data/providers.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/normalize.dart';
import '../../shared/layout/page_body.dart';
import '../../shared/master_data/master_providers.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/feedback.dart';
import '../../shared/widgets/paged_table.dart';
import 'dashboard_repository.dart';

final dashboardSourceProvider = Provider<DashboardSource>(
  (ref) => ref.watch(isDemoProvider)
      ? DemoDashboardSource()
      : FirestoreDashboardSource(FirebaseFirestore.instance),
);

final registrationsTodayProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(dashboardSourceProvider).registrationsToday(),
);
final opdTodayProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(dashboardSourceProvider).opdEncountersToday(),
);
final queueProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(dashboardSourceProvider).queue(),
);
final recentVisitsProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(dashboardSourceProvider).recentVisits(),
);
final pendingLabProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(dashboardSourceProvider).pendingLabOrders(),
);
final pendingRxProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(dashboardSourceProvider).pendingPrescriptions(),
);
final collectionTodayProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(dashboardSourceProvider).collectionToday(),
);
final lowStockProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(dashboardSourceProvider).lowStock(),
);

final recentAuditProvider = StreamProvider.autoDispose<List<AuditEntry>>(
  (ref) => ref.watch(auditRepositoryProvider).watch(const AuditQuery(limit: 8)),
);

/// Bed counts by status, overall and per ward, from the `beds` master data.
class BedOccupancy {
  BedOccupancy(List<MasterRecord> beds) {
    for (final b in beds.where((b) => b.isActive)) {
      final s = '${b['bedStatus'] ?? 'available'}';
      byStatus[s] = (byStatus[s] ?? 0) + 1;
      final ward = '${b['wardName'] ?? 'Unassigned'}';
      final w = byWard.putIfAbsent(ward, () => (occupied: 0, total: 0));
      byWard[ward] = (
        occupied: w.occupied + (s == 'occupied' ? 1 : 0),
        total: w.total + 1,
      );
    }
  }

  final byStatus = <String, int>{};
  final byWard = <String, ({int occupied, int total})>{};

  int get total => byStatus.values.fold(0, (a, b) => a + b);
  int get occupied => byStatus['occupied'] ?? 0;
  double get rate => total == 0 ? 0 : occupied / total;
}

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  void _refresh(WidgetRef ref) {
    ref
      ..invalidate(registrationsTodayProvider)
      ..invalidate(opdTodayProvider)
      ..invalidate(queueProvider)
      ..invalidate(recentVisitsProvider)
      ..invalidate(pendingLabProvider)
      ..invalidate(pendingRxProvider)
      ..invalidate(collectionTodayProvider)
      ..invalidate(lowStockProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reg = ref.watch(registrationsTodayProvider);
    final opd = ref.watch(opdTodayProvider);
    final lab = ref.watch(pendingLabProvider);
    final rx = ref.watch(pendingRxProvider);
    final coll = ref.watch(collectionTodayProvider);
    final low = ref.watch(lowStockProvider);
    final beds = ref.watch(collectionRecordsProvider('beds'));
    final doctors = ref.watch(collectionRecordsProvider('doctors'));
    final canAudit = ref.watch(
      canProvider((Modules.auditLogs, PermAction.view)),
    );
    final canBeds = ref.watch(
      canProvider((Modules.wardsRoomsBeds, PermAction.view)),
    );
    final canDoctors = ref.watch(
      canProvider((Modules.doctors, PermAction.view)),
    );

    MetricCard metric<T>(
      AsyncValue<Metric<T>> v,
      IconData icon,
      String label,
      Color color,
      String Function(T) fmt,
    ) {
      final m = v.value;
      final unavailable = m != null && !m.isAvailable;
      return MetricCard(
        icon: icon,
        label: label,
        color: color,
        unavailable: unavailable || v.hasError,
        value: v.isLoading
            ? '…'
            : v.hasError
            ? 'Error'
            : unavailable
            ? '—'
            : fmt(m!.value as T),
        caption: v.hasError
            ? 'Could not load'
            : unavailable
            ? 'Source not available yet'
            : (m?.demo ?? false)
            ? 'Demo data'
            : null,
      );
    }

    final occupancy = BedOccupancy(beds.value ?? const []);

    return PageBody(
      title: 'Dashboard',
      subtitle: "Today's hospital overview · ${formatDate(DateTime.now())}",
      module: Modules.dashboard,
      actions: [
        OutlinedButton.icon(
          onPressed: () => _refresh(ref),
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Refresh'),
        ),
      ],
      children: [
        if (!ref.watch(isDemoProvider) &&
            implementedSources.values.every((on) => !on)) ...[
          const InfoBanner(
            'Registration, OPD, Laboratory, Pharmacy and Billing modules are '
            'not implemented yet, so their metrics show "—". Bed and audit '
            'data come from the Admin Panel.',
          ),
          const SizedBox(height: 20),
        ],
        ResponsiveGrid(
          minItemWidth: 250,
          children: [
            metric(
              reg,
              Icons.person_add_alt,
              "Today's registrations",
              AppColors.primary,
              (v) => '$v',
            ),
            metric(
              opd,
              Icons.groups_outlined,
              "Today's OPD encounters",
              AppColors.info,
              (v) => '$v',
            ),
            MetricCard(
              icon: Icons.bed_outlined,
              label: 'IPD bed occupancy',
              color: AppColors.secondary,
              unavailable: !canBeds,
              value: !canBeds
                  ? '—'
                  : beds.isLoading
                  ? '…'
                  : '${occupancy.occupied}/${occupancy.total}',
              caption: !canBeds
                  ? 'No permission'
                  : '${(occupancy.rate * 100).toStringAsFixed(0)}% occupied',
            ),
            metric(
              lab,
              Icons.biotech_outlined,
              'Pending lab orders',
              AppColors.warning,
              (v) => '${v.length}',
            ),
            metric(
              rx,
              Icons.medication_outlined,
              'Pending prescriptions',
              AppColors.danger,
              (v) => '${v.length}',
            ),
            metric(
              coll,
              Icons.payments_outlined,
              "Today's collection",
              AppColors.success,
              (v) => formatMoney(v.total),
            ),
            metric(
              low,
              Icons.inventory_2_outlined,
              'Low-stock alerts',
              AppColors.danger,
              (v) => '${v.length}',
            ),
            MetricCard(
              icon: Icons.medical_services_outlined,
              label: 'Active doctors',
              unavailable: !canDoctors,
              value: !canDoctors
                  ? '—'
                  : doctors.isLoading
                  ? '…'
                  : '${(doctors.value ?? []).where((d) => d.isActive).length}',
              caption: canDoctors ? 'From doctor master' : 'No permission',
            ),
          ],
        ),
        const SizedBox(height: 20),
        ResponsiveGrid(
          minItemWidth: 520,
          children: [
            const _QueueCard(),
            if (canBeds) _OccupancyCard(occupancy: occupancy, beds: beds),
            AppCard(
              title: 'Recent registrations & OPD encounters',
              child: _MetricBody(
                value: ref.watch(recentVisitsProvider),
                builder: (List<VisitRow> rows) => PagedTable<VisitRow>(
                  pageSize: 5,
                  rows: rows,
                  empty: const EmptyView(title: 'No visits today'),
                  columns: [
                    TableCol('Number', (r) => Text(r.number)),
                    TableCol('Patient', (r) => Text(r.patient)),
                    TableCol(
                      'Type',
                      (r) => StatusChip(
                        r.kind == 'opd' ? 'OPD' : 'Registration',
                        color: r.kind == 'opd'
                            ? AppColors.info
                            : AppColors.primary,
                      ),
                    ),
                    TableCol('Doctor', (r) => Text(r.doctor)),
                    TableCol('Time', (r) => Text(formatTime(r.at))),
                  ],
                ),
              ),
            ),
            _PendingCard(
              title: 'Pending laboratory orders',
              value: lab,
              detailLabel: 'Tests',
            ),
            _PendingCard(
              title: 'Pending pharmacy prescriptions',
              value: rx,
              detailLabel: 'Doctor',
            ),
            AppCard(
              title: "Today's collection summary",
              child: _MetricBody(
                value: coll,
                builder: (CollectionSummary c) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatMoney(c.total),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text('${c.receipts} receipts'),
                    const SizedBox(height: 12),
                    if (c.byMethod.isEmpty)
                      const EmptyView(title: 'No collections today')
                    else
                      for (final e in c.byMethod.entries)
                        _BarRow(
                          label: e.key,
                          value: e.value / (c.total == 0 ? 1 : c.total),
                          trailing: formatMoney(e.value),
                        ),
                  ],
                ),
              ),
            ),
            AppCard(
              title: 'Low-stock medicine alerts',
              child: _MetricBody(
                value: low,
                builder: (List<LowStockRow> rows) => PagedTable<LowStockRow>(
                  pageSize: 5,
                  rows: rows,
                  empty: const EmptyView(
                    title: 'No low-stock alerts',
                    icon: Icons.check_circle_outline,
                  ),
                  columns: [
                    TableCol('Medicine', (r) => Text(r.medicine)),
                    TableCol(
                      'In stock',
                      (r) => Text('${r.stock}'),
                      numeric: true,
                    ),
                    TableCol(
                      'Threshold',
                      (r) => Text('${r.threshold}'),
                      numeric: true,
                    ),
                    TableCol(
                      'Status',
                      (r) => StatusChip(
                        r.stock == 0 ? 'Out of stock' : 'Low',
                        color: r.stock == 0
                            ? AppColors.danger
                            : AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (canAudit) ...[const SizedBox(height: 20), const _RecentAuditCard()],
      ],
    );
  }
}

/// Renders a [Metric] with loading / error / unavailable / demo states.
class _MetricBody<T> extends StatelessWidget {
  const _MetricBody({required this.value, required this.builder});

  final AsyncValue<Metric<T>> value;
  final Widget Function(T value) builder;

  @override
  Widget build(BuildContext context) => value.when(
    loading: () => const LoadingView(),
    error: (e, _) => ErrorView(error: e),
    data: (m) => !m.isAvailable
        ? UnavailableSourceView(reason: m.reason!)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (m.demo)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: StatusChip('Demo data', color: AppColors.secondary),
                  ),
                ),
              builder(m.value as T),
            ],
          ),
  );
}

class _QueueCard extends ConsumerStatefulWidget {
  const _QueueCard();

  @override
  ConsumerState<_QueueCard> createState() => _QueueCardState();
}

class _QueueCardState extends ConsumerState<_QueueCard> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    return AppCard(
      title: 'Doctor / department queue',
      actions: [
        SizedBox(
          width: 180,
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Filter',
              prefixIcon: Icon(Icons.search, size: 18),
            ),
            onChanged: (v) => setState(() => _q = normalizeKey(v)),
          ),
        ),
      ],
      child: _MetricBody(
        value: ref.watch(queueProvider),
        builder: (List<QueueRow> rows) => PagedTable<QueueRow>(
          pageSize: 5,
          rows: rows
              .where(
                (r) => normalizeKey('${r.doctor} ${r.department}').contains(_q),
              )
              .toList(),
          empty: const EmptyView(title: 'No queue entries today'),
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
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({
    required this.title,
    required this.value,
    required this.detailLabel,
  });

  final String title;
  final AsyncValue<Metric<List<PendingRow>>> value;
  final String detailLabel;

  @override
  Widget build(BuildContext context) => AppCard(
    title: title,
    child: _MetricBody(
      value: value,
      builder: (List<PendingRow> rows) => PagedTable<PendingRow>(
        pageSize: 5,
        rows: rows,
        empty: const EmptyView(
          title: 'Nothing pending',
          icon: Icons.check_circle_outline,
        ),
        columns: [
          TableCol('Number', (r) => Text(r.number)),
          TableCol('Patient', (r) => Text(r.patient)),
          TableCol(detailLabel, (r) => Text(r.detail)),
          TableCol('Since', (r) => Text(formatTime(r.at))),
          TableCol('Status', (r) => StatusChip.status(r.status)),
        ],
      ),
    ),
  );
}

class _OccupancyCard extends StatelessWidget {
  const _OccupancyCard({required this.occupancy, required this.beds});

  final BedOccupancy occupancy;
  final AsyncValue<List<MasterRecord>> beds;

  @override
  Widget build(BuildContext context) => AppCard(
    title: 'IPD ward / bed occupancy',
    subtitle:
        'From bed master data · occupancy is set by the future IPD module',
    actions: [
      TextButton(
        onPressed: () => context.go('/beds'),
        child: const Text('Manage beds'),
      ),
    ],
    child: beds.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(error: e),
      data: (_) => occupancy.total == 0
          ? EmptyView(
              icon: Icons.bed_outlined,
              title: 'No beds configured',
              message: 'Add wards, rooms and beds to track occupancy.',
              action: OutlinedButton(
                onPressed: () => context.go('/wards'),
                child: const Text('Set up wards'),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in occupancy.byStatus.entries)
                      StatusChip.status(e.key, suffix: '${e.value}'),
                  ],
                ),
                const SizedBox(height: 16),
                for (final e in occupancy.byWard.entries)
                  _BarRow(
                    label: e.key,
                    value: e.value.total == 0
                        ? 0
                        : e.value.occupied / e.value.total,
                    trailing: '${e.value.occupied}/${e.value.total}',
                  ),
              ],
            ),
    ),
  );
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.value,
    required this.trailing,
  });

  final String label;
  final double value;
  final String trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: AppColors.heading),
              ),
            ),
            Text(trailing),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value.clamp(0, 1),
            minHeight: 8,
            backgroundColor: AppColors.primaryLight,
            color: AppColors.primary,
            semanticsLabel: "$label $trailing",
          ),
        ),
      ],
    ),
  );
}

class _RecentAuditCard extends ConsumerWidget {
  const _RecentAuditCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) => AppCard(
    title: 'Recent administrative activity',
    actions: [
      TextButton(
        onPressed: () => context.go('/audit-logs'),
        child: const Text('View all'),
      ),
    ],
    child: ref
        .watch(recentAuditProvider)
        .when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(error: e),
          data: (rows) => PagedTable<AuditEntry>(
            rows: rows,
            showFooter: false,
            empty: const EmptyView(title: 'No audit activity yet'),
            columns: [
              TableCol('Time', (r) => Text(formatDateTime(r.timestamp))),
              TableCol('Actor', (r) => Text(r.actor)),
              TableCol('Action', (r) => Text(r.action.replaceAll('_', ' '))),
              TableCol('Module', (r) => Text(r.module.replaceAll('_', ' '))),
              TableCol(
                'Record',
                (r) => Text(r.recordLabel ?? r.recordId ?? '—'),
              ),
              TableCol('Result', (r) => StatusChip.status(r.result)),
            ],
          ),
        ),
  );
}
