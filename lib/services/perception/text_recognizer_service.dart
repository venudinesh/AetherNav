import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Offline OCR via ML Kit. Reading sign text ("EXIT", "STAIRS", "Platform 2")
/// is the most reliable perception signal for a controlled demo environment.
class TextRecognizerService {
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  Future<RecognizedText?> process(InputImage image) async {
    try {
      return await _recognizer.processImage(image);
    } catch (_) {
      return null;
    }
  }

  Future<void> dispose() async {
    try {
      await _recognizer.close();
    } catch (_) {}
  }
}
