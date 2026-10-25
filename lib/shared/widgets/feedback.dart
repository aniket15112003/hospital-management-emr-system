import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/error_text.dart';

class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.color = AppColors.primary});

  /// Maps common status values to colours.
  factory StatusChip.status(String status, {Key? key, String? suffix}) {
    final color = switch (status) {
      'active' || 'available' || 'success' || 'completed' => AppColors.success,
      'inactive' || 'failure' || 'denied' || 'occupied' => AppColors.danger,
      'reserved' || 'pending' || 'cleaning' || 'waiting' => AppColors.warning,
      'maintenance' => AppColors.muted,
      _ => AppColors.info,
    };
    final label = status.isEmpty
        ? '—'
        : status[0].toUpperCase() + status.substring(1).replaceAll('_', ' ');
    return StatusChip(
      suffix == null ? label : '$label · $suffix',
      key: key,
      color: color,
    );
  }

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label = 'Loading…'});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: Center(
      child: Semantics(
        label: label,
        child: const CircularProgressIndicator(strokeWidth: 2.5),
      ),
    ),
  );
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.lg,
        horizontal: 8,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.muted),
            const SizedBox(height: 8),
            Text(title, style: t.titleSmall, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 4),
              Text(message!, style: t.bodySmall, textAlign: TextAlign.center),
            ],
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => EmptyView(
    icon: Icons.error_outline,
    title: 'Something went wrong',
    message: friendlyError(error),
    action: onRetry == null
        ? null
        : OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
  );
}

/// Shown where a metric's data source belongs to a module not yet built.
class UnavailableSourceView extends StatelessWidget {
  const UnavailableSourceView({super.key, required this.reason});
  final String reason;

  @override
  Widget build(BuildContext context) => EmptyView(
    icon: Icons.hourglass_empty,
    title: 'Data source not available yet',
    message: reason,
  );
}

enum BannerKind { info, warning, danger, success }

class InfoBanner extends StatelessWidget {
  const InfoBanner(
    this.message, {
    super.key,
    this.kind = BannerKind.info,
    this.action,
  });

  final String message;
  final BannerKind kind;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (kind) {
      BannerKind.info => (AppColors.info, Icons.info_outline),
      BannerKind.warning => (AppColors.warning, Icons.warning_amber_rounded),
      BannerKind.danger => (AppColors.danger, Icons.error_outline),
      BannerKind.success => (AppColors.success, Icons.check_circle_outline),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.heading, fontSize: 13),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

void showSuccess(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.success),
    );
}

void showFailure(BuildContext context, Object error) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(friendlyError(error)),
        backgroundColor: AppColors.danger,
      ),
    );
}
