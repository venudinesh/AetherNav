import 'package:permission_handler/permission_handler.dart';

/// Thin wrapper around the runtime permissions AetherNav Edge needs.
/// Camera is required; microphone is optional (voice degrades gracefully).
class AppPermissions {
  static Future<bool> ensureCamera() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  static Future<bool> ensureMicrophone() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Requests the Android 13+ notification permission so the model-download
  /// progress notification can show. Best-effort — the download proceeds either
  /// way (the notification is a nicety, not a requirement).
  static Future<bool> ensureNotifications() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  static Future<bool> cameraGranted() async =>
      (await Permission.camera.status).isGranted;

  static Future<bool> micGranted() async =>
      (await Permission.microphone.status).isGranted;

  static Future<void> openSettings() => openAppSettings();
}
