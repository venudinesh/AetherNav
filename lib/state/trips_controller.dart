import 'package:flutter/foundation.dart';

import '../data/app_database.dart';
import '../data/models/trip_record.dart';

/// Owns the saved-trip history (Strava-style). Reads from and writes to
/// [AppDatabase], newest first. Saving must never break the live trip, so
/// failures are swallowed — the trip still ran, it just isn't in the list.
class TripsController extends ChangeNotifier {
  final AppDatabase _db;
  TripsController(this._db);

  List<TripRecord> trips = [];

  Future<void> load() async {
    try {
      trips = await _db.trips();
    } catch (_) {}
    notifyListeners();
  }

  Future<void> add(TripRecord trip) async {
    try {
      await _db.insertTrip(trip);
      await load();
    } catch (_) {}
  }

  Future<void> delete(int id) async {
    try {
      await _db.deleteTrip(id);
      trips = trips.where((t) => t.id != id).toList();
      notifyListeners();
    } catch (_) {}
  }
}
