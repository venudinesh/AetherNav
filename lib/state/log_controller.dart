import 'package:flutter/foundation.dart';

import '../data/app_database.dart';
import '../data/models/trip_log.dart';

enum LoadStatus { loading, ready, error }

/// The local trip/hazard/voice log, backed by [AppDatabase].
class LogController extends ChangeNotifier {
  final AppDatabase _db;
  LogController(this._db);

  LoadStatus status = LoadStatus.loading;
  List<TripLogEntry> entries = [];
  Map<String, int> counts = {};
  String? error;

  Future<void> load() async {
    status = LoadStatus.loading;
    notifyListeners();
    try {
      entries = await _db.recent();
      counts = await _db.countsByType();
      status = LoadStatus.ready;
    } catch (e) {
      error = e.toString();
      status = LoadStatus.error;
    }
    notifyListeners();
  }

  Future<void> add(LogType type, String summary, {String? detail}) async {
    try {
      final now = DateTime.now();
      final id = await _db.insert(
          TripLogEntry(time: now, type: type, summary: summary, detail: detail));
      entries = [
        TripLogEntry(id: id, time: now, type: type, summary: summary, detail: detail),
        ...entries,
      ];
      counts = {...counts, type.name: (counts[type.name] ?? 0) + 1};
      notifyListeners();
    } catch (_) {
      // Logging failures shouldn't break the app.
    }
  }

  Future<void> clear() async {
    try {
      await _db.clearAll();
      entries = [];
      counts = {};
      notifyListeners();
    } catch (_) {}
  }
}
