import 'package:permission_handler/permission_handler.dart';

/// Runtime permission requests. Camera is required; mic is optional (voice
/// degrades to typed input).
class AppPermissions {
  static Future<bool> ensureCamera() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  static Future<bool> ensureMicrophone() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Android 13+ notification permission, for the model-download progress
  /// notification. Best-effort — the download runs either way.
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
