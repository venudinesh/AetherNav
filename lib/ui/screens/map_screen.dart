import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../state/location_controller.dart';
import '../../state/settings_controller.dart';

/// The live map: OpenStreetMap raster tiles with a hand-drawn "you are here"
/// dot (an accuracy circle + a marker) driven by [LocationController]. Unlike
/// the rest of the app this uses GPS and downloads tiles when online, so it
/// stays OFF until the user enables live location.
///
/// The blue dot is drawn manually (CircleLayer + MarkerLayer) rather than via
/// flutter_map_location_marker, which pins older flutter_map / latlong2 and
/// would drag the whole map stack backwards.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  final MapController _mc = MapController();
  bool _ready = false;
  LatLng? _lastCentered;

  // A neutral fallback centre until the first fix arrives.
  static const LatLng _fallback = LatLng(12.9716, 77.5946); // Bengaluru

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mc.dispose();
    super.dispose();
  }

  /// Coming back from the OS location/permission settings screen: re-attempt the
  /// GPS stream so turning on location there takes effect without toggling the
  /// app's own switch off and on. retry() is idempotent — a no-op while already
  /// streaming.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      final settings = context.read<SettingsController>();
      if (settings.liveLocation) context.read<LocationController>().retry();
    }
  }

  void _recenter(LatLng p) {
    context.read<SettingsController>().setFollowLocation(true);
    if (_ready) _mc.move(p, 17);
    _lastCentered = p;
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final loc = context.watch<LocationController>();
    final p = loc.position;
    final here = p != null ? LatLng(p.latitude, p.longitude) : null;

    // Follow-me: recenter on each new fix while "keep centred" is on.
    if (here != null &&
        settings.followLocation &&
        _ready &&
        here != _lastCentered) {
      _lastCentered = here;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mc.move(here, _mc.camera.zoom);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Map'),
        actions: [
          IconButton(
            tooltip:
                settings.followLocation ? 'Following' : 'Follow location',
            icon: Icon(settings.followLocation
                ? Icons.my_location
                : Icons.location_searching),
            onPressed: () => context
                .read<SettingsController>()
                .setFollowLocation(!settings.followLocation),
          ),
        ],
      ),
      body: Stack(children: [
        // The map downloads OSM tiles over the network, so it only renders once
        // the user opts into live location — otherwise the tab stays offline.
        if (settings.liveLocation)
          _map(here, p?.accuracy ?? 0)
        else
          _offlinePlaceholder(context),
        _banner(context, settings, loc),
      ]),
      floatingActionButton: settings.liveLocation && here != null
          ? FloatingActionButton(
              onPressed: () => _recenter(here),
              tooltip: 'Recenter',
              child: const Icon(Icons.gps_fixed),
            )
          : null,
    );
  }

  /// Shown in place of the map while live location is off, so the tab isn't a
  /// blank void and no tiles are fetched. The banner on top offers "Turn on".
  Widget _offlinePlaceholder(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surfaceContainerLow,
      alignment: Alignment.center,
      child: Icon(Icons.map_outlined,
          size: 72, color: scheme.onSurfaceVariant.withValues(alpha: 0.4)),
    );
  }

  Widget _map(LatLng? here, double accuracy) {
    final scheme = Theme.of(context).colorScheme;
    return FlutterMap(
      mapController: _mc,
      options: MapOptions(
        initialCenter: here ?? _fallback,
        initialZoom: 16,
        minZoom: 3,
        maxZoom: 19,
        onMapReady: () {
          _ready = true;
          if (here != null) {
            _mc.move(here, 17);
            _lastCentered = here;
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'dev.aethernav.aethernav_edge',
          maxNativeZoom: 19,
        ),
        if (here != null && accuracy > 0)
          CircleLayer(circles: [
            CircleMarker(
              point: here,
              radius: accuracy,
              useRadiusInMeter: true,
              color: scheme.primary.withValues(alpha: 0.15),
              borderColor: scheme.primary.withValues(alpha: 0.4),
              borderStrokeWidth: 1,
            ),
          ]),
        if (here != null)
          MarkerLayer(markers: [
            Marker(
              point: here,
              width: 26,
              height: 26,
              child: Semantics(
                label: 'Your location',
                child: _Dot(color: scheme.primary),
              ),
            ),
          ]),
        RichAttributionWidget(
          attributions: const [
            TextSourceAttribution('© OpenStreetMap contributors'),
          ],
        ),
      ],
    );
  }

  Widget _banner(
      BuildContext context, SettingsController settings, LocationController loc) {
    if (!settings.liveLocation) {
      return _Banner(
        icon: Icons.location_off,
        text: 'Live location is off. Turn it on to see your position.',
        actionLabel: 'Turn on',
        onAction: () =>
            context.read<SettingsController>().setLiveLocation(true),
      );
    }
    switch (loc.status) {
      case LocationStatus.active:
        return const SizedBox.shrink();
      case LocationStatus.requesting:
        return const _Banner(icon: Icons.my_location, text: 'Locating…');
      case LocationStatus.denied:
        return _Banner(
          icon: Icons.location_disabled,
          text: 'Location permission denied.',
          actionLabel: 'Try again',
          onAction: loc.retry,
        );
      case LocationStatus.deniedForever:
        return _Banner(
          icon: Icons.location_disabled,
          text: 'Location permission is blocked. Enable it in system settings.',
          actionLabel: 'Open settings',
          onAction: loc.openAppSettings,
        );
      case LocationStatus.serviceOff:
        return _Banner(
          icon: Icons.gps_off,
          text: 'Device location services are off.',
          actionLabel: 'Open settings',
          onAction: loc.openLocationSettings,
        );
      case LocationStatus.error:
        return _Banner(
          icon: Icons.error_outline,
          text: loc.error ?? 'Location error.',
          actionLabel: 'Try again',
          onAction: loc.retry,
        );
      case LocationStatus.off:
        return _Banner(
          icon: Icons.location_off,
          text: 'Live location is off.',
          actionLabel: 'Turn on',
          onAction: loc.retry,
        );
    }
  }
}

/// The "you are here" dot: a filled circle with a white ring, matching common
/// map conventions.
class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});
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

/// A top-of-map status banner explaining why there's no live position, with an
/// optional action (turn on / try again / open settings).
class _Banner extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _Banner({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Material(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
              child: Row(children: [
                Icon(icon, size: 20, color: scheme.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(child: Text(text, style: t.bodyMedium)),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(width: 8),
                  TextButton(onPressed: onAction, child: Text(actionLabel!)),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}




