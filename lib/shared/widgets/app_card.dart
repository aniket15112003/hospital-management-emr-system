import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// White rounded card with optional header, matching the XRay "iq-card".
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    this.title,
    this.subtitle,
    this.actions = const [],
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md + 4),
  });

  final String? title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              child: LayoutBuilder(
                builder: (context, box) {
                  final heading = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title!, style: t.titleMedium),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(subtitle!, style: t.bodySmall),
                        ),
                    ],
                  );
                  if (actions.isEmpty) return heading;
                  final actionBar = Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: actions,
                  );
                  // Stack the actions under the title on narrow cards.
                  if (box.maxWidth < 560) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        heading,
                        const SizedBox(height: 10),
                        actionBar,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: heading),
                      Flexible(child: actionBar),
                    ],
                  );
                },
              ),
            ),
            const Divider(),
          ],
          // Gives ListTiles/InkWells a Material above the card's decoration.
          Material(
            type: MaterialType.transparency,
            child: Padding(padding: padding, child: child),
          ),
        ],
      ),
    );
  }
}

/// Compact metric tile with icon, value and caption.
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.color = AppColors.primary,
    this.caption,
    this.unavailable = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? caption;

  /// Shows the value muted, indicating the data source does not exist yet.
  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Semantics(
      label: '$label: $value${caption == null ? '' : ', $caption'}',
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: t.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: t.headlineSmall?.copyWith(
                      color: unavailable ? AppColors.muted : AppColors.heading,
                      fontSize: 22,
                    ),
                  ),
                  if (caption != null)
                    Text(
                      caption!,
                      style: t.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
