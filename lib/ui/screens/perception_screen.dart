import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/permissions.dart';
import '../../data/models/detection.dart';
import '../../state/perception_controller.dart';
import '../widgets/app_states.dart';
import '../widgets/detection_overlay.dart';
import '../widgets/hazard_banner.dart';

/// Live offline camera perception: OCR + object detection on discrete frames,
/// with a hazard banner, a bounding-box overlay, and an honest list of what the
/// device currently sees.
class PerceptionScreen extends StatefulWidget {
  const PerceptionScreen({super.key});
  @override
  State<PerceptionScreen> createState() => _PerceptionScreenState();
}

class _PerceptionScreenState extends State<PerceptionScreen> {
  late final PerceptionController _perception = context.read<PerceptionController>();
  bool _denied = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    setState(() => _denied = false);
    final granted = await AppPermissions.ensureCamera();
    if (!mounted) return;
    if (granted) {
      _perception.start();
    } else {
      setState(() => _denied = true);
    }
  }

  @override
  void dispose() {
    _perception.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final perception = context.watch<PerceptionController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera perception'),
        actions: [
          if (perception.status == PerceptionStatus.running) ...[
            IconButton(
              tooltip: perception.torchOn ? 'Torch off' : 'Torch on',
              icon: Icon(
                  perception.torchOn ? Icons.flash_on : Icons.flash_off),
              onPressed: _perception.toggleTorch,
            ),
            IconButton(
              tooltip: 'Stop',
              icon: const Icon(Icons.stop_circle_outlined),
              onPressed: _perception.stop,
            ),
          ] else
            IconButton(
              tooltip: 'Start',
              icon: const Icon(Icons.play_circle_outline),
              onPressed: _boot,
            ),
        ],
      ),
      body: _buildBody(context, perception),
    );
  }

  Widget _buildBody(BuildContext context, PerceptionController perception) {
    if (_denied) {
      return _PermissionDenied(onRetry: _boot);
    }
    switch (perception.status) {
      case PerceptionStatus.idle:
        return EmptyState(
          icon: Icons.photo_camera_outlined,
          title: 'Camera stopped',
          message: 'Start the camera to read signs and detect obstacles.',
          action: FilledButton.icon(
            onPressed: _boot,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start camera'),
          ),
        );
      case PerceptionStatus.initializing:
        return const LoadingState(message: 'Starting camera…');
      case PerceptionStatus.error:
        return ErrorState(
          title: 'Camera unavailable',
          message: perception.error ?? 'The camera could not be started.',
          onRetry: _boot,
        );
      case PerceptionStatus.running:
        return _CameraView(perception: perception);
    }
  }

}

class _PermissionDenied extends StatelessWidget {
  final VoidCallback onRetry;
  const _PermissionDenied({required this.onRetry});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.no_photography_outlined, size: 40, color: scheme.error),
          const SizedBox(height: 16),
          Text('Camera permission needed',
              style: t.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(
            'AetherNav Edge uses the camera on-device to read signs and detect '
            'obstacles. Grant the camera permission to continue.',
            textAlign: TextAlign.center,
            style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: [
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
            OutlinedButton.icon(
              onPressed: AppPermissions.openSettings,
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Open settings'),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _CameraView extends StatelessWidget {
  final PerceptionController perception;
  const _CameraView({required this.perception});

  @override
  Widget build(BuildContext context) {
    final c = perception.camera.controller;
    if (c == null || !c.value.isInitialized) {
      return const LoadingState(message: 'Starting camera…');
    }
    return Stack(fit: StackFit.expand, children: [
      _coveredPreview(c),
      DetectionOverlay(
        detections: perception.detections,
        imageSize: perception.imageSize,
      ),
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: HazardBanner(hazard: perception.hazard),
          ),
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: _DetectionPanel(detections: perception.detections),
      ),
    ]);
  }

  Widget _coveredPreview(CameraController c) {
    final preview = c.value.previewSize;
    final w = preview?.height ?? 9;
    final h = preview?.width ?? 16;
    return ClipRect(
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(width: w, height: h, child: CameraPreview(c)),
        ),
      ),
    );
  }
}

class _DetectionPanel extends StatelessWidget {
  final List<Detection> detections;
  const _DetectionPanel({required this.detections});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.visibility_outlined,
                  size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text('Detected now', style: t.titleSmall),
              const Spacer(),
              Text('${detections.length}',
                  style: t.titleSmall?.copyWith(color: scheme.onSurfaceVariant)),
            ]),
            const SizedBox(height: 10),
            if (detections.isEmpty)
              Text('Point the camera at signs or obstacles.',
                  style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant))
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 132),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [for (final d in detections) _chip(context, d)],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, Detection d) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final name = d.label == d.kind.display ? d.label : '${d.kind.display}: ${d.label}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(name, style: t.labelMedium),
    );
  }
}
