import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/trip_math.dart';
import '../../data/models/landmark.dart';
import '../../data/models/nav_state.dart';
import '../../data/models/trip_record.dart';
import '../../state/location_controller.dart';
import '../../state/navigation_controller.dart';
import '../../state/trips_controller.dart';
import '../widgets/app_states.dart';
import '../widgets/status_chip.dart';
import 'trip_path_screen.dart';

/// The Trip screen: a user-started span with a live distance, duration and step
/// count, plus the offline compass heading and the nearest known landmarks.
/// This is controlled-area dead-reckoning (IMU + step estimate), not GPS — the
/// copy stays honest about that.
class TripScreen extends StatefulWidget {
  const TripScreen({super.key});
  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  @override
  void initState() {
    super.initState();
    final nav = context.read<NavigationController>();
    nav.start();
    if (nav.map == null) nav.loadMap();
  }

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavigationController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip'),
        actions: [
          IconButton(
            tooltip: 'Reset',
            onPressed: nav.resetTrip,
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      body: _body(context, nav),
    );
  }
}

Widget _body(BuildContext context, NavigationController nav) {
  if (nav.map == null && nav.error != null) {
    return ErrorState(message: nav.error!, onRetry: nav.loadMap);
  }
  if (nav.map == null) {
    return const LoadingState(message: 'Loading map…');
  }
  return _TripContent(nav: nav);
}

class _TripContent extends StatelessWidget {
  final NavigationController nav;
  const _TripContent({required this.nav});
  @override
  Widget build(BuildContext context) {
    final snap = nav.snapshot;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final landmarks = nav.map!.landmarks;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _TripCard(nav: nav),
        const _PastTrips(),
        const SizedBox(height: 16),
        _HeadingCard(snap: snap),
        const SizedBox(height: 16),
        _StrideCard(nav: nav),
        const SizedBox(height: 24),
        Text('Landmarks',
            style: t.titleSmall?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        for (final lm in landmarks)
          _LandmarkTile(
            landmark: lm,
            heading: snap.headingDegrees,
            nearest: lm.id == snap.nearestLandmarkId,
          ),
      ],
    );
  }
}

/// The saved-trip history (Strava-style), newest first. Hidden when empty. Tap
/// a trip to replay it; swipe to delete. Trips are numbered oldest-first so
/// "Trip 1" is always the user's first recorded trip.
class _PastTrips extends StatelessWidget {
  const _PastTrips();
  @override
  Widget build(BuildContext context) {
    final trips = context.watch<TripsController>().trips;
    if (trips.isEmpty) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 24),
      Text('Past trips',
          style: t.titleSmall?.copyWith(color: scheme.onSurfaceVariant)),
      const SizedBox(height: 8),
      for (var i = 0; i < trips.length; i++)
        _PastTripTile(trip: trips[i], number: trips.length - i),
    ]);
  }
}

class _PastTripTile extends StatelessWidget {
  final TripRecord trip;
  final int number;
  const _PastTripTile({required this.trip, required this.number});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final subtitle = '${trip.distanceMeters.toStringAsFixed(0)} m · '
        '${formatDuration(trip.duration)} · ${_date(trip.startTime)}';
    final id = trip.id;
    final tile = Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(trip.hasPath ? Icons.route : Icons.timeline,
            color: scheme.onSurfaceVariant),
        title: Text('Trip $number', style: t.titleMedium),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TripPathScreen(trip: trip)),
        ),
      ),
    );
    if (id == null) return tile;
    return Dismissible(
      key: ValueKey(id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
            color: scheme.errorContainer,
            borderRadius: BorderRadius.circular(12)),
        child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
      ),
      confirmDismiss: (_) => _confirm(context),
      onDismissed: (_) => context.read<TripsController>().delete(id),
      child: tile,
    );
  }

  static String _date(DateTime d) => '${d.year}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<bool> _confirm(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete trip?'),
        content: const Text('This removes the saved trip permanently.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    return ok ?? false;
  }
}

