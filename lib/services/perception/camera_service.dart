import 'package:camera/camera.dart';

/// Owns the camera; grabs still JPEG frames for the perception pipeline.
class CameraService {
  CameraController? controller;

  // mirrored so the UI doesn't have to poke the plugin's value
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
    torchOn = false;
  }

  // no-op if not ready; errors on flashless devices are swallowed
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

  // returns the jpeg path, or null if busy / not ready
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
