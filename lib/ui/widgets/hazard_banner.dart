import 'package:flutter/material.dart';

import '../../data/models/hazard_event.dart';
import '../../theme/app_colors.dart';
import '../../theme/motion.dart';

/// A prominent, honest hazard banner. Colour and icon come from the semantic
/// [StatusColors] extension so the tone always carries meaning, and there is a
/// distinct "clear" state so the surface is never ambiguous. No gradient, no
/// shadow theatrics (per DESIGN_RULES).
class HazardBanner extends StatelessWidget {
  final HazardEvent hazard;
  const HazardBanner({super.key, required this.hazard});

  @override
  Widget build(BuildContext context) {
    final status = Theme.of(context).extension<StatusColors>()!;
    final t = Theme.of(context).textTheme;
    final (Color bg, Color fg, IconData icon) = switch (hazard.level) {
      HazardLevel.none => (
          status.successContainer,
          status.onSuccessContainer,
          Icons.check_circle_outline
        ),
      HazardLevel.caution => (
          status.infoContainer,
          status.onInfoContainer,
          Icons.info_outline
        ),
      HazardLevel.warning => (
          status.warningContainer,
          status.onWarningContainer,
          Icons.warning_amber_outlined
        ),
      HazardLevel.danger => (
          status.dangerContainer,
          status.onDangerContainer,
          Icons.report_outlined
        ),
    };
    return AnimatedContainer(
      duration: Motion.fast(context),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(icon, color: fg),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              hazard.level.display.toUpperCase(),
              style: t.labelSmall?.copyWith(
                  color: fg,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              hazard.message,
              style: t.titleMedium
                  ?.copyWith(color: fg, fontWeight: FontWeight.w600),
            ),
          ]),
        ),
      ]),
    );
  }
}
