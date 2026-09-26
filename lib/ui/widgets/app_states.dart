import 'package:flutter/material.dart';

/// Shown while a screen or list is loading its first data.
class LoadingState extends StatelessWidget {
  final String? message;
  const LoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Centered(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircularProgressIndicator(strokeWidth: 3),
        if (message != null) ...[
          const SizedBox(height: 16),
          Text(message!,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ]),
    );
  }
}

/// Shown when a list is genuinely empty (distinct from an error).
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  const EmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return _Centered(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 40, color: scheme.onSurfaceVariant),
        const SizedBox(height: 16),
        Text(title, style: t.titleMedium, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(message,
            textAlign: TextAlign.center,
            style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
        if (action != null) ...[const SizedBox(height: 20), action!],
      ]),
    );
  }
}

/// Shown when something failed. Offers a retry whenever [onRetry] is provided.
class ErrorState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  const ErrorState({
    super.key,
    this.title = 'Something went wrong',
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return _Centered(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.error_outline, size: 40, color: scheme.error),
        const SizedBox(height: 16),
        Text(title, style: t.titleMedium, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(message,
            textAlign: TextAlign.center,
            style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
        if (onRetry != null) ...[
          const SizedBox(height: 20),
          OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again')),
        ],
      ]),
    );
  }
}

class _Centered extends StatelessWidget {
  final Widget child;
  const _Centered({required this.child});
  @override
  Widget build(BuildContext context) =>
      Center(child: Padding(padding: const EdgeInsets.all(32), child: child));
}
