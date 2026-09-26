import 'package:flutter/foundation.dart';

import '../data/models/landmark.dart';
import '../services/voice/speech_service.dart';
import '../services/voice/tts_service.dart';
import '../services/voice/voice_interaction.dart';

/// Coordinates speech-to-text, the on-device query resolver, and text-to-speech.
class VoiceController extends ChangeNotifier {
  final SpeechService speech;
  final TtsService tts;
  VoiceInteraction? _interaction;

  VoiceController({required this.speech, required this.tts});

  bool ready = false;
  bool listening = false;
  String heardText = '';
  String? answer;
  String? error;

  /// Set by the app so answers use the live compass heading.
  double Function()? headingProvider;

  /// Set by the app to log each question/answer exchange.
  void Function(String question, String answer)? onExchange;

  /// Optional grounded offline-LLM front-end, set by the app. Given a fully
  /// built grounded prompt it returns a spoken answer, or null on any failure /
  /// timeout / when no model is loaded — the deterministic matcher then answers.
  Future<String?> Function(String prompt)? llmGenerate;

  Future<void> init(DemoMap map) async {
    _interaction = VoiceInteraction(map);
    ready = await speech.init();
    if (!ready) error = speech.lastError ?? 'Speech recognition is unavailable';
    notifyListeners();
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

    // Grounded LLM first — it only rephrases the facts buildPrompt injects. On
    // null / timeout / empty / no-model, the deterministic matcher answers, so
    // the assistant never depends on inference and never hangs the mic.
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
