/// Severity of a hazard. Ordered: higher index = more urgent.
enum HazardLevel { none, caution, warning, danger }

extension HazardLevelInfo on HazardLevel {
  String get display => switch (this) {
        HazardLevel.none => 'Clear',
        HazardLevel.caution => 'Caution',
        HazardLevel.warning => 'Warning',
        HazardLevel.danger => 'Danger',
      };

  /// Whether this level should fire a haptic + voice alert.
  bool get shouldAlert => index >= HazardLevel.warning.index;
}

/// A hazard determined by the hazard engine from the current detections.
class HazardEvent {
  final HazardLevel level;
  final String message; // e.g. "Stairs ahead"
  final String? source; // detection label that triggered it
  final DateTime time;

  HazardEvent({
    required this.level,
    required this.message,
    this.source,
    DateTime? time,
  }) : time = time ?? DateTime.now();

  static HazardEvent clear() =>
      HazardEvent(level: HazardLevel.none, message: 'Path clear');
}
