import 'package:vibration/vibration.dart';

import '../../data/models/hazard_event.dart';

/// Haptic feedback for hazards. Patterns escalate with severity. Safe no-op when
/// the device has no vibrator or the platform call fails.
class HapticService {
  bool _hasVibrator = false;

  Future<void> init() async {
    try {
      _hasVibrator = await Vibration.hasVibrator();
    } catch (_) {
      _hasVibrator = false;
    }
  }

  Future<void> forHazard(HazardLevel level) async {
    if (!_hasVibrator) return;
    try {
      switch (level) {
        case HazardLevel.danger:
          await Vibration.vibrate(pattern: [0, 200, 100, 200, 100, 350]);
          break;
        case HazardLevel.warning:
          await Vibration.vibrate(duration: 240);
          break;
        case HazardLevel.caution:
          await Vibration.vibrate(duration: 90);
          break;
        case HazardLevel.none:
          break;
      }
    } catch (_) {
      // Ignore: haptics are a non-critical enhancement.
    }
  }
}
