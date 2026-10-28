import 'package:flutter/foundation.dart';

import '../data/models/landmark.dart';
import '../services/voice/speech_service.dart';
import '../services/voice/tts_service.dart';
import '../services/voice/voice_interaction.dart';

/// Coordinates speech-to-text, query resolution, and text-to-speech.
class VoiceController extends ChangeNotifier {
  final SpeechService speech;
  final TtsService tts;
  VoiceInteraction? _interaction;

  VoiceController({required this.speech, required this.tts});

  bool ready = false;
  bool listening = false;
  bool _initializingSpeech = false;
  String heardText = '';
  String? answer;
  String? error;

  /// Set by the app so answers use the live compass heading.
  double Function()? headingProvider;

  /// Set by the app to log each question/answer exchange.
  void Function(String question, String answer)? onExchange;

  /// Optional offline-LLM generator. Takes a grounded prompt, returns a spoken
  /// answer or null; on null the deterministic matcher answers.
  Future<String?> Function(String prompt)? llmGenerate;

  /// Set the demo map so typed questions and answers work without touching the
  /// mic. Safe to call at boot (no permission prompt).
  void setMap(DemoMap map) {
    _interaction = VoiceInteraction(map);
    notifyListeners();
  }

  /// Initialise speech recognition — this is what requests the mic on Android.
  /// Idempotent; called when the Voice tab opens, not at app launch.
  Future<void> ensureSpeech() async {
    if (ready || _initializingSpeech) return;
    _initializingSpeech = true;
    ready = await speech.init();
    if (!ready) error = speech.lastError ?? 'Speech recognition is unavailable';
    _initializingSpeech = false;
    notifyListeners();
  }

  Future<void> init(DemoMap map) async {
    setMap(map);
    await ensureSpeech();
  }

  Future<void> toggleListen() async {
    if (!ready) return;
    if (listening) {
      await speech.stop();
      listening = false;
      notifyListeners();
      return;
    }
    heardText = '';
    answer = null;
    error = null;
    listening = true;
    notifyListeners();
    try {
      await speech.listen(onResult: (text, isFinal) {
        heardText = text;
        notifyListeners();
        if (isFinal) _resolve(text);
      });
    } catch (e) {
      listening = false;
      error = speech.lastError ?? 'Could not start listening.';
      notifyListeners();
    }
  }

  /// Text fallback (used when the mic is unavailable).
  Future<void> ask(String text) async {
    heardText = text;
    notifyListeners();
    await _resolve(text);
  }

  /// Read [text] aloud. Honors the spoken-announcements setting (TtsService
  /// no-ops when disabled). Used by tap-to-speak controls elsewhere in the app.
  Future<void> speak(String text) => tts.speak(text);

  Future<void> _resolve(String text) async {
    listening = false;
    final interaction = _interaction;
    if (interaction == null) {
      answer = 'Voice is not ready yet.';
      notifyListeners();
      await tts.speak(answer!);
      return;
    }
    final h = headingProvider?.call() ?? 0;

    // Try the LLM first; on null/empty/timeout the matcher answers.
    String? spoken;
    final gen = llmGenerate;
    if (gen != null && text.trim().isNotEmpty) {
      try {
        spoken = await gen(interaction.buildPrompt(text, h))
            .timeout(const Duration(seconds: 20));
      } catch (_) {
        spoken = null;
      }
    }
    if (spoken == null || spoken.trim().isEmpty) {
      spoken = interaction.answer(text, heading: h).spoken;
    }

    answer = spoken;
    notifyListeners();
    await tts.speak(spoken);
    if (text.trim().isNotEmpty) onExchange?.call(text, spoken);
  }
}
