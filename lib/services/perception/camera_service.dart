import 'package:camera/camera.dart';

/// Owns the camera lifecycle. Keeps a live preview running and grabs discrete
/// still frames on demand for the perception pipeline (robust across devices,
/// no image-stream YUV handling).
class CameraService {
  CameraController? controller;

  /// Whether the torch (rear flash LED) is currently lit. Kept here so the UI
  /// can reflect it without reaching into the camera plugin's value.
  bool torchOn = false;

  bool get isReady => controller?.value.isInitialized ?? false;

  Future<void> init() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw StateError('No camera available on this device');
    }
    final back = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    final c = CameraController(
      back,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await c.initialize();
    controller = c;
    torchOn = false; // fresh controller starts with the torch off
  }

  /// Turns the torch (rear flash LED) on or off. No-op if the camera isn't
  /// ready; swallows the error on devices without a flash so the UI never
  /// crashes on a missing LED.
  Future<void> setTorch(bool on) async {
    final c = controller;
    if (c == null || !c.value.isInitialized) return;
    try {
      await c.setFlashMode(on ? FlashMode.torch : FlashMode.off);
      torchOn = on;
    } catch (_) {
      torchOn = false;
    }
  }

  Future<void> toggleTorch() => setTorch(!torchOn);

  /// Captures a single JPEG to a temp file and returns its path, or null if a
  /// capture is already in flight or the camera is not ready.
  Future<String?> capture() async {
    final c = controller;
    if (c == null || !c.value.isInitialized || c.value.isTakingPicture) {
      return null;
    }
    try {
      final file = await c.takePicture();
      return file.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> dispose() async {
    try {
      await controller?.dispose();
    } catch (_) {}
    controller = null;
    torchOn = false;
  }
}
