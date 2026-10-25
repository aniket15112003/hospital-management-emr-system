import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/permissions.dart';
import '../../core/auth/session.dart';
import '../../core/auth/user_admin_policy.dart';
import '../../core/data/master_entity.dart';
import '../../core/data/providers.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/error_text.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/normalize.dart';
import '../../shared/layout/page_body.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/feedback.dart';
import '../../shared/widgets/paged_table.dart';
import 'user_repository.dart';

final usersProvider = StreamProvider.autoDispose<List<AppUserRecord>>(
  (ref) => ref.watch(userAdminRepositoryProvider).watchUsers(),
);

class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});

  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage> {
  String _q = '';
  String? _role;
  String _status = 'all';

  String? _denied(String action, {AppUserRecord? target, AppRole? newRole}) {
    final s = ref.read(sessionProvider).value;
    if (s?.role == null) return 'Not signed in.';
    return checkUserAdminAction(
      callerRole: s!.role!,
      callerUid: s.uid,
      callerPermissions: ref.read(currentPermissionsProvider),
      action: action,
      targetUid: target?.uid,
      targetCurrentRole: target?.role,
      newRole: newRole,
    );
  }

  Future<void> _toggle(AppUserRecord u) async {
    final activate = !u.isActive;
    final ok = await confirmDialog(
      context,
      title: '${activate ? 'Activate' : 'Deactivate'} ${u.displayName}?',
      message: activate
          ? 'The user will be able to sign in again.'
          : 'The user will be signed out and blocked from signing in. '
                'Their history is kept.',
      confirmLabel: activate ? 'Activate' : 'Deactivate',
      destructive: !activate,
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(userAdminRepositoryProvider).setActive(u.uid, activate);
      if (mounted) {
        showSuccess(context, 'User ${activate ? 'activated' : 'deactivated'}.');
      }
    } catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(usersProvider);
    final me = ref.watch(sessionProvider).value;
    ref.watch(currentPermissionsProvider);
    final canCreate = _denied(PermAction.create) == null;
    final all = async.value ?? const <AppUserRecord>[];
    final q = normalizeKey(_q);
    final rows = all.where((u) {
      if (_role != null && u.role?.id != _role) return false;
      if (_status != 'all' && u.status != _status) return false;
      return q.isEmpty ||
          normalizeKey('${u.displayName} ${u.email}').contains(q);
    }).toList();

    return PageBody(
      title: 'Users',
      subtitle: 'Login accounts, roles and access status.',
      module: Modules.users,
      children: [
        const InfoBanner(
          'Accounts are created and changed only through secure backend '
          'functions. Passwords are never stored in the database; new users '
          'receive a one-time password setup link. Nobody can change their '
          'own role or status, and only a Super Admin can assign Admin or '
          'Super Admin.',
        ),
        const SizedBox(height: 16),
        AppCard(
          title: 'Users (${all.length})',
          subtitle: '${all.where((u) => u.isActive).length} active',
          actions: [
            if (canCreate)
              FilledButton.icon(
                onPressed: () => showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const _CreateUserDialog(),
                ),
                icon: const Icon(Icons.person_add_alt, size: 18),
                label: const Text('Add user'),
              ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 260,
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search, size: 20),
                        hintText: 'Search name or email',
                      ),
                      onChanged: (v) => setState(() => _q = v),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String?>(
                      initialValue: _role,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Role'),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All roles'),
                        ),
                        for (final r in AppRole.values)
                          DropdownMenuItem(value: r.id, child: Text(r.label)),
                      ],
                      onChanged: (v) => setState(() => _role = v),
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All')),
                        DropdownMenuItem(
                          value: 'active',
                          child: Text('Active'),
                        ),
                        DropdownMenuItem(
                          value: 'inactive',
                          child: Text('Inactive'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _status = v ?? 'all'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              async.when(
                loading: () => const LoadingView(),
                error: (e, _) => ErrorView(
                  error: e,
                  onRetry: () => ref.invalidate(usersProvider),
                ),
                data: (_) => PagedTable<AppUserRecord>(
                  rows: rows,
                  empty: const EmptyView(title: 'No users found'),
                  columns: [
                    TableCol(
                      'Name',
                      (u) => Text(
                        u.displayName + (u.uid == me?.uid ? ' (you)' : ''),
                      ),
                    ),
                    TableCol('Email', (u) => Text(u.email)),
                    TableCol(
                      'Role',
                      (u) => StatusChip(
                        u.role?.label ?? 'Unassigned',
                        color: u.role?.isPrivileged ?? false
                            ? AppColors.secondary
                            : AppColors.primary,
                      ),
                    ),
                    TableCol('Status', (u) => StatusChip.status(u.status)),
                    TableCol('Created', (u) => Text(formatDate(u.createdAt))),
                    TableCol('Actions', (u) {
                      final roleDenied = _denied(PermAction.edit, target: u);
                      final statusDenied = _denied(
                        PermAction.deactivate,
                        target: u,
                      );
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'View details',
                            icon: const Icon(
                              Icons.visibility_outlined,
                              size: 20,
                              color: AppColors.primary,
                            ),
                            onPressed: () => _showDetails(u),
                          ),
                          IconButton(
                            tooltip: roleDenied ?? 'Change role',
                            icon: const Icon(
                              Icons.manage_accounts_outlined,
                              size: 20,
                            ),
                            onPressed: roleDenied != null
                                ? null
                                : () => showDialog<void>(
                                    context: context,
                                    builder: (_) => _RoleDialog(user: u),
                                  ),
                          ),
                          IconButton(
                            tooltip:
                                statusDenied ??
                                (u.isActive ? 'Deactivate' : 'Activate'),
                            icon: Icon(
                              u.isActive
                                  ? Icons.toggle_on_outlined
                                  : Icons.toggle_off_outlined,
                              color: statusDenied != null
                                  ? null
                                  : (u.isActive
                                        ? AppColors.success
                                        : AppColors.muted),
                            ),
                            onPressed: statusDenied != null
                                ? null
                                : () => _toggle(u),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showDetails(AppUserRecord u) {
    Widget row(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(k, style: const TextStyle(color: AppColors.muted)),
          ),
          Expanded(
            child: SelectableText(
              v,
              style: const TextStyle(color: AppColors.heading),
            ),
          ),
        ],
      ),
    );
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(u.displayName),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              row('User ID', u.uid),
              row('Email', u.email),
              row('Phone', u.phone ?? '—'),
              row('Role', u.role?.label ?? 'Unassigned'),
              row('Status', u.status),
              row('Created', formatDateTime(u.createdAt)),
              row('Updated', formatDateTime(u.updatedAt)),
            ],
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
}

/// Roles the current user may assign.
List<AppRole> _assignableRoles(WidgetRef ref) {
  final me = ref.read(sessionProvider).value;
  final isSuper = me?.role == AppRole.superAdmin;
  return [
    for (final r in AppRole.values)
      if (isSuper || !r.isPrivileged) r,
  ];
}

class _CreateUserDialog extends ConsumerStatefulWidget {
  const _CreateUserDialog();

  @override
  ConsumerState<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends ConsumerState<_CreateUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  AppRole? _role;
  bool _busy = false;
  String? _error;
  CreateUserResult? _result;

  static const _emailField = FieldDef(
    'email',
    'Email',
    type: FieldType.email,
    required: true,
  );
  static const _phoneField = FieldDef('phone', 'Phone', type: FieldType.phone);

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await ref
          .read(userAdminRepositoryProvider)
          .createUser(
            displayName: _name.text.trim(),
            email: _email.text.trim().toLowerCase(),
            role: _role!,
            phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          );
      setState(() => _result = res);
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_result != null) {
      final link = _result!.passwordSetupLink;
      return AlertDialog(
        title: const Text('User created'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const InfoBanner(
                'The account was created and the role assigned.',
                kind: BannerKind.success,
              ),
              const SizedBox(height: 12),
              if (link != null) ...[
                const Text(
                  'Share this one-time password setup link with the user through a secure channel:',
                ),
                const SizedBox(height: 8),
                SelectableText(link, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: link));
                      if (context.mounted) showSuccess(context, 'Link copied.');
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy link'),
                  ),
                ),
              ] else
                const Text(
                  'Demo mode: no real login account or setup link was created.',
                ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      );
    }
    return AlertDialog(
      title: const Text('Add user'),
      scrollable: true,
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                InfoBanner(_error!, kind: BannerKind.danger),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Display name *'),
                validator: (v) =>
                    (v ?? '').trim().length < 2 ? 'Enter the full name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email *'),
                validator: (v) => _emailField.validate(v, const {}),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
                validator: (v) => _phoneField.validate(v, const {}),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<AppRole>(
                isExpanded: true,
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Role *'),
                items: [
                  for (final r in _assignableRoles(ref))
                    DropdownMenuItem(value: r, child: Text(r.label)),
                ],
                onChanged: (v) => setState(() => _role = v),
                validator: (v) => v == null ? 'Select a role' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Create user'),
        ),
      ],
    );
  }
}

