// Custom painter for rendering drawing actions (shapes, lines, etc.)
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../utils/Tools.dart';
import 'DrawAction.dart';

class DrawingPainter extends CustomPainter {
  final List<DrawAction> actions;
  final ui.Image? backgroundImage;
  final double scale;
  final TextStyle currentTextStyle;

  DrawingPainter(
      this.actions, this.backgroundImage, this.scale, this.currentTextStyle);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(scale);

    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final paintLayer = Paint();
    canvas.saveLayer(Offset.zero & size, paintLayer);

    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    if (backgroundImage != null) {
      paintImage(
        canvas: canvas,
        image: backgroundImage!,
        rect: Offset.zero & size,
        fit: BoxFit.cover,
      );
    }

    for (var action in actions) {
      final isEraser = action.tool == Tool.eraser;
      final paint = Paint()
        ..color = isEraser ? Colors.transparent : action.color
        ..strokeWidth = action.strokeWidth
        ..style = action.isFilled ? PaintingStyle.fill : PaintingStyle.stroke
        ..blendMode = isEraser ? BlendMode.clear : BlendMode.srcOver;

      switch (action.tool) {
        case Tool.pencil:
          final path = Path()
            ..moveTo(action.pathPoints[0].dx, action.pathPoints[0].dy);
          for (int i = 1; i < action.pathPoints.length - 1; i++) {
            final midPoint =
                (action.pathPoints[i] + action.pathPoints[i + 1]) / 2;
            path.quadraticBezierTo(action.pathPoints[i].dx,
                action.pathPoints[i].dy, midPoint.dx, midPoint.dy);
          }
          canvas.drawPath(path, paint);
          break;
        case Tool.eraser:
          for (int i = 0; i < action.pathPoints.length - 1; i++) {
            canvas.drawLine(
                action.pathPoints[i], action.pathPoints[i + 1], paint);
          }
          break;
        case Tool.line:
          canvas.drawLine(action.pathPoints[0], action.pathPoints[1], paint);
          break;
        case Tool.rectangle:
          canvas.drawRect(
              Rect.fromPoints(action.pathPoints[0], action.pathPoints[1]),
              paint);
          break;
        case Tool.circle:
          final center = (action.pathPoints[0] + action.pathPoints[1]) / 2;
          final radius =
              (action.pathPoints[0] - action.pathPoints[1]).distance / 2;
          canvas.drawCircle(center, radius, paint);
          break;
        case Tool.polygon:
          _drawPolygon(canvas, action, paint);
          break;
        case Tool.text:
          break;
        case Tool.select:
          break;
      }
    }

    canvas.restore();
  }

  // Draws a polygon
  void _drawPolygon(Canvas canvas, DrawAction action, Paint paint) {
    final sides = action.polygonSides;
    if (sides < 3) return;
    final center = (action.pathPoints[0] + action.pathPoints[1]) / 2;
    final radius = (action.pathPoints[0] - action.pathPoints[1]).distance / 2;
    final path = Path();
    for (int i = 0; i < sides; i++) {
      final angle = (2 * pi / sides) * i - pi / 2;
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);
      final point = Offset(x, y);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) {
    return oldDelegate.actions != actions ||
        oldDelegate.scale != scale ||
        oldDelegate.backgroundImage != backgroundImage;
  }
}
