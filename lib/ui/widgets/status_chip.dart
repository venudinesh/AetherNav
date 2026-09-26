import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// The semantic tone of a [StatusChip]. Neutral uses surface colors; the others
/// map to the [StatusColors] extension so color always carries meaning.
enum StatusTone { neutral, success, warning, danger, info }

/// A compact, quiet chip for a single status label. No drop shadow, no gradient.
class StatusChip extends StatelessWidget {
  final String label;
  final StatusTone tone;
  final IconData? icon;
  const StatusChip({
    super.key,
    required this.label,
    this.tone = StatusTone.neutral,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = Theme.of(context).extension<StatusColors>()!;
    final (Color bg, Color fg) = switch (tone) {
      StatusTone.neutral => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
      StatusTone.success => (status.successContainer, status.onSuccessContainer),
      StatusTone.warning => (status.warningContainer, status.onWarningContainer),
      StatusTone.danger => (status.dangerContainer, status.onDangerContainer),
      StatusTone.info => (status.infoContainer, status.onInfoContainer),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 6)],
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: fg, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
