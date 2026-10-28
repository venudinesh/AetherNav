import 'package:flutter/material.dart';

/// what the perception pipeline can detect
enum DetectionKind { sign, exitSign, arrow, stairs, door, obstacle, text, unknown }

extension DetectionKindLabel on DetectionKind {
  String get display => switch (this) {
        DetectionKind.sign => 'Sign',
        DetectionKind.exitSign => 'Exit',
        DetectionKind.arrow => 'Arrow',
        DetectionKind.stairs => 'Stairs',
        DetectionKind.door => 'Door',
        DetectionKind.obstacle => 'Obstacle',
        DetectionKind.text => 'Text',
        DetectionKind.unknown => 'Object',
      };
}

/// one perception result for a frame
class Detection {
  final DetectionKind kind;
  final String label; // human-facing, e.g. "Exit 4"
  // frame area fraction (0..1), a nearness cue not model confidence;
  // feeds the obstacle danger threshold
  final double prominence;
  final Rect boundingBox; // source-image pixel coords

  const Detection({
    required this.kind,
    required this.label,
    required this.prominence,
    required this.boundingBox,
  });
}
