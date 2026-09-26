import 'package:sqflite/sqflite.dart';

import 'models/trip_log.dart';
import 'models/trip_record.dart';

/// Local, offline SQLite store for trip / hazard / voice logs and saved trips.
/// Everything stays on the device; there is no network or laptop sync
/// (standalone app).
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    final path = '$dir/aethernav_edge.db';
    _db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await _createLog(db);
        await _createTrips(db);
      },
      onUpgrade: (db, oldV, newV) async {
        // v1 → v2 added the saved-trips table. Idempotent so a partial upgrade
        // can be re-run safely.
        if (oldV < 2) await _createTrips(db);
      },
    );
    return _db!;
  }

  Future<void> _createLog(Database db) async {
    await db.execute('''
      CREATE TABLE trip_log(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ts INTEGER NOT NULL,
        type TEXT NOT NULL,
        summary TEXT NOT NULL,
        detail TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_trip_log_ts ON trip_log(ts DESC)');
  }

  Future<void> _createTrips(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS trips(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start_ts INTEGER NOT NULL,
        duration_ms INTEGER NOT NULL,
        distance_m REAL NOT NULL,
        steps INTEGER NOT NULL,
        step_len_m REAL NOT NULL,
        track TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_trips_start ON trips(start_ts DESC)');
  }

  Future<int> insert(TripLogEntry entry) async {
    final db = await database;
    final map = entry.toMap()..remove('id');
    return db.insert('trip_log', map);
  }

  Future<List<TripLogEntry>> recent({int limit = 300}) async {
    final db = await database;
    final rows = await db.query('trip_log', orderBy: 'ts DESC', limit: limit);
    return rows.map(TripLogEntry.fromMap).toList();
  }

  Future<Map<String, int>> countsByType() async {
    final db = await database;
    final rows = await db
        .rawQuery('SELECT type, COUNT(*) AS c FROM trip_log GROUP BY type');
    return {for (final r in rows) r['type'] as String: r['c'] as int};
  }

  Future<int> clearAll() async {
    final db = await database;
    return db.delete('trip_log');
  }

  // --- Saved trips (Strava-style history) ---

  Future<int> insertTrip(TripRecord trip) async {
    final db = await database;
    final map = trip.toMap()..remove('id');
    return db.insert('trips', map);
  }

  Future<List<TripRecord>> trips({int limit = 200}) async {
    final db = await database;
    final rows =
        await db.query('trips', orderBy: 'start_ts DESC', limit: limit);
    return rows.map(TripRecord.fromMap).toList();
  }

  Future<int> deleteTrip(int id) async {
    final db = await database;
    return db.delete('trips', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> clearTrips() async {
    final db = await database;
    return db.delete('trips');
  }
}
