/// Categories of things worth logging during a session.
enum LogType { session, detection, hazard, voice, navigation }

extension LogTypeInfo on LogType {
  String get label => switch (this) {
        LogType.session => 'Session',
        LogType.detection => 'Detection',
        LogType.hazard => 'Hazard',
        LogType.voice => 'Voice',
        LogType.navigation => 'Navigation',
      };

  static LogType fromName(String s) =>
      LogType.values.firstWhere((e) => e.name == s, orElse: () => LogType.session);
}

/// One persisted log row. Stored locally in sqflite (no cloud, no laptop sync).
class TripLogEntry {
  final int? id;
  final DateTime time;
  final LogType type;
  final String summary;
  final String? detail;

  TripLogEntry({
    this.id,
    required this.time,
    required this.type,
    required this.summary,
    this.detail,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'ts': time.millisecondsSinceEpoch,
        'type': type.name,
        'summary': summary,
        'detail': detail,
      };

  factory TripLogEntry.fromMap(Map<String, Object?> m) => TripLogEntry(
        id: m['id'] as int?,
        time: DateTime.fromMillisecondsSinceEpoch(m['ts'] as int),
        type: LogTypeInfo.fromName(m['type'] as String),
        summary: m['summary'] as String,
        detail: m['detail'] as String?,
      );
}