class _TripCard extends StatelessWidget {
  final NavigationController nav;
  const _TripCard({required this.nav});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final active = nav.tripActive;
    final loc = context.watch<LocationController>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Trip', style: t.titleMedium),
            const Spacer(),
            StatusChip(
              label: active ? 'Recording' : 'Stopped',
              tone: active ? StatusTone.success : StatusTone.neutral,
              icon: active ? Icons.fiber_manual_record : Icons.stop,
            ),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: _TripMetric(
                    label: 'Distance',
                    value: '${nav.tripDistance.toStringAsFixed(0)} m')),
            Expanded(
                child: _TripMetric(
                    label: 'Time', value: formatDuration(nav.tripDuration))),
            Expanded(
                child:
                    _TripMetric(label: 'Steps', value: '${nav.tripSteps}')),
          ]),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: _TripMetric(
                    label: 'Avg speed',
                    value: '${nav.tripSpeedKmh.toStringAsFixed(1)} km/h')),
            Expanded(
                child: _TripMetric(
                    label: 'Cadence', value: '${nav.tripCadence.round()} spm')),
            Expanded(
                child: _TripMetric(
                    label: 'Stride',
                    value: '${nav.stepLengthMeters.toStringAsFixed(2)} m')),
          ]),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(
              child: active
                  ? FilledButton.icon(
                      onPressed: nav.stopTrip,
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop trip'),
                    )
                  : FilledButton.icon(
                      onPressed: nav.startTrip,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start trip'),
                    ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: nav.resetTrip,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset'),
            ),
          ]),
          if (nav.tripEnded) ...[
            const SizedBox(height: 12),
            if (loc.track.length >= 2)
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TripPathScreen(
                        trip: TripRecord(
                          startTime:
                              DateTime.now().subtract(nav.tripDuration),
                          duration: nav.tripDuration,
                          distanceMeters: nav.tripDistance,
                          steps: nav.tripSteps,
                          stepLengthMeters: nav.stepLengthMeters,
                          track: List.of(loc.track),
                        ),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('View path on map'),
                ),
              )
            else
              Text(
                'No path to map — turn on Live location before your trip to '
                'record it here.',
                style: t.bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
          ],
        ]),
      ),
    );
  }
}

class _TripMetric extends StatelessWidget {
  final String label;
  final String value;
  const _TripMetric({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        Text(label,
            style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
      ]),
    );
  }
}

class _HeadingCard extends StatelessWidget {
  final NavSnapshot snap;
  const _HeadingCard({required this.snap});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(children: [
          SizedBox(
            width: 84,
            height: 84,
            child: Stack(alignment: Alignment.center, children: [
              Container(
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.surfaceContainerHighest),
              ),
              Transform.rotate(
                angle: snap.headingDegrees * 3.1415926535897932 / 180,
                child: Icon(Icons.navigation, size: 40, color: scheme.primary),
              ),
            ]),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${snap.headingDegrees.toStringAsFixed(0)}° ${snap.cardinal}',
                      style:
                          t.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('Compass heading',
                      style:
                          t.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 10),
                  StatusChip(
                    label: snap.moving ? 'Moving' : 'Stationary',
                    tone: snap.moving ? StatusTone.success : StatusTone.neutral,
                    icon: snap.moving ? Icons.directions_walk : Icons.pause,
                  ),
                ]),
          ),
        ]),
      ),
    );
  }
}

class _StrideCard extends StatelessWidget {
  final NavigationController nav;
  const _StrideCard({required this.nav});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.straighten, color: scheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Text('Stride length', style: t.titleMedium),
            const Spacer(),
            Text('${nav.stepLengthMeters.toStringAsFixed(2)} m',
                style: t.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700, color: scheme.primary)),
          ]),
          Slider(
            value: nav.stepLengthMeters.clamp(0.4, 1.1),
            min: 0.4,
            max: 1.1,
            divisions: 14, // 0.05 m steps
            label: '${nav.stepLengthMeters.toStringAsFixed(2)} m',
            onChanged: nav.setStepLength,
          ),
          Text(
            'Calibrate to your own stride so the distance estimate stays honest. '
            'A typical adult stride is 0.65–0.80 m.',
            style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ]),
      ),
    );
  }
}

class _LandmarkTile extends StatelessWidget {
  final Landmark landmark;
  final double heading;
  final bool nearest;
  const _LandmarkTile({
    required this.landmark,
    required this.heading,
    required this.nearest,
  });
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final rel = relativeDirection(landmark.bearing, heading);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Icon(_iconFor(landmark.kind), color: scheme.onSurfaceVariant),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(child: Text(landmark.name, style: t.titleMedium)),
                    if (nearest) ...[
                      const SizedBox(width: 8),
                      const StatusChip(label: 'Nearest', tone: StatusTone.info),
                    ],
                  ]),
                  const SizedBox(height: 2),
                  Text('$rel · ${landmark.distanceMeters.toStringAsFixed(0)} m',
                      style:
                          t.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                ]),
          ),
        ]),
      ),
    );
  }

  IconData _iconFor(String kind) => switch (kind) {
        'exit' => Icons.logout,
        'stairs' => Icons.stairs_outlined,
        'door' => Icons.door_front_door_outlined,
        'room' => Icons.meeting_room_outlined,
        'hazard' => Icons.warning_amber_outlined,
        _ => Icons.place_outlined,
      };
}




