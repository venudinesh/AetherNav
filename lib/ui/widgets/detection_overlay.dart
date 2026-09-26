import 'package:flutter/material.dart';

import '../../data/models/detection.dart';

/// Draws detection bounding boxes over the camera preview. Boxes arrive in
/// source-image pixel coordinates and are mapped onto the preview with a cover
/// fit (the preview fills its box the same way), so they line up regardless of
/// the preview's aspect ratio.
class DetectionOverlay extends StatelessWidget {
  final List<Detection> detections;
  final Size imageSize;
  const DetectionOverlay({
    super.key,
    required this.detections,
    required this.imageSize,
  });

  @override
  Widget build(BuildContext context) {
    if (detections.isEmpty || imageSize == Size.zero) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: CustomPaint(
        painter: _BoxPainter(detections, imageSize, Theme.of(context)),
        size: Size.infinite,
      ),
    );
  }
}

class _BoxPainter extends CustomPainter {
  final List<Detection> detections;
  final Size imageSize;
  final ThemeData theme;
  _BoxPainter(this.detections, this.imageSize, this.theme);

  @override
  void paint(Canvas canvas, Size size) {
    // Cover fit: scale so the image fills the widget, crop the overflow.
    final scale = (size.width / imageSize.width)
        .clamp(size.height / imageSize.height, double.infinity);
    final dx = (size.width - imageSize.width * scale) / 2;
    final dy = (size.height - imageSize.height * scale) / 2;

    for (final d in detections) {
      final color = _colorFor(d.kind);
      final rect = Rect.fromLTRB(
        d.boundingBox.left * scale + dx,
        d.boundingBox.top * scale + dy,
        d.boundingBox.right * scale + dx,
        d.boundingBox.bottom * scale + dy,
      );
      final rr = RRect.fromRectAndRadius(rect, const Radius.circular(8));
      canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = color,
      );
      _label(canvas, rect, d.label, color);
    }
  }

  void _label(Canvas canvas, Rect rect, String text, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 220);
    final pad = const EdgeInsets.symmetric(horizontal: 6, vertical: 3);
    final top = (rect.top - tp.height - pad.vertical).clamp(0.0, double.infinity);
    final bg = Rect.fromLTWH(
        rect.left, top, tp.width + pad.horizontal, tp.height + pad.vertical);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bg, const Radius.circular(6)),
      Paint()..color = color,
    );
    tp.paint(canvas, Offset(rect.left + pad.left, top + pad.top));
  }

  Color _colorFor(DetectionKind kind) {
    final scheme = theme.colorScheme;
    switch (kind) {
      case DetectionKind.obstacle:
        return const Color(0xFFDC2626); // red-600
      case DetectionKind.stairs:
        return const Color(0xFFD97706); // amber-600
      case DetectionKind.exitSign:
      case DetectionKind.arrow:
        return const Color(0xFF16A34A); // green-600
      case DetectionKind.door:
        return const Color(0xFF2563EB); // blue-600
      default:
        return scheme.primary;
    }
  }

  @override
  bool shouldRepaint(_BoxPainter old) =>
      old.detections != detections ||
      old.imageSize != imageSize ||
      old.theme != theme;
}
