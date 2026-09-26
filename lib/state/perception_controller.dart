import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../data/models/detection.dart';
import '../data/models/hazard_event.dart';
import '../services/hazard/hazard_engine.dart';
import '../services/perception/camera_service.dart';
import '../services/perception/object_detector_service.dart';
import '../services/perception/text_recognizer_service.dart';

enum PerceptionStatus { idle, initializing, running, error }

/// Owns the offline camera perception pipeline: capture a still, run OCR +
/// object detection, classify the frame, derive a hazard, and expose the result
/// to the UI. Alerts (haptics/voice) and logging are delegated via callbacks so
/// this controller stays independent of those subsystems.
class PerceptionController extends ChangeNotifier {
  final CameraService camera = CameraService();
  final ObjectDetectorService _objects = ObjectDetectorService();
  final TextRecognizerService _text = TextRecognizerService();
  final HazardEngine _hazards = HazardEngine();

  PerceptionStatus status = PerceptionStatus.idle;
  String? error;
  List<Detection> detections = const [];
  ui.Size imageSize = ui.Size.zero;
  HazardEvent hazard = HazardEvent.clear();

  Timer? _loop;
  bool _busy = false;
  Set<String> _lastSignKeys = {};

  /// Fired when the hazard level rises into an alert state (warning/danger).
  void Function(HazardEvent hazard)? onHazard;

  /// Fired when a new notable sign/landmark is recognised (for the trip log).
  void Function(Detection detection)? onDetection;

  Future<void> start() async {
    if (status == PerceptionStatus.running ||
        status == PerceptionStatus.initializing) {
      return;
    }
    status = PerceptionStatus.initializing;
    error = null;
    notifyListeners();
    try {
      _objects.init();
      await camera.init();
      status = PerceptionStatus.running;
      notifyListeners();
      _loop =
          Timer.periodic(const Duration(milliseconds: 900), (_) => _tick());
    } catch (e) {
      error = _friendlyError(e);
      status = PerceptionStatus.error;
      notifyListeners();
    }
  }

  void stop() {
    _loop?.cancel();
    _loop = null;
    camera.dispose();
    detections = const [];
    hazard = HazardEvent.clear();
    _lastSignKeys = {};
    if (status != PerceptionStatus.error) status = PerceptionStatus.idle;
    _busy = false;
    notifyListeners();
  }

  /// Whether the torch is currently lit (reflected by the camera settings UI).
  bool get torchOn => camera.torchOn;

  /// Toggles the rear torch and refreshes the UI.
  Future<void> toggleTorch() async {
    await camera.toggleTorch();
    notifyListeners();
  }

  Future<void> _tick() async {
    if (_busy || status != PerceptionStatus.running) return;
    _busy = true;
    String? path;
    try {
      path = await camera.capture();
      if (path == null) return;
      final input = InputImage.fromFilePath(path);
      final recognised = await _text.process(input);
      final objects = await _objects.process(input);
      final size = await _decodeSize(path);
      if (size != null) imageSize = size;

      detections = _classify(recognised, objects, imageSize);

      final hz = _hazards.evaluate(detections);
      final rising = hz.level.index > hazard.level.index;
      hazard = hz;
      if (rising && hz.level.shouldAlert) onHazard?.call(hz);

      _logNewSigns(detections);
      notifyListeners();
    } catch (_) {
      // A single bad frame must never stop the pipeline.
    } finally {
      // Always delete the temp frame — even if the pipeline threw — so captures
      // can't accumulate on disk over a long session.
      if (path != null) _deleteQuietly(path);
      _busy = false;
    }
  }

  List<Detection> _classify(
      RecognizedText? text, List<DetectedObject> objects, ui.Size size) {
    final out = <Detection>[];
    final area = size.width * size.height;

    if (text != null) {
      for (final block in text.blocks) {
        final raw = block.text.trim();
        if (raw.isEmpty) continue;
        final upper = raw.toUpperCase();
        final DetectionKind kind;
        final String label;
        if (upper.contains('EXIT')) {
          kind = DetectionKind.exitSign;
          label = _clean(raw);
        } else if (upper.contains('STAIR')) {
          kind = DetectionKind.stairs;
          label = 'Stairs';
        } else if (upper.contains('DOOR') || upper.contains('GATE')) {
          kind = DetectionKind.door;
          label = _clean(raw);
        } else if (_hasArrow(raw)) {
          kind = DetectionKind.arrow;
          label = 'Direction arrow';
        } else {
          if (raw.replaceAll(RegExp(r'\s'), '').length < 2) continue;
          kind = DetectionKind.text;
          label = _clean(raw);
        }
        final box = block.boundingBox;
        out.add(Detection(
          kind: kind,
          label: label,
          prominence: area > 0 ? (box.width * box.height) / area : 0.0,
          boundingBox: box,
        ));
      }
    }

    for (final obj in objects) {
      final box = obj.boundingBox;
      final ratio = area > 0 ? (box.width * box.height) / area : 0.0;
      if (ratio < 0.18) continue; // ignore small / distant objects
      final labelText =
          obj.labels.isNotEmpty ? obj.labels.first.text.trim() : '';
      out.add(Detection(
        kind: DetectionKind.obstacle,
        label: labelText.isEmpty ? 'Obstacle' : labelText,
        prominence: ratio.clamp(0.0, 1.0).toDouble(),
        boundingBox: box,
      ));
    }
    return out;
  }

  void _logNewSigns(List<Detection> dets) {
    const notable = {
      DetectionKind.exitSign,
      DetectionKind.stairs,
      DetectionKind.door,
      DetectionKind.arrow,
    };
    final keys = <String>{};
    for (final d in dets) {
      if (!notable.contains(d.kind)) continue;
      final key = '${d.kind.name}:${d.label}';
      keys.add(key);
      if (!_lastSignKeys.contains(key)) onDetection?.call(d);
    }
    _lastSignKeys = keys;
  }

  Future<ui.Size?> _decodeSize(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final size = ui.Size(image.width.toDouble(), image.height.toDouble());
      image.dispose();
      return size;
    } catch (_) {
      return null;
    }
  }

  void _deleteQuietly(String path) {
    try {
      File(path).delete();
    } catch (_) {}
  }

  String _clean(String s) {
    final collapsed = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return collapsed.length > 40 ? '${collapsed.substring(0, 40)}…' : collapsed;
  }

  bool _hasArrow(String s) =>
      s.contains('→') ||
      s.contains('←') ||
      s.contains('↑') ||
      s.contains('↓') ||
      s.contains('➜') ||
      s.contains('▶');

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('No camera')) return 'No camera available on this device.';
    return 'Could not start the camera. Check the camera permission.';
  }

  @override
  void dispose() {
    _loop?.cancel();
    camera.dispose();
    _objects.dispose();
    _text.dispose();
    super.dispose();
  }
}
