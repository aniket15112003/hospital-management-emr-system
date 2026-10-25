import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/nav_items.dart';
import '../../core/auth/permissions.dart';
import '../../core/auth/session.dart';
import '../../core/data/providers.dart';
import '../../core/theme/app_tokens.dart';
import 'sidebar.dart';

/// Sidebar + topbar layout wrapping every Admin Panel page.
class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool? _collapsed;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final mobile = width < AppBreakpoints.mobile;
    final collapsed = _collapsed ?? width < AppBreakpoints.desktop;
    final isDemo = ref.watch(isDemoProvider);

    final content = Column(
      children: [
        _TopBar(
          location: widget.location,
          onMenu: () => mobile
              ? _scaffoldKey.currentState?.openDrawer()
              : setState(() => _collapsed = !collapsed),
        ),
        if (isDemo)
          Container(
            width: double.infinity,
            color: AppColors.secondary.withValues(alpha: 0.15),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: const Text(
              'DEMO MODE — sample data held in memory only. Nothing is saved '
              'and no real accounts are created.',
              style: TextStyle(
                color: AppColors.heading,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        Expanded(child: widget.child),
      ],
    );

    return Scaffold(
      key: _scaffoldKey,
      drawer: mobile
          ? Drawer(
              width: 270,
              child: Sidebar(
                location: widget.location,
                onNavigate: () => Navigator.of(context).pop(),
              ),
            )
          : null,
      body: mobile
          ? content
          : Row(
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  child: Sidebar(
                    location: widget.location,
                    collapsed: collapsed,
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: content),
              ],
            ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.location, required this.onMenu});

  final String location;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = navItemFor(location);
    final session = ref.watch(sessionProvider).value;
    final narrow = MediaQuery.sizeOf(context).width < AppBreakpoints.mobile;
    final t = Theme.of(context).textTheme;

    return Container(
      height: 68,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Toggle navigation',
            icon: const Icon(Icons.menu, color: AppColors.primary),
            onPressed: onMenu,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item?.label ?? 'Admin Panel',
                  style: t.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!narrow)
                  Text(
                    [
                      'Home',
                      if (item != null && item.path != '/') ...[
                        item.group,
                        item.label,
                      ],
                    ].join('  /  '),
                    style: t.bodySmall,
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_none, color: AppColors.body),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Notifications'),
                content: const Text(
                  'Notifications are not available yet. A notification '
                  'service will be added with the operational modules.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ),
          if (session != null) _ProfileMenu(session: session, compact: narrow),
        ],
      ),
    );
  }
}

class _ProfileMenu extends ConsumerWidget {
  const _ProfileMenu({required this.session, required this.compact});

  final AppSession session;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDemo = ref.watch(isDemoProvider);
    return PopupMenuButton<Object>(
      tooltip: 'Profile menu',
      offset: const Offset(0, 56),
      onSelected: (v) async {
        if (v is AppRole) {
          ref.read(demoSessionProvider.notifier).switchRole(v);
        } else if (v == 'signout') {
          await FirebaseAuth.instance.signOut();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem<Object>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.heading,
                ),
              ),
              Text(session.email, style: const TextStyle(fontSize: 12)),
              Text(
                session.role?.label ?? 'No role',
                style: const TextStyle(fontSize: 12, color: AppColors.primary),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        if (isDemo) ...[
          const PopupMenuItem<Object>(
            enabled: false,
            child: Text('Preview as role (demo only)'),
          ),
          for (final r in AppRole.values)
            CheckedPopupMenuItem<Object>(
              value: r,
              checked: session.role == r,
              child: Text(r.label),
            ),
        ] else
          const PopupMenuItem<Object>(
            value: 'signout',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.logout),
              title: Text('Sign out'),
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primaryLight,
              child: Text(
                session.initials,
                style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (!compact) ...[
              const SizedBox(width: 10),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.heading,
                    ),
                  ),
                  Text(
                    session.role?.label ?? '',
                    style: const TextStyle(fontSize: 12, color: AppColors.body),
                  ),
                ],
              ),
              const Icon(Icons.arrow_drop_down, color: AppColors.body),
            ],
          ],
        ),
      ),
    );
  }
}
