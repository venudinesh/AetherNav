import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/app_database.dart';
import 'data/models/trip_log.dart';
import 'data/models/trip_record.dart';
import 'services/hazard/haptic_service.dart';
import 'services/llm/llm_service.dart';
import 'services/voice/speech_service.dart';
import 'services/voice/tts_service.dart';
import 'state/location_controller.dart';
import 'state/llm_controller.dart';
import 'state/log_controller.dart';
import 'state/navigation_controller.dart';
import 'state/perception_controller.dart';
import 'state/settings_controller.dart';
import 'state/trips_controller.dart';
import 'state/voice_controller.dart';

/// Boots services + controllers, wires their cross-callbacks, primes offline
/// data, then runs [AetherNavApp].
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Portrait only: it's a handheld aid, and the short landscape viewport
  // crams the camera idle screen against the nav bar.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // On-device services.
  final db = AppDatabase.instance;
  final haptic = HapticService();
  await haptic.init();
  final tts = TtsService();
  await tts.init();
  final speech = SpeechService();

  // Controllers.
  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsController(prefs);
  final log = LogController(db);
  final navigation = NavigationController(prefs);
  final perception = PerceptionController();
  final voice = VoiceController(speech: speech, tts: tts);
  final location = LocationController();
  final llm = LlmController(LlmService(), settings);
  await llm.init(); // resume any background download + wire the OS notification
  final trips = TripsController(db);

  // Push the current settings to TTS / GPS / LLM (setEnabled is idempotent).
  tts.enabled = settings.voiceEnabled;
  location.setEnabled(settings.liveLocation);
  llm.setEnabled(settings.useLocalLlm);
  settings.addListener(() {
    tts.enabled = settings.voiceEnabled;
    location.setEnabled(settings.liveLocation);
    llm.setEnabled(settings.useLocalLlm);
  });

  // Cross-controller wiring lives here, not inside the controllers.
  perception.onHazard = (hz) {
    if (settings.hapticsEnabled) haptic.forHazard(hz.level);
    if (settings.voiceEnabled) tts.speak(hz.message);
    log.add(LogType.hazard, hz.message);
  };
  perception.onDetection = (d) => log.add(LogType.detection, d.label);
  voice.headingProvider = () => navigation.heading;
  voice.onExchange = (q, a) => log.add(LogType.voice, q, detail: a);
  // Returns null unless a model is loaded, so the matcher stays the fallback.
  voice.llmGenerate = llm.generate;
  // Record a GPS breadcrumb over the trip so it can be replayed on the map.
  navigation.onTripStart = location.startTrack;
  navigation.onTripComplete = (distanceMeters, duration, steps) {
    location.stopTrack();
    // startTime is derived from the frozen duration; track is copied because
    // location.track is reused by the next trip.
    trips.add(TripRecord(
      startTime: DateTime.now().subtract(duration),
      duration: duration,
      distanceMeters: distanceMeters,
      steps: steps,
      stepLengthMeters: navigation.stepLengthMeters,
      track: List.of(location.track),
    ));
    final mins = duration.inMinutes;
    log.add(
      LogType.navigation,
      'Trip: ${distanceMeters.toStringAsFixed(0)} m, $steps steps',
      detail: '$mins min',
    );
  };

  // Prime offline data.
  await navigation.loadMap();
  final map = navigation.map;
  // Set the map for typed answers now; the mic is only initialised when the
  // Voice tab opens (see VoiceScreen), so launch doesn't prompt for it.
  if (map != null) voice.setMap(map);
  await log.load();
  await trips.load();
  await log.add(LogType.session, 'Session started');

  runApp(AetherNavApp(
    settings: settings,
    perception: perception,
    navigation: navigation,
    voice: voice,
    log: log,
    location: location,
    llm: llm,
    trips: trips,
  ));
}
