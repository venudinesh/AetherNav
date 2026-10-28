import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// State of the live-location subsystem, shown by the map.
enum LocationStatus {
  off, // live location disabled by the user
  requesting, // asking for permission / waiting for first fix
  denied, // permission refused
  deniedForever, // needs app settings to reset
  serviceOff, // device location services are off
  active, // streaming fixes
  error, // unexpected failure
}

/// Wraps geolocator: permission + service checks and the position stream.
/// Driven by the "Live location" setting.
class LocationController extends ChangeNotifier {
  LocationStatus status = LocationStatus.off;
  Position? position;
  String? error;

  bool _enabled = false;
  StreamSubscription<Position>? _sub;

  // Breadcrumbs of the current/last trip: GPS fixes while recording, drawn as
  // a polyline after the trip stops.
  final List<LatLng> track = [];
  bool _recording = false;

  /// Start a fresh breadcrumb track, seeded with the current fix.
  void startTrack() {
    track.clear();
    if (position != null) {
      track.add(LatLng(position!.latitude, position!.longitude));
    }
    _recording = true;
    notifyListeners();
  }

  /// Stop appending but keep the breadcrumb so it can be viewed after the trip.
  void stopTrack() {
    _recording = false;
    notifyListeners();
  }

  /// setEnabled is idempotent: re-sending the current value is ignored.
  Future<void> setEnabled(bool on) async {
    if (on == _enabled) return;
    _enabled = on;
    if (on) {
      await _start();
    } else {
      _stop();
    }
  }

  /// Retry after a denial or disabled service, without toggling the setting.
  Future<void> retry() async {
    if (!_enabled) {
      await setEnabled(true);
      return;
    }
    await _start();
  }

  Future<void> _start() async {
    if (_sub != null) return; // already streaming
    status = LocationStatus.requesting;
    error = null;
    notifyListeners();
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        status = LocationStatus.serviceOff;
        notifyListeners();
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        status = LocationStatus.deniedForever;
        notifyListeners();
        return;
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.unableToDetermine) {
        status = LocationStatus.denied;
        notifyListeners();
        return;
      }
      _sub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 1,
        ),
      ).listen(
        (p) {
          position = p;
          status = LocationStatus.active;
          error = null;
          // ponytail: 20 000-point cap (~20 km at the 1 m filter) so a trip left
          // running forever can't grow the list unbounded. Raise if longer walks
          // ever need mapping.
          if (_recording && track.length < 20000) {
            track.add(LatLng(p.latitude, p.longitude));
          }
          notifyListeners();
        },
        onError: (e) {
          error = e.toString();
          status = LocationStatus.error;
          notifyListeners();
        },
      );
    } catch (e) {
      error = e.toString();
      status = LocationStatus.error;
      notifyListeners();
    }
  }

  void _stop() {
    _sub?.cancel();
    _sub = null;
    status = LocationStatus.off;
    notifyListeners();
  }

  /// Opens the OS app-settings page (for a permanently-denied permission).
  Future<void> openAppSettings() => Geolocator.openAppSettings();

  /// Opens the OS location-services page (when the device's GPS is off).
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
