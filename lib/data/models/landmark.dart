import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// A known point in the controlled demo area. Bearings are degrees clockwise
/// from the area's reference "north"; distances are approximate metres.
class Landmark {
  final String id;
  final String name; // "Exit 4"
  final String kind; // exit, stairs, door, room, hazard
  final double bearing;
  final double distanceMeters;
  final String? note;

  const Landmark({
    required this.id,
    required this.name,
    required this.kind,
    required this.bearing,
    required this.distanceMeters,
    this.note,
  });

  factory Landmark.fromJson(Map<String, dynamic> j) => Landmark(
        id: j['id'] as String,
        name: j['name'] as String,
        kind: j['kind'] as String,
        bearing: (j['bearing'] as num).toDouble(),
        distanceMeters: (j['distanceMeters'] as num).toDouble(),
        note: j['note'] as String?,
      );
}

/// The loaded demo map: an area name plus its landmarks.
class DemoMap {
  final String area;
  final List<Landmark> landmarks;
  const DemoMap({required this.area, required this.landmarks});

  static Future<DemoMap> load() async {
    final raw = await rootBundle.loadString('assets/landmarks/demo_map.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final list = (json['landmarks'] as List)
        .map((e) => Landmark.fromJson(e as Map<String, dynamic>))
        .toList();
    return DemoMap(area: json['area'] as String? ?? 'Demo area', landmarks: list);
  }
}
