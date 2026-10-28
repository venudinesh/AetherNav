import 'package:flutter/material.dart';

/// Motion helpers that honour the OS "reduce motion" setting: when animations
/// are disabled, durations collapse to zero.
class Motion {
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  static Duration fast(BuildContext context) =>
      reduced(context) ? Duration.zero : const Duration(milliseconds: 150);
}
