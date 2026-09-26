import 'package:latlong2/latlong.dart';

/// Pure, dependency-light trip helpers shared by the Trip screens and covered by
/// unit tests. Keeping them here (not private to a widget) is what makes the
/// distance/direction/format logic testable without booting the UI.

/// `mm:ss`, or `h:mm:ss` once the duration passes an hour.
String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

/// Human-relative direction of a landmark at [bearing] degrees while the user
/// faces [heading] degrees. Both are 0..360 compass degrees.
String relativeDirection(double bearing, double heading) {
  final delta = (((bearing - heading) + 540) % 360) - 180;
  final a = delta.abs();
  if (a <= 20) return 'Straight ahead';
  if (a >= 160) return 'Behind you';
  final side = delta > 0 ? 'right' : 'left';
  if (a < 70) return 'Ahead, to your $side';
  return 'To your $side';
}

/// Ground distance in metres along a GPS breadcrumb — an independent check on
/// the IMU step estimate. Returns 0 for a track of fewer than two points.
double pathMeters(List<LatLng> track) {
  const d = Distance();
  var m = 0.0;
  for (var i = 1; i < track.length; i++) {
    m += d.as(LengthUnit.Meter, track[i - 1], track[i]);
  }
  return m;
}

/// Average speed in km/h from [distanceMeters] over [seconds]. Returns 0 when
/// [seconds] <= 0 (no elapsed time to divide by).
double speedKmh(double distanceMeters, int seconds) =>
    seconds <= 0 ? 0 : distanceMeters / seconds * 3.6; // m/s -> km/h

/// Cadence in steps per minute from [steps] over [seconds]. Returns 0 when
/// [seconds] <= 0.
double cadenceSpm(int steps, int seconds) =>
    seconds <= 0 ? 0 : steps / seconds * 60;

/// Pace in minutes per kilometre. Returns null when there's no meaningful
/// distance or time to divide (pace is undefined for a standing-still trip).
double? paceMinPerKm(double distanceMeters, int seconds) {
  if (distanceMeters < 1 || seconds <= 0) return null;
  return (seconds / 60) / (distanceMeters / 1000);
}

/// `m:ss /km`, or an em dash when pace is undefined.
String formatPace(double? minPerKm) {
  if (minPerKm == null || !minPerKm.isFinite) return '—';
  final total = (minPerKm * 60).round();
  return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')} /km';
}
