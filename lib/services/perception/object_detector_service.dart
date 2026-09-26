import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

/// Offline object detection via ML Kit's bundled base model. Runs on discrete
/// still frames (single-image mode) so there is no YUV stream conversion.
class ObjectDetectorService {
  ObjectDetector? _detector;

  void init() {
    // A single-image detector is stateless across frames and reusable, so keep
    // one for the app's lifetime. PerceptionController.start() calls this on
    // every Camera-tab entry while stop() does not close it — recreating here
    // would leak the previous native detector (dispose() never runs because the
    // controller is a provider.value singleton).
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
