import 'package:flutter_tts/flutter_tts.dart';

/// Offline text-to-speech for guidance and hazard warnings. Uses the device's
/// on-board TTS engine (no network). All calls are guarded so a missing engine
/// never crashes the app.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool enabled = true;
  bool _ready = false;

  Future<void> init() async {
    try {
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(true);
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  Future<void> speak(String text) async {
    if (!enabled || !_ready || text.trim().isEmpty) return;
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
