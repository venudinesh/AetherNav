import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../core/trip_math.dart';
import '../../data/models/trip_record.dart';

/// Read-only replay of a saved trip. When the trip has a GPS breadcrumb (Live
/// location was on) it's drawn Strava-style as a polyline on OpenStreetMap
/// tiles with start/finish markers and a stats card; a pure IMU trip (no track)
/// shows the same stats full-screen without any map tiles.
class TripPathScreen extends StatelessWidget {
  final TripRecord trip;
  const TripPathScreen({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trip')),
      body: trip.hasPath ? _withMap(context) : _statsOnly(context),
    );
  }

  Widget _withMap(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bounds = LatLngBounds.fromPoints(trip.track);
    return Stack(children: [
      FlutterMap(
        options: MapOptions(
          initialCameraFit: CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(56),
          ),
          minZoom: 3,
          maxZoom: 19,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'dev.aethernav.aethernav_edge',
            maxNativeZoom: 19,
          ),
          PolylineLayer(polylines: [
            Polyline(
              points: trip.track,
              strokeWidth: 5,
              color: scheme.primary,
              borderStrokeWidth: 2,
              borderColor: Colors.white.withValues(alpha: 0.7),
            ),
          ]),
          MarkerLayer(markers: [
            Marker(
              point: trip.track.first,
              width: 22,
              height: 22,
              child: Semantics(
                label: 'Trip start',
                child: const _EndDot(color: Color(0xFF16A34A)), // start: green
              ),
            ),
            Marker(
              point: trip.track.last,
              width: 22,
              height: 22,
              child: Semantics(
                label: 'Trip finish',
                child: _EndDot(color: scheme.error), // finish
              ),
            ),
          ]),
          RichAttributionWidget(
            attributions: const [
              TextSourceAttribution('© OpenStreetMap contributors'),
            ],
          ),
        ],
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _statsCard(context),
          ),
        ),
      ),
    ]);
  }

  /// Pure IMU trip: no geographic track, so show the stats full-screen with an
  /// honest note instead of an empty map.
  Widget _statsOnly(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _statsCard(context),
        const SizedBox(height: 12),
        Row(children: [
          Icon(Icons.info_outline, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No GPS path for this trip. Turn on Live location during a trip '
              'to map the route here.',
              style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _statsCard(BuildContext context) {
    final secs = trip.duration.inSeconds;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_stamp(trip.startTime),
              style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _Stat(
                label: 'Distance',
                value: '${trip.distanceMeters.toStringAsFixed(0)} m'),
            _Stat(label: 'Time', value: formatDuration(trip.duration)),
            _Stat(label: 'Steps', value: '${trip.steps}'),
          ]),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _Stat(
                label: 'Pace',
                value: formatPace(paceMinPerKm(trip.distanceMeters, secs))),
            _Stat(
                label: 'Speed',
                value:
                    '${speedKmh(trip.distanceMeters, secs).toStringAsFixed(1)} km/h'),
            _Stat(
                label: 'Cadence',
                value: '${cadenceSpm(trip.steps, secs).round()} spm'),
          ]),
          if (trip.hasPath) ...[
            const SizedBox(height: 12),
            Text('GPS path ≈ ${pathMeters(trip.track).toStringAsFixed(0)} m',
                style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ]),
      ),
    );
  }

  static String _stamp(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${months[d.month - 1]} ${d.day}, ${d.year} · $hh:$mm';
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(value, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
      Text(label, style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
    ]);
  }
}

/// A small filled dot with a white ring, used for the start/finish points.
class _EndDot extends StatelessWidget {
  final Color color;
  const _EndDot({required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 4,
              offset: const Offset(0, 1)),
        ],
      ),
    );
  }
}
