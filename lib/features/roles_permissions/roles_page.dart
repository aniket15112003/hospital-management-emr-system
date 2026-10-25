import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/permissions.dart';
import '../../core/auth/roles_repository.dart';
import '../../core/auth/session.dart';
import '../../core/data/providers.dart';
import '../../core/theme/app_tokens.dart';
import '../../shared/layout/page_body.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/feedback.dart';

class RolesPage extends ConsumerStatefulWidget {
  const RolesPage({super.key});

  @override
  ConsumerState<RolesPage> createState() => _RolesPageState();
}

class _RolesPageState extends ConsumerState<RolesPage> {
  AppRole _selected = AppRole.admin;

  /// Unsaved edits of the selected role.
  PermissionMatrix? _draft;
  bool _saving = false;

  void _select(AppRole r) => setState(() {
    _selected = r;
    _draft = null;
  });

  Future<void> _save(RoleDefinition def) async {
    final draft = _draft ?? def.permissions;
    setState(() => _saving = true);
    try {
      await ref.read(rolesRepositoryProvider).save(_selected, draft);
      if (!mounted) return;
      setState(() => _draft = null);
      showSuccess(context, 'Permissions for ${_selected.label} saved.');
    } catch (e) {
      if (mounted) showFailure(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rolesAsync = ref.watch(rolesProvider);
    final isSuper =
        ref.watch(sessionProvider).value?.role == AppRole.superAdmin;
    final canManage = isSuper && _selected != AppRole.superAdmin;
    final wide = MediaQuery.sizeOf(context).width > 1000;

    return PageBody(
      title: 'Roles & Permissions',
      subtitle: 'Module-level permissions for each role.',
      module: Modules.roles,
      children: [
        InfoBanner(
          isSuper
              ? 'Permissions are enforced by Firestore Security Rules and Cloud '
                    'Functions, not only by hiding menu items. Super Admin always '
                    'has full access and cannot be edited.'
              : 'Read-only: only a Super Admin can change role permissions.',
        ),
        const SizedBox(height: 16),
        rolesAsync.when(
          loading: () => const LoadingView(),
          error: (e, _) =>
              ErrorView(error: e, onRetry: () => ref.invalidate(rolesProvider)),
          data: (roles) {
            final def = roles[_selected]!;
            final matrix = _draft ?? def.permissions;
            final roleList = AppCard(
              title: 'Roles',
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  for (final r in AppRole.values)
                    ListTile(
                      selected: r == _selected,
                      selectedTileColor: AppColors.primaryLight.withValues(
                        alpha: 0.5,
                      ),
                      leading: Icon(
                        r.isPrivileged
                            ? Icons.shield_outlined
                            : Icons.badge_outlined,
                        color: AppColors.primary,
                      ),
                      title: Text(r.label),
                      subtitle: Text(
                        r == AppRole.superAdmin
                            ? 'Full access'
                            : roles[r]!.stored
                            ? '${roles[r]!.permissions.values.fold<int>(0, (a, s) => a + s.length)} permissions'
                            : 'Not saved yet',
                      ),
                      onTap: () => _select(r),
                    ),
                ],
              ),
            );
            final editor = AppCard(
              title: _selected.label,
              subtitle: _draft != null ? 'Unsaved changes' : null,
              actions: [
                if (canManage) ...[
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => setState(
                            () => _draft = defaultPermissionsFor(_selected),
                          ),
                    child: const Text('Reset to defaults'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving || (_draft == null && def.stored)
                        ? null
                        : () => _save(def),
                    child: const Text('Save'),
                  ),
                ],
              ],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!def.stored) ...[
                    const InfoBanner(
                      'This role has no saved permission document, so the server '
                      'currently grants it no access. Defaults are shown; save to apply them.',
                      kind: BannerKind.warning,
                    ),
                    const SizedBox(height: 12),
                  ],
                  _Matrix(
                    matrix: matrix,
                    editable: canManage,
                    onChanged: (module, action, on) {
                      final next = {
                        for (final e in matrix.entries) e.key: {...e.value},
                      };
                      final set = next.putIfAbsent(module, () => {});
                      on ? set.add(action) : set.remove(action);
                      // Any action implies view.
                      if (on) set.add(PermAction.view);
                      if (!on && action == PermAction.view) set.clear();
                      setState(() => _draft = next);
                    },
                  ),
                ],
              ),
            );
            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 300, child: roleList),
                      const SizedBox(width: 20),
                      Expanded(child: editor),
                    ],
                  )
                : Column(
                    children: [roleList, const SizedBox(height: 20), editor],
                  );
          },
        ),
      ],
    );
  }
}

class _Matrix extends StatelessWidget {
  const _Matrix({
    required this.matrix,
    required this.editable,
    required this.onChanged,
  });

  final PermissionMatrix matrix;
  final bool editable;
  final void Function(String module, String action, bool on) onChanged;

  static const _actions = [
    PermAction.view,
    PermAction.create,
    PermAction.edit,
    PermAction.deactivate,
    PermAction.approve,
    PermAction.manage,
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: const WidgetStatePropertyAll(AppColors.background),
        columnSpacing: 20,
        columns: [
          const DataColumn(label: Text('Module')),
          for (final a in _actions)
            DataColumn(label: Text(PermAction.labels[a]!)),
        ],
        rows: [
          for (final m in Modules.all)
            DataRow(
              cells: [
                DataCell(Text(m.label)),
                for (final a in _actions)
                  DataCell(
                    m.actions.contains(a)
                        ? Checkbox(
                            value: matrix[m.id]?.contains(a) ?? false,
                            semanticLabel:
                                '${m.label}: ${PermAction.labels[a]}',
                            onChanged: editable
                                ? (v) => onChanged(m.id, a, v ?? false)
                                : null,
                          )
                        : const Text(
                            '—',
                            style: TextStyle(color: AppColors.muted),
                          ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
