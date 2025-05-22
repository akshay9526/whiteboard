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
  final double selectedRotation;
  final int? selectedIndex;

  DrawingPainter(this.actions, this.backgroundImage, this.scale,
      this.currentTextStyle, this.selectedRotation, this.selectedIndex);

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
    } else {
      canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    }

    for (int i = 0; i < actions.length; i++) {
      final action = actions[i];
      final isSelected = (i == selectedIndex);
      canvas.save();

      // Determine shape center
      Offset shapeCenter;
      if (action.tool == Tool.text && action.pathPoints.isNotEmpty) {
        shapeCenter = action.pathPoints[0];
      } else if (action.pathPoints.length >= 2) {
        shapeCenter = (action.pathPoints[0] + action.pathPoints[1]) / 2;
      } else if (action.pathPoints.isNotEmpty) {
        // Only one point, use it as center
        shapeCenter = action.pathPoints[0];
      } else {
        shapeCenter = Offset.zero;
      }

      // Apply rotation only if selected
      if (isSelected) {
        canvas.translate(shapeCenter.dx, shapeCenter.dy);
        canvas.rotate(action.rotation);
        canvas.translate(-shapeCenter.dx, -shapeCenter.dy);
      }

      if (isSelected) {
        final rect = _calculateShapeRect(action);
        // Draw handles at corners
        final handles = [
          rect.topLeft,
          rect.topRight,
          rect.bottomLeft,
          rect.bottomRight,
        ];
        for (final handle in handles) {
          canvas.drawCircle(handle, 8, Paint()..color = Colors.blue);
        }
      }

      // Set paint
      final isEraser = action.tool == Tool.eraser;
      final paint = Paint()
        ..color = isEraser ? Colors.transparent : action.color
        ..strokeWidth = action.strokeWidth
        ..style = action.isFilled ? PaintingStyle.fill : PaintingStyle.stroke
        ..blendMode = isEraser ? BlendMode.clear : BlendMode.srcOver;

      switch (action.tool) {
        case Tool.pencil:
          for (int i = 0; i < action.pathPoints.length - 1; i++) {
            canvas.drawLine(
                action.pathPoints[i], action.pathPoints[i + 1], paint);
          }
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
          // Text is handled separately
          break;
        default:
          break;
      }

      // canvas.restore();
    }

    canvas.restore();
  }

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
        oldDelegate.backgroundImage != backgroundImage ||
        oldDelegate.scale != scale ||
        oldDelegate.selectedRotation != selectedRotation ||
        oldDelegate.selectedIndex != selectedIndex;
  }

  Rect _calculateShapeRect(DrawAction action) {
    final points = action.pathPoints;
    final minX = points.map((p) => p.dx).reduce(min);
    final maxX = points.map((p) => p.dx).reduce(max);
    final minY = points.map((p) => p.dy).reduce(min);
    final maxY = points.map((p) => p.dy).reduce(max);
    return Rect.fromPoints(Offset(minX, minY), Offset(maxX, maxY));
  }
}
