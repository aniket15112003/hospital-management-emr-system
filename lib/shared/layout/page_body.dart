import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/permissions.dart';
import '../../core/auth/session.dart';
import '../../core/theme/app_tokens.dart';
import '../widgets/feedback.dart';

/// Standard scrollable page body with header and access check.
class PageBody extends ConsumerWidget {
  const PageBody({
    super.key,
    required this.title,
    this.subtitle,
    this.module,
    this.actions = const [],
    required this.children,
  });

  final String title;
  final String? subtitle;

  /// When set, the page requires `view` permission on this module.
  final String? module;
  final List<Widget> actions;
  final List<Widget> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final allowed =
        module == null || ref.watch(canProvider((module!, PermAction.view)));
    final narrow = MediaQuery.sizeOf(context).width < AppBreakpoints.mobile;
    return ListView(
      padding: EdgeInsets.all(narrow ? AppSpacing.md : AppSpacing.lg),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 12,
          spacing: 12,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.headlineSmall),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(subtitle!, style: t.bodyMedium),
                  ),
              ],
            ),
            if (allowed && actions.isNotEmpty)
              Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (allowed)
          ...children
        else
          const EmptyView(
            icon: Icons.lock_outline,
            title: 'Access denied',
            message:
                'Your role does not have permission to view this page. '
                'Contact a Super Admin if you need access.',
          ),
      ],
    );
  }
}

/// Lays children out in a responsive grid of equal-width columns.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 260,
    this.spacing = AppSpacing.md + 4,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = (c.maxWidth / minItemWidth).floor().clamp(1, 4);
        final w = (c.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children) SizedBox(width: w, child: child),
          ],
        );
      },
    );
  }
}
