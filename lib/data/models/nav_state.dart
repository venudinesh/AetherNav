/// A point-in-time snapshot of the offline navigation estimate.
///
/// This is deliberately a *controlled-environment* estimate (IMU dead-reckoning
/// + visual landmarks), NOT universal GPS-free navigation.
class NavSnapshot {
  final double headingDegrees; // 0..360, device compass heading
  final int stepCount; // steps since session start
  final double distanceMeters; // rough distance from step length
  final bool moving;
  final String? nearestLandmarkId;
  final String? nearestLandmarkName;

  const NavSnapshot({
    this.headingDegrees = 0,
    this.stepCount = 0,
    this.distanceMeters = 0,
    this.moving = false,
    this.nearestLandmarkId,
    this.nearestLandmarkName,
  });

  NavSnapshot copyWith({
    double? headingDegrees,
    int? stepCount,
    double? distanceMeters,
    bool? moving,
    String? nearestLandmarkId,
    String? nearestLandmarkName,
  }) {
    return NavSnapshot(
      headingDegrees: headingDegrees ?? this.headingDegrees,
      stepCount: stepCount ?? this.stepCount,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      moving: moving ?? this.moving,
      nearestLandmarkId: nearestLandmarkId ?? this.nearestLandmarkId,
      nearestLandmarkName: nearestLandmarkName ?? this.nearestLandmarkName,
    );
  }

  /// Compass heading as a cardinal string, e.g. "NE".
  String get cardinal {
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return dirs[(((headingDegrees % 360) / 45).round()) % 8];
  }
}
