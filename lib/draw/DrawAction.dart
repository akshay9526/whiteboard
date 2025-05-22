import 'dart:ui';

import '../utils/Tools.dart';

class DrawAction {
  final Tool tool;
  late final List<Offset> pathPoints;
  Color color;
  final double strokeWidth;
  final int polygonSides;
  final bool isFilled;
  final String text;
  double rotation;

  DrawAction(this.tool, this.pathPoints, this.color, this.strokeWidth,
      [this.polygonSides = 5,
      this.isFilled = false,
      this.text = '',
      this.rotation = 0.0]);

  Map<String, dynamic> toJson() => {
        'tool': tool.toString().split('.').last,
        'pathPoints': pathPoints.map((p) => {'dx': p.dx, 'dy': p.dy}).toList(),
        'color': color.value,
        'strokeWidth': strokeWidth,
        'polygonSides': polygonSides,
        'isFilled': isFilled,
        'text': text,
        'rotation': rotation,
      };

  factory DrawAction.fromJson(Map<String, dynamic> json) => DrawAction(
        Tool.values.firstWhere(
            (tool) => tool.toString().split('.').last == json['tool']),
        (json['pathPoints'] as List)
            .map((p) => Offset(p['dx'], p['dy']))
            .toList(),
        Color(json['color']),
        json['strokeWidth'].toDouble(),
        json['polygonSides'] ?? 5,
        json['isFilled'] ?? false,
        json['text'] ?? '',
        (json['rotation'] ?? 0.0).toDouble(),
      );
}
