// Represents a single drawing action (line, circle, text, etc.)
import 'dart:ui';

import '../utils/Tools.dart';

class DrawAction {
  final Tool tool;
  final List<Offset> pathPoints;
  final Color color;
  final double strokeWidth;
  final int polygonSides;
  final bool isFilled;
  final String text;

  DrawAction(this.tool, this.pathPoints, this.color, this.strokeWidth,
      [this.polygonSides = 5, this.isFilled = false, this.text = '']);

  Map<String, dynamic> toJson() => {
        'tool': tool.toString().split('.').last,
        'pathPoints': pathPoints.map((p) => {'dx': p.dx, 'dy': p.dy}).toList(),
        'color': color.value,
        'strokeWidth': strokeWidth,
        'polygonSides': polygonSides,
        'isFilled': isFilled,
        'text': text,
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
      );
}
