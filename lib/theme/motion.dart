import 'package:flutter/material.dart';

/// Motion helpers that honour the OS "reduce motion" setting. Durations collapse
/// to zero when animations are disabled, so nothing moves purely to impress.
class Motion {
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  static Duration fast(BuildContext context) =>
      reduced(context) ? Duration.zero : const Duration(milliseconds: 150);
}
