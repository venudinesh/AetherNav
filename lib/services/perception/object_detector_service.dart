import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

/// ml kit object detection (bundled base model) on still frames.
class ObjectDetectorService {
  ObjectDetector? _detector;

  void init() {
    // don't recreate: this service is a singleton, stop() never closes the
    // detector, so recreating would leak the previous native one
    if (_detector != null) return;
    final options = ObjectDetectorOptions(
      mode: DetectionMode.single,
      classifyObjects: true,
      multipleObjects: true,
    );
    _detector = ObjectDetector(options: options);
  }

  Future<List<DetectedObject>> process(InputImage image) async {
    final detector = _detector;
    if (detector == null) return const [];
    try {
      return await detector.processImage(image);
    } catch (_) {
      return const [];
    }
  }

  Future<void> dispose() async {
    await _detector?.close();
    _detector = null;
  }
}
