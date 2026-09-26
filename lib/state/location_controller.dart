import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Where the live-location subsystem currently stands, so the map can show an
/// honest state (off / locating / denied / service disabled / active / error)
/// instead of a silent blank map.
enum LocationStatus {
  off, // live location disabled by the user
  requesting, // asking for permission / waiting for the first fix
  denied, // permission refused this time
  deniedForever, // permission permanently refused (needs app settings)
  serviceOff, // device location services are turned off
  active, // streaming fixes
  error, // an unexpected failure
}

/// Owns geolocator: permission + service checks and the position stream. Driven
/// by the "Live location" setting; the map and any follow-me logic read
/// [position] and [status] from here.
///
/// This is the one subsystem that leaves the device (GPS + optional online map
/// tiles). It stays OFF until the user explicitly enables live location.
class LocationController extends ChangeNotifier {
  LocationStatus status = LocationStatus.off;
  Position? position;
  String? error;

  bool _enabled = false;
  StreamSubscription<Position>? _sub;

  // Breadcrumb of the current/last trip: every GPS fix while recording, drawn
  // Strava-style as a polyline once the trip stops. Only populated when live
  // location is streaming — a pure IMU trip leaves this empty.
  final List<LatLng> track = [];
  bool _recording = false;

  /// Begin a fresh breadcrumb for a new trip. Seeds with the current fix so the
  /// path starts at the trip's origin even before the next fix arrives.
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

  /// Enable/disable live location. Idempotent: unrelated settings changes that
  /// re-send the current value are ignored so we don't thrash the GPS stream.
  Future<void> setEnabled(bool on) async {
    if (on == _enabled) return;
    _enabled = on;
    if (on) {
      await _start();
    } else {
      _stop();
    }
  }

  /// Re-attempt after a denial or a disabled-service state, without toggling the
  /// user's setting off and on.
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
