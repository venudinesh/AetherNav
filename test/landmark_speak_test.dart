// Proves the Trip screen's landmark rows are accessible "Read out" buttons and
// that tapping one speaks the direction via TTS. Uses fake IMU/speech/TTS so no
// sensors or platform channels are touched.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aethernav_edge/data/app_database.dart';
import 'package:aethernav_edge/data/models/landmark.dart';
import 'package:aethernav_edge/services/navigation/imu_service.dart';
import 'package:aethernav_edge/services/voice/speech_service.dart';
import 'package:aethernav_edge/services/voice/tts_service.dart';
import 'package:aethernav_edge/state/location_controller.dart';
import 'package:aethernav_edge/state/navigation_controller.dart';
import 'package:aethernav_edge/state/trips_controller.dart';
import 'package:aethernav_edge/state/voice_controller.dart';
import 'package:aethernav_edge/theme/app_theme.dart';
import 'package:aethernav_edge/ui/screens/trip_screen.dart';

class _FakeImu extends ImuService {
  @override
  void start() {}
  @override
  void stop() {}
}

class _FakeSpeech extends SpeechService {
  @override
  Future<bool> init() async => true;
}

class _RecordingTts extends TtsService {
  final spoken = <String>[];
  @override
  Future<void> init() async {}
  @override
  Future<void> speak(String text) async => spoken.add(text);
  @override
  Future<void> stop() async {}
}

void main() {
  testWidgets('landmark row is a "Read out" button that speaks on tap',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final nav = NavigationController(prefs, imu: _FakeImu())
      ..map = const DemoMap(area: 'Test', landmarks: [
        Landmark(
            id: 'e1',
            name: 'Exit 1',
            kind: 'exit',
            bearing: 90,
            distanceMeters: 12),
      ])
      // TripScreen.initState calls start(); mark it running so that no-op's and
      // doesn't notifyListeners mid-build (harmless in the real app, where the
      // screen mounts after providers settle).
      ..running = true;
    final tts = _RecordingTts();
    final voice = VoiceController(speech: _FakeSpeech(), tts: tts)
      ..setMap(nav.map!);

    final handle = tester.ensureSemantics();
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: nav),
        ChangeNotifierProvider.value(value: voice),
        ChangeNotifierProvider.value(value: TripsController(AppDatabase.instance)),
        ChangeNotifierProvider.value(value: LocationController()),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: TripScreen()),
    ));
    await tester.pumpAndSettle();

    // Accessibility: the row is exposed as a button labelled "Read out Exit 1".
    expect(find.bySemanticsLabel(RegExp(r'Read out Exit 1')), findsOneWidget);

    // Interaction: tapping the row speaks the direction, honouring the map data.
    await tester.tap(find.text('Exit 1'));
    await tester.pump();
    expect(tts.spoken, isNotEmpty);
    expect(tts.spoken.last, contains('Exit 1'));
    expect(tts.spoken.last, contains('metres'));

    handle.dispose();
  });
}
