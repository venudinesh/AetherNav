import 'dart:convert';

import 'package:latlong2/latlong.dart';

/// One saved trip (Strava-style history): the IMU-derived distance/steps/
/// duration, plus a GPS breadcrumb to replay on the map when Live location was
/// on during the trip. Persisted locally in sqflite. The track is stored as a
/// JSON array of `[lat, lng]` pairs; a pure IMU trip stores an empty track.
class TripRecord {
  final int? id;
  final DateTime startTime;
  final Duration duration;
  final double distanceMeters;
  final int steps;
  final double stepLengthMeters;
  final List<LatLng> track;

  const TripRecord({
    this.id,
    required this.startTime,
    required this.duration,
    required this.distanceMeters,
    required this.steps,
    required this.stepLengthMeters,
    this.track = const [],
  });

  /// A geographic path exists only if two or more GPS fixes were recorded.
  bool get hasPath => track.length >= 2;

  Map<String, Object?> toMap() => {
        'id': id,
        'start_ts': startTime.millisecondsSinceEpoch,
        'duration_ms': duration.inMilliseconds,
        'distance_m': distanceMeters,
        'steps': steps,
        'step_len_m': stepLengthMeters,
        'track':
            jsonEncode(track.map((p) => [p.latitude, p.longitude]).toList()),
      };

  factory TripRecord.fromMap(Map<String, Object?> m) => TripRecord(
        id: m['id'] as int?,
        startTime: DateTime.fromMillisecondsSinceEpoch(m['start_ts'] as int),
        duration: Duration(milliseconds: m['duration_ms'] as int),
        distanceMeters: (m['distance_m'] as num).toDouble(),
        steps: (m['steps'] as num).toInt(),
        stepLengthMeters: (m['step_len_m'] as num).toDouble(),
        track: _decodeTrack(m['track'] as String?),
      );

  static List<LatLng> _decodeTrack(String? s) {
    if (s == null || s.isEmpty) return const [];
    final decoded = jsonDecode(s) as List;
    return [
      for (final p in decoded)
        LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()),
    ];
  }
}
