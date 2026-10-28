import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/trip_math.dart';
import '../data/models/landmark.dart';
import '../data/models/nav_state.dart';
import '../services/navigation/imu_service.dart';

/// Navigation estimate from the IMU plus trip tracking. Trip numbers are
/// deltas from the IMU's running counters, so resetting mid-trip is safe.
class NavigationController extends ChangeNotifier {
  NavigationController(this._prefs, {ImuService? imu})
      : _imu = imu ?? ImuService() {
    final s = _prefs.getDouble(_kStride);
    if (s != null) _imu.stepLengthMeters = s.clamp(0.4, 1.1);
  }

  final SharedPreferences _prefs;
  static const _kStride = 'stepLength';

  final ImuService _imu;

  DemoMap? map;
  NavSnapshot snapshot = const NavSnapshot();
  bool running = false;
  String? error;

  // Trip state.
  bool tripActive = false;
  DateTime? _tripStart;
  int _tripStartSteps = 0;
  Timer? _tripTimer;
  // Frozen at stop so the final numbers don't move after the trip ends.
  DateTime? _tripEnd;
  int? _tripEndSteps;

  /// Fired when a trip is stopped, with its final distance, duration and steps.
  void Function(double distanceMeters, Duration duration, int steps)?
      onTripComplete;

  /// Fired when a trip starts (e.g. for GPS breadcrumb recording).
  void Function()? onTripStart;

  /// True after a trip is stopped, until reset or a new one starts.
  bool get tripEnded => _tripEnd != null && !tripActive;

  double get heading => _imu.heading;
  bool get hasHeading => _imu.hasHeading;

  int get tripSteps {
    final end = _tripEndSteps ?? _imu.steps;
    final d = end - _tripStartSteps;
    return d < 0 ? 0 : d;
  }

  double get tripDistance => tripSteps * _imu.stepLengthMeters;

  Duration get tripDuration {
    if (_tripStart == null) return Duration.zero;
    final end = _tripEnd ?? DateTime.now();
    final d = end.difference(_tripStart!);
    return d.isNegative ? Duration.zero : d;
  }

  /// Trip-average speed in km/h.
  double get tripSpeedKmh => speedKmh(tripDistance, tripDuration.inSeconds);

  /// Trip-average cadence in steps per minute.
  double get tripCadence => cadenceSpm(tripSteps, tripDuration.inSeconds);

  /// Step length used to turn steps into distance; user-calibratable.
  double get stepLengthMeters => _imu.stepLengthMeters;

  void setStepLength(double meters) {
    _imu.stepLengthMeters = meters.clamp(0.4, 1.1);
    _prefs.setDouble(_kStride, _imu.stepLengthMeters);
    notifyListeners();
  }

  Future<void> loadMap() async {
    try {
      map = await DemoMap.load();
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  void start() {
    if (running) return;
    _imu.onUpdate = _onImu;
    _imu.start();
    running = true;
    notifyListeners();
  }

  void startTrip() {
    if (!running) start();
    _tripStart = DateTime.now();
    _tripStartSteps = _imu.steps;
    _tripEnd = null;
    _tripEndSteps = null;
    tripActive = true;
    // 1s heartbeat keeps the duration ticking while standing still.
    _tripTimer?.cancel();
    _tripTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (tripActive) notifyListeners();
    });
    onTripStart?.call();
    notifyListeners();
  }

  void stopTrip() {
    if (!tripActive) return;
    // Freeze counters first so the getters report final values.
    _tripEnd = DateTime.now();
    _tripEndSteps = _imu.steps;
    final distance = tripDistance;
    final duration = tripDuration;
    final steps = tripSteps;
    tripActive = false;
    _tripTimer?.cancel();
    _tripTimer = null;
    onTripComplete?.call(distance, duration, steps);
    notifyListeners();
  }

  /// Resets the trip baseline to now; also zeroes the IMU step counter.
  void resetTrip() {
    _imu.reset();
    _tripStartSteps = 0;
    _tripEndSteps = null;
    // Rebase while recording; clear when stopped so it reads 0.
    _tripStart = tripActive ? DateTime.now() : null;
    _tripEnd = null;
    _onImu();
  }

  void _onImu() {
    final nearest = _nearest();
    snapshot = snapshot.copyWith(
      headingDegrees: _imu.heading,
      stepCount: _imu.steps,
      distanceMeters: _imu.distanceMeters,
      moving: _imu.moving,
      nearestLandmarkId: nearest?.id,
      nearestLandmarkName: nearest?.name,
    );
    notifyListeners();
  }

  Landmark? _nearest() {
    final m = map;
    if (m == null || m.landmarks.isEmpty) return null;
    Landmark? best;
    var bestDelta = 999.0;
    for (final lm in m.landmarks) {
      final d = ((((lm.bearing - _imu.heading) + 540) % 360) - 180).abs();
      if (d < bestDelta) {
        bestDelta = d;
        best = lm;
      }
    }
    return best;
  }

  void reset() {
    _imu.reset();
    _tripStartSteps = 0;
    _onImu();
  }

  void stop() {
    _tripTimer?.cancel();
    _tripTimer = null;
    tripActive = false;
    _imu.stop();
    running = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _tripTimer?.cancel();
    _imu.stop();
    super.dispose();
  }
}
