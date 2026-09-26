import 'package:speech_to_text/speech_to_text.dart';

/// Offline speech recognition wrapper. Prefers the on-device recognizer so it
/// works without a network. Exposes a simple listen/stop API.
class SpeechService {
  final SpeechToText _stt = SpeechToText();
  bool _available = false;
  String? lastError;

  bool get available => _available;
  bool get isListening => _stt.isListening;

  Future<bool> init() async {
    try {
      _available = await _stt.initialize(
        onError: (e) => lastError = e.errorMsg,
        onStatus: (_) {},
      );
    } catch (e) {
      lastError = e.toString();
      _available = false;
    }
    return _available;
  }

  Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
  }) async {
    if (!_available) return;
    try {
      await _stt.listen(
        onResult: (r) => onResult(r.recognizedWords, r.finalResult),
        listenOptions: SpeechListenOptions(
          partialResults: true,
          listenMode: ListenMode.confirmation,
          cancelOnError: true,
        ),
      );
    } catch (e) {
      lastError = e.toString();
      rethrow; // let the controller reset its listening state
    }
  }

  Future<void> stop() async {
    try {
      await _stt.stop();
    } catch (_) {}
  }
}
