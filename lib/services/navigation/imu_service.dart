import 'dart:async';
import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';

/// tilt-compensated magnetic heading (accel + mag) and step detection from
/// linear acceleration. dead-reckoning for the demo area, not real navigation.
class ImuService {
  final List<StreamSubscription<dynamic>> _subs = [];

  double heading = 0; // degrees, 0..360, smoothed
  bool hasHeading = false; // false until the first valid fused sample
  int steps = 0;
  bool moving = false;
  double stepLengthMeters = 0.75;

  void Function()? onUpdate;
  DateTime _lastStep = DateTime.fromMillisecondsSinceEpoch(0);

  // latest gravity vector (m/s^2, device frame) from raw accelerometer
  double _ax = 0, _ay = 0, _az = 0;
  bool _haveGravity = false;

  // smoothed in sin/cos space so the 359->0 wrap works
  double _sinH = 0, _cosH = 0;
  bool _haveFilter = false;
  static const double _alpha = 0.2;

  double get distanceMeters => steps * stepLengthMeters;

  void start() {
    if (_subs.isNotEmpty) return; // already streaming
    // raw accel: gravity for tilt compensation only
    _subs.add(accelerometerEventStream().listen((e) {
      _ax = e.x;
      _ay = e.y;
      _az = e.z;
      _haveGravity = true;
    }, onError: (_) {}));

    _subs.add(magnetometerEventStream().listen((e) {
      _updateHeading(e.x, e.y, e.z);
    }, onError: (_) {}));

    // linear accel (gravity removed) for step detection
    _subs.add(userAccelerometerEventStream().listen((e) {
      final magnitude = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
      moving = magnitude > 1.2;
      final now = DateTime.now();
      if (magnitude > 2.5 && now.difference(_lastStep).inMilliseconds > 350) {
        steps++;
        _lastStep = now;
        onUpdate?.call();
      }
    }, onError: (_) {}));
  }

  /// azimuth with tilt compensation, same math as Android's
  /// getRotationMatrix + getOrientation (H = E x A, M = A x H).
  void _updateHeading(double ex, double ey, double ez) {
    if (!_haveGravity) return;
    final ax = _ax, ay = _ay, az = _az;

    // H = E x A
    var hx = ey * az - ez * ay;
    var hy = ez * ax - ex * az;
    var hz = ex * ay - ey * ax;
    final normH = sqrt(hx * hx + hy * hy + hz * hz);
    if (normH < 0.1) return; // device near-parallel to the field: unreliable
    hx /= normH;
    hy /= normH;
    hz /= normH;

    final normA = sqrt(ax * ax + ay * ay + az * az);
    if (normA < 0.1) return;
    final nax = ax / normA, naz = az / normA;

    // M = A x H, only M_y is needed
    final my = naz * hx - nax * hz;

    final azimuth = atan2(hy, my); // radians, magnetic
    final s = sin(azimuth), c = cos(azimuth);
    if (_haveFilter) {
      _sinH = _alpha * s + (1 - _alpha) * _sinH;
      _cosH = _alpha * c + (1 - _alpha) * _cosH;
    } else {
      _sinH = s;
      _cosH = c;
      _haveFilter = true;
    }
    final deg = atan2(_sinH, _cosH) * 180 / pi;
    heading = (deg + 360) % 360;
    hasHeading = true;
    onUpdate?.call();
  }

  void reset() {
    steps = 0;
    moving = false;
  }

  void stop() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _haveGravity = false;
    _haveFilter = false;
  }
}
