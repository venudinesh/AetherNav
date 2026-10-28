import 'package:flutter/foundation.dart';

import '../data/app_database.dart';
import '../data/models/trip_record.dart';

/// Saved trip history, newest first. Write failures are swallowed so a
/// failed save can't break the live trip.
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
