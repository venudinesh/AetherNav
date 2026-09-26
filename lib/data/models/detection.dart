import 'package:flutter/material.dart';

/// The kinds of things the offline perception pipeline can surface.
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

/// A single perception result for one frame.
class Detection {
  final DetectionKind kind;
  final String label; // human-facing, e.g. "Exit 4", "Stairs ahead"
  // Fraction of the frame the box covers (0..1) — a nearness cue, not a model
  // confidence. Drives the obstacle danger threshold; 0 where nearness doesn't apply.
  final double prominence;
  final Rect boundingBox; // in source-image pixel coordinates

  const Detection({
    required this.kind,
    required this.label,
    required this.prominence,
    required this.boundingBox,
  });
}
