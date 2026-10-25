import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/nav_items.dart';
import '../../core/auth/permissions.dart';
import '../../core/auth/session.dart';
import '../../core/theme/app_tokens.dart';

class Sidebar extends ConsumerWidget {
  const Sidebar({
    super.key,
    required this.location,
    this.collapsed = false,
    this.onNavigate,
  });

  final String location;
  final bool collapsed;

  /// Called after navigation (closes the mobile drawer).
  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(currentPermissionsProvider);
    bool visible(NavItem i) =>
        perms[i.module]?.contains(PermAction.view) ?? false;

    return Container(
      width: collapsed ? 80 : 260,
      color: AppColors.surface,
      child: Column(
        children: [
          SizedBox(
            height: 72,
            child: Row(
              mainAxisAlignment: collapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                if (!collapsed) const SizedBox(width: 24),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(Icons.local_hospital, color: Colors.white),
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  const Text(
                    'HMS Admin',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.heading,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                for (final group in navGroups)
                  if (navItems.any((i) => i.group == group && visible(i))) ...[
                    if (!collapsed)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 16, 12, 6),
                        child: Text(
                          group.toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                      )
                    else
                      const Divider(height: 24),
                    for (final item in navItems.where(
                      (i) => i.group == group && visible(i),
                    ))
                      _NavTile(
                        item: item,
                        selected: item.path == location,
                        collapsed: collapsed,
                        onTap: () {
                          context.go(item.path);
                          onNavigate?.call();
                        },
                      ),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  final NavItem item;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.body;
    final tile = Material(
      color: selected ? AppColors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: onTap,
        hoverColor: AppColors.primaryLight.withValues(alpha: 0.5),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: collapsed ? 0 : 14,
            vertical: 11,
          ),
          child: Row(
            mainAxisAlignment: collapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Icon(
                item.icon,
                size: 20,
                color: selected ? Colors.white : AppColors.primary,
              ),
              if (!collapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fg,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Semantics(
        selected: selected,
        button: true,
        label: item.label,
        child: collapsed ? Tooltip(message: item.label, child: tile) : tile,
      ),
    );
  }
}
