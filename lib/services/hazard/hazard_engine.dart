import '../../data/models/detection.dart';
import '../../data/models/hazard_event.dart';

/// Pure rules that turn the current frame's detections into a single hazard.
/// Deliberately simple and explainable (no unverified ML claims): the demo warns
/// about stairs, obstacles, and doorways detected close/ahead.
class HazardEngine {
  HazardEvent evaluate(List<Detection> detections) {
    var worst = HazardEvent.clear();
    for (final d in detections) {
      final level = _levelFor(d);
      if (level.index > worst.level.index) {
        worst = HazardEvent(level: level, message: _message(d), source: d.label);
      }
    }
    return worst;
  }

  HazardLevel _levelFor(Detection d) {
    switch (d.kind) {
      case DetectionKind.stairs:
        return HazardLevel.warning;
      case DetectionKind.obstacle:
        return d.prominence >= 0.55 ? HazardLevel.danger : HazardLevel.warning;
      case DetectionKind.door:
        return HazardLevel.caution;
      default:
        return HazardLevel.none;
    }
  }

  String _message(Detection d) {
    switch (d.kind) {
      case DetectionKind.stairs:
        return 'Stairs ahead';
      case DetectionKind.obstacle:
        return 'Obstacle ahead';
      case DetectionKind.door:
        return 'Doorway ahead';
      default:
        return d.label;
    }
  }
}