class _RoleDialog extends ConsumerStatefulWidget {
  const _RoleDialog({required this.user});
  final AppUserRecord user;

  @override
  ConsumerState<_RoleDialog> createState() => _RoleDialogState();
}

class _RoleDialogState extends ConsumerState<_RoleDialog> {
  late AppRole? _role = widget.user.role;
  bool _busy = false;
  String? _error;

  Future<void> _save() async {
    if (_role == null || _role == widget.user.role) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(userAdminRepositoryProvider)
          .setRole(widget.user.uid, _role!);
      if (!mounted) return;
      Navigator.pop(context);
      showSuccess(context, 'Role updated to ${_role!.label}.');
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roles = _assignableRoles(ref);
    return AlertDialog(
      title: Text('Change role · ${widget.user.displayName}'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              InfoBanner(_error!, kind: BannerKind.danger),
              const SizedBox(height: 16),
            ],
            DropdownButtonFormField<AppRole>(
              isExpanded: true,
              initialValue: roles.contains(_role) ? _role : null,
              decoration: const InputDecoration(labelText: 'Role'),
              items: [
                for (final r in roles)
                  DropdownMenuItem(value: r, child: Text(r.label)),
              ],
              onChanged: (v) => setState(() => _role = v),
            ),
            const SizedBox(height: 12),
            const Text(
              'The change takes effect the next time the user\'s session refreshes '
              '(within about an hour, or immediately after they sign in again).',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: const Text('Save role'),
        ),
      ],
    );
  }
}
