import 'package:flutter/material.dart';

/// Brand seeds. Indigo is the Material 3 seed; teal is the accent
/// (per DESIGN_RULES: "one seed color -> M3 tonal scheme, indigo seed, teal accent").
const Color kIndigoSeed = Color(0xFF4F46E5); // indigo-600
const Color kTealSeed = Color(0xFF0D9488); // teal-600

/// Semantic status colors (success / warning / danger / info), used ONLY where a
/// color carries meaning. Each fill is paired with an on-color chosen for WCAG AA.
/// Exposed as a ThemeExtension so widgets read them from the active theme.
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color danger;
  final Color onDanger;
  final Color dangerContainer;
  final Color onDangerContainer;
  final Color info;
  final Color onInfo;
  final Color infoContainer;
  final Color onInfoContainer;

  const StatusColors({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.danger,
    required this.onDanger,
    required this.dangerContainer,
    required this.onDangerContainer,
    required this.info,
    required this.onInfo,
    required this.infoContainer,
    required this.onInfoContainer,
  });
  static const StatusColors light = StatusColors(
    success: Color(0xFF15803D), onSuccess: Color(0xFFFFFFFF),
    successContainer: Color(0xFFDCFCE7), onSuccessContainer: Color(0xFF052E16),
    warning: Color(0xFFB45309), onWarning: Color(0xFFFFFFFF),
    warningContainer: Color(0xFFFEF3C7), onWarningContainer: Color(0xFF451A03),
    danger: Color(0xFFB91C1C), onDanger: Color(0xFFFFFFFF),
    dangerContainer: Color(0xFFFEE2E2), onDangerContainer: Color(0xFF450A0A),
    info: Color(0xFF1D4ED8), onInfo: Color(0xFFFFFFFF),
    infoContainer: Color(0xFFDBEAFE), onInfoContainer: Color(0xFF082F49),
  );

  static const StatusColors dark = StatusColors(
    success: Color(0xFF4ADE80), onSuccess: Color(0xFF052E16),
    successContainer: Color(0xFF14532D), onSuccessContainer: Color(0xFFDCFCE7),
    warning: Color(0xFFFBBF24), onWarning: Color(0xFF451A03),
    warningContainer: Color(0xFF78350F), onWarningContainer: Color(0xFFFEF3C7),
    danger: Color(0xFFF87171), onDanger: Color(0xFF450A0A),
    dangerContainer: Color(0xFF7F1D1D), onDangerContainer: Color(0xFFFEE2E2),
    info: Color(0xFF60A5FA), onInfo: Color(0xFF082F49),
    infoContainer: Color(0xFF1E3A8A), onInfoContainer: Color(0xFFDBEAFE),
  );
  @override
  StatusColors copyWith({
    Color? success, Color? onSuccess, Color? successContainer, Color? onSuccessContainer,
    Color? warning, Color? onWarning, Color? warningContainer, Color? onWarningContainer,
    Color? danger, Color? onDanger, Color? dangerContainer, Color? onDangerContainer,
    Color? info, Color? onInfo, Color? infoContainer, Color? onInfoContainer,
  }) {
    return StatusColors(
      success: success ?? this.success, onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning, onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      danger: danger ?? this.danger, onDanger: onDanger ?? this.onDanger,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      onDangerContainer: onDangerContainer ?? this.onDangerContainer,
      info: info ?? this.info, onInfo: onInfo ?? this.onInfo,
      infoContainer: infoContainer ?? this.infoContainer,
      onInfoContainer: onInfoContainer ?? this.onInfoContainer,
    );
  }

  @override
  StatusColors lerp(ThemeExtension<StatusColors>? other, double t) {
    if (other is! StatusColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return StatusColors(
      success: c(success, other.success), onSuccess: c(onSuccess, other.onSuccess),
      successContainer: c(successContainer, other.successContainer),
      onSuccessContainer: c(onSuccessContainer, other.onSuccessContainer),
      warning: c(warning, other.warning), onWarning: c(onWarning, other.onWarning),
      warningContainer: c(warningContainer, other.warningContainer),
      onWarningContainer: c(onWarningContainer, other.onWarningContainer),
      danger: c(danger, other.danger), onDanger: c(onDanger, other.onDanger),
      dangerContainer: c(dangerContainer, other.dangerContainer),
      onDangerContainer: c(onDangerContainer, other.onDangerContainer),
      info: c(info, other.info), onInfo: c(onInfo, other.onInfo),
      infoContainer: c(infoContainer, other.infoContainer),
      onInfoContainer: c(onInfoContainer, other.onInfoContainer),
    );
  }
}
