import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/permissions.dart';
import '../../core/auth/session.dart';
import '../../core/data/master_entity.dart';
import '../../core/data/providers.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/normalize.dart';
import '../layout/page_body.dart';
import '../widgets/app_card.dart';
import '../widgets/feedback.dart';
import '../widgets/paged_table.dart';
import 'master_form_dialog.dart';
import 'master_providers.dart';

/// Full page for a single master entity.
class MasterDataPage extends StatelessWidget {
  const MasterDataPage({super.key, required this.config});
  final MasterEntityConfig config;

  @override
  Widget build(BuildContext context) => PageBody(
    title: config.title,
    subtitle: config.subtitle,
    module: config.module,
    children: [MasterDataPanel(config: config)],
  );
}

/// Searchable, filterable, paginated table with add/edit/activate actions.
class MasterDataPanel extends ConsumerStatefulWidget {
  const MasterDataPanel({super.key, required this.config});
  final MasterEntityConfig config;

  @override
  ConsumerState<MasterDataPanel> createState() => _MasterDataPanelState();
}

class _MasterDataPanelState extends ConsumerState<MasterDataPanel> {
  String _query = '';
  String _status = 'all';
  final _filters = <String, String?>{};

  MasterEntityConfig get c => widget.config;

  bool _can(String action) => ref.watch(canProvider((c.module, action)));

  List<MasterRecord> _apply(List<MasterRecord> rows) {
    final q = normalizeKey(_query);
    return rows.where((r) {
      if (_status != 'all' && r.status != _status) return false;
      for (final e in _filters.entries) {
        if (e.value != null && '${r[e.key] ?? ''}' != e.value) return false;
      }
      if (q.isEmpty) return true;
      final fields = c.searchFields.isEmpty ? c.fields : c.searchFields;
      return fields.any((f) => normalizeKey(f.display(r.data)).contains(q));
    }).toList();
  }

  Future<void> _toggle(MasterRecord r) async {
    final activate = !r.isActive;
    final ok = await confirmDialog(
      context,
      title:
          '${activate ? 'Activate' : 'Deactivate'} ${c.singular.toLowerCase()}?',
      message: activate
          ? 'This record will become available for selection again.'
          : 'Inactive records are hidden from selection lists in other '
                'modules. Existing references are kept.',
      confirmLabel: activate ? 'Activate' : 'Deactivate',
      destructive: !activate,
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(masterRepositoryProvider).setActive(c, r.id, activate);
      if (mounted) {
        showSuccess(
          context,
          '${c.singular} ${activate ? 'activated' : 'deactivated'}.',
        );
      }
    } catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  Widget _filterDropdown(FieldDef f, List<MasterRecord> rows) {
    final options = <String, String>{};
    if (f.type == FieldType.select) {
      for (final o in f.options) {
        options[o.value] = o.label;
      }
    } else {
      for (final r in rows) {
        final id = r[f.key];
        if (id is String && id.isNotEmpty) options[id] = f.display(r.data);
      }
    }
    return SizedBox(
      width: 190,
      child: DropdownButtonFormField<String?>(
        initialValue: _filters[f.key],
        isExpanded: true,
        decoration: InputDecoration(labelText: f.label),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('All')),
          for (final e in options.entries)
            DropdownMenuItem(value: e.key, child: Text(e.value)),
        ],
        onChanged: (v) => setState(() => _filters[f.key] = v),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(masterRecordsProvider(c));
    final canCreate = _can(PermAction.create);
    final canEdit = _can(PermAction.edit);
    final canDeactivate = _can(PermAction.deactivate);
    final rows = async.value ?? const <MasterRecord>[];
    final filtered = _apply(rows);

    final toolbar = Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 260,
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, size: 20),
              hintText: 'Search ${c.title.toLowerCase()}',
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        for (final f in c.filterFields) _filterDropdown(f, rows),
        SizedBox(
          width: 150,
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All')),
              DropdownMenuItem(value: 'active', child: Text('Active')),
              DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
            ],
            onChanged: (v) => setState(() => _status = v ?? 'all'),
          ),
        ),
      ],
    );

    final columns = <TableCol<MasterRecord>>[
      for (final f in c.fields.where((f) => f.inTable))
        TableCol(
          f.label,
          (r) => f.type == FieldType.select && f.key.endsWith('Status')
              ? StatusChip.status('${r[f.key] ?? ''}')
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: Text(
                    f.display(r.data),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
          numeric: f.type == FieldType.number || f.type == FieldType.integer,
        ),
      TableCol('Status', (r) => StatusChip.status(r.status)),
      TableCol('Updated', (r) => Text(formatDate(r.updatedAt))),
      TableCol(
        'Actions',
        (r) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: canEdit ? 'Edit' : 'View',
              icon: Icon(
                canEdit ? Icons.edit_outlined : Icons.visibility_outlined,
                size: 20,
                color: AppColors.primary,
              ),
              onPressed: () => showMasterForm(
                context,
                config: c,
                record: r,
                readOnly: !canEdit,
              ),
            ),
            if (canDeactivate)
              IconButton(
                tooltip: r.isActive ? 'Deactivate' : 'Activate',
                icon: Icon(
                  r.isActive
                      ? Icons.toggle_on_outlined
                      : Icons.toggle_off_outlined,
                  color: r.isActive ? AppColors.success : AppColors.muted,
                ),
                onPressed: () => _toggle(r),
              ),
          ],
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (c.notice != null) ...[
          InfoBanner(c.notice!),
          const SizedBox(height: 16),
        ],
        AppCard(
          title: '${c.title} (${rows.length})',
          subtitle: async.isLoading
              ? 'Loading…'
              : '${rows.where((r) => r.isActive).length} active · '
                    '${filtered.length} shown',
          actions: [
            if (canCreate)
              FilledButton.icon(
                onPressed: () => showMasterForm(context, config: c),
                icon: const Icon(Icons.add, size: 18),
                label: Text('Add ${c.singular.toLowerCase()}'),
              ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              toolbar,
              const SizedBox(height: 16),
              async.when(
                loading: () => const LoadingView(),
                error: (e, _) => ErrorView(
                  error: e,
                  onRetry: () => ref.invalidate(masterRecordsProvider(c)),
                ),
                data: (_) => PagedTable<MasterRecord>(
                  columns: columns,
                  rows: filtered,
                  empty: EmptyView(
                    title: rows.isEmpty
                        ? 'No ${c.title.toLowerCase()} yet'
                        : 'No matching records',
                    message: rows.isEmpty
                        ? (canCreate
                              ? 'Use "Add ${c.singular.toLowerCase()}" to create the first one.'
                              : null)
                        : 'Try a different search or filter.',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
