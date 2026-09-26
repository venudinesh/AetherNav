// Unit tests for AetherNav Edge's pure-Dart domain logic. Widget/integration
// coverage is intentionally omitted here because the app boots from on-device
// services (camera, TTS, sensors, SQLite) that aren't available in the test VM.

import 'package:flutter_test/flutter_test.dart';

import 'package:aethernav_edge/data/models/hazard_event.dart';
import 'package:aethernav_edge/data/models/trip_log.dart';

void main() {
  group('HazardLevel', () {
    test('severity increases with index', () {
      expect(HazardLevel.none.index, lessThan(HazardLevel.caution.index));
      expect(HazardLevel.caution.index, lessThan(HazardLevel.warning.index));
      expect(HazardLevel.warning.index, lessThan(HazardLevel.danger.index));
    });

    test('only warning and danger raise an alert', () {
      expect(HazardLevel.none.shouldAlert, isFalse);
      expect(HazardLevel.caution.shouldAlert, isFalse);
      expect(HazardLevel.warning.shouldAlert, isTrue);
      expect(HazardLevel.danger.shouldAlert, isTrue);
    });

    test('clear() is a none-level "Path clear" event', () {
      final e = HazardEvent.clear();
      expect(e.level, HazardLevel.none);
      expect(e.message, 'Path clear');
    });
  });

  group('LogType', () {
    test('fromName round-trips every value', () {
      for (final type in LogType.values) {
        expect(LogTypeInfo.fromName(type.name), type);
      }
    });

    test('fromName falls back to session on unknown input', () {
      expect(LogTypeInfo.fromName('nope'), LogType.session);
    });
  });
}
