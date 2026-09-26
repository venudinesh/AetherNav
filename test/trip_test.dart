// Unit tests for the pure trip math and the NavigationController's trip
// bookkeeping. A fake IMU stands in for the on-device sensors so the trip
// counters can be driven deterministically without booting the sensor stack.

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aethernav_edge/core/trip_math.dart';
import 'package:aethernav_edge/data/models/landmark.dart';
import 'package:aethernav_edge/data/models/trip_record.dart';
import 'package:aethernav_edge/services/navigation/imu_service.dart';
import 'package:aethernav_edge/services/voice/voice_interaction.dart';
import 'package:aethernav_edge/state/navigation_controller.dart';

/// A sensor-free IMU: [start]/[stop] are no-ops so no real streams open, and
/// [steps]/[stepLengthMeters] are set directly by the tests.
class _FakeImu extends ImuService {
  @override
  void start() {}
  @override
  void stop() {}
}

void main() {
  group('trip_math', () {
    test('formatDuration switches to h:mm:ss past an hour', () {
      expect(formatDuration(const Duration(seconds: 5)), '00:05');
      expect(formatDuration(const Duration(minutes: 3, seconds: 7)), '03:07');
      expect(formatDuration(const Duration(hours: 1, minutes: 2, seconds: 9)),
          '1:02:09');
    });

    test('relativeDirection reads out ahead/behind/left/right', () {
      expect(relativeDirection(0, 0), 'Straight ahead');
      expect(relativeDirection(180, 0), 'Behind you');
      expect(relativeDirection(90, 0), contains('right'));
      expect(relativeDirection(270, 0), contains('left'));
    });

    test('pathMeters is 0 for < 2 points and ~metres otherwise', () {
      expect(pathMeters(const []), 0);
      expect(pathMeters(const [LatLng(0, 0)]), 0);
      // 0.001 degrees of latitude at the equator is ~111 m.
      expect(pathMeters(const [LatLng(0, 0), LatLng(0.001, 0)]),
          closeTo(111, 3));
    });

    test('speedKmh guards zero/negative time', () {
      expect(speedKmh(100, 0), 0);
      expect(speedKmh(100, -5), 0);
      expect(speedKmh(1000, 360), closeTo(10, 1e-9)); // 1 km in 6 min
    });

    test('cadenceSpm guards zero/negative time', () {
      expect(cadenceSpm(10, 0), 0);
      expect(cadenceSpm(120, 60), closeTo(120, 1e-9));
    });

    test('paceMinPerKm and formatPace: 1 km in 6 min = 6:00 /km', () {
      expect(paceMinPerKm(0, 60), isNull); // no distance -> undefined
      expect(paceMinPerKm(1000, 0), isNull); // no time -> undefined
      expect(paceMinPerKm(1000, 360), closeTo(6, 1e-9));
      expect(formatPace(paceMinPerKm(1000, 360)), '6:00 /km');
      expect(formatPace(null), '—');
    });
  });

  group('NavigationController', () {
    late SharedPreferences prefs;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('tripDistance = trip steps x stride', () {
      final imu = _FakeImu();
      final nav = NavigationController(prefs, imu: imu);
      nav.setStepLength(0.8);
      nav.startTrip(); // baseline captured at 0 steps
      imu.steps = 10;
      expect(nav.tripSteps, 10);
      expect(nav.tripDistance, closeTo(8.0, 1e-9));
      nav.dispose();
    });

    test('stopTrip freezes the counters even if the IMU keeps counting', () {
      final imu = _FakeImu();
      final nav = NavigationController(prefs, imu: imu);
      nav.startTrip();
      imu.steps = 5;
      nav.stopTrip();
      expect(nav.tripSteps, 5);
      imu.steps = 50; // user keeps walking after the trip ended
      expect(nav.tripSteps, 5); // still frozen at the stop value
      nav.dispose();
    });

    test('tripSteps never goes negative when the counter drops below baseline',
        () {
      final imu = _FakeImu()..steps = 20;
      final nav = NavigationController(prefs, imu: imu);
      nav.startTrip(); // baseline 20
      imu.steps = 5; // counter reset below the baseline
      expect(nav.tripSteps, 0);
      nav.dispose();
    });

    test('setStepLength clamps to 0.4-1.1 and persists across instances', () {
      final nav = NavigationController(prefs, imu: _FakeImu());
      nav.setStepLength(5.0);
      expect(nav.stepLengthMeters, 1.1);
      nav.setStepLength(0.1);
      expect(nav.stepLengthMeters, 0.4);
      nav.dispose();
      // A fresh controller reads the persisted stride back on construction.
      final restored = NavigationController(prefs, imu: _FakeImu());
      expect(restored.stepLengthMeters, 0.4);
      restored.dispose();
    });
  });

  group('TripRecord', () {
    test('toMap/fromMap round-trips including the GPS track', () {
      final trip = TripRecord(
        id: 7,
        startTime: DateTime(2024, 1, 2, 3, 4, 5),
        duration: const Duration(minutes: 12, seconds: 34),
        distanceMeters: 842.5,
        steps: 1100,
        stepLengthMeters: 0.75,
        track: const [LatLng(12.9716, 77.5946), LatLng(12.9720, 77.5950)],
      );
      final back = TripRecord.fromMap(trip.toMap());
      expect(back.id, 7);
      expect(back.startTime, trip.startTime);
      expect(back.duration, trip.duration);
      expect(back.distanceMeters, closeTo(842.5, 1e-9));
      expect(back.steps, 1100);
      expect(back.stepLengthMeters, closeTo(0.75, 1e-9));
      expect(back.track.length, 2);
      expect(back.track.first.latitude, closeTo(12.9716, 1e-9));
      expect(back.track.last.longitude, closeTo(77.5950, 1e-9));
      expect(back.hasPath, isTrue);
    });

    test('an empty track stays empty and has no path', () {
      final back = TripRecord.fromMap(TripRecord(
        startTime: DateTime(2024),
        duration: const Duration(minutes: 1),
        distanceMeters: 0,
        steps: 0,
        stepLengthMeters: 0.7,
      ).toMap());
      expect(back.track, isEmpty);
      expect(back.hasPath, isFalse);
    });
  });

  group('VoiceInteraction', () {
    // A one-landmark demo map is enough to prove small talk doesn't get treated
    // as a place lookup, and that a real place query still resolves.
    const map = DemoMap(area: 'Test area', landmarks: [
      Landmark(
          id: 'e4', name: 'Exit 4', kind: 'exit', bearing: 90, distanceMeters: 30),
    ]);
    const voice = VoiceInteraction(map);

    test('"hello" is answered as a greeting, not a navigation miss', () {
      final spoken = voice.answer('hello').spoken;
      expect(spoken, contains('Hello'));
      expect(spoken, isNot(contains('metres'))); // not a distance readout
      expect(spoken.toLowerCase(), isNot(contains("don't"))); // not the miss text
    });

    test('a real place query still resolves with a grounded distance', () {
      final spoken = voice.answer('where is exit 4').spoken;
      expect(spoken, contains('Exit 4'));
      expect(spoken, contains('metres'));
    });
  });
}
