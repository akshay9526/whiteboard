// Custom painter for rendering text objects
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'TextObject.dart';

class TextPainterCanvas extends CustomPainter {
  final List<TextObject> textObjects;

  TextPainterCanvas(this.textObjects);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black;

    for (final textObject in textObjects) {
      final textSpan = TextSpan(
        text: textObject.text,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 20,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: ui.TextDirection.ltr,
      );

      textPainter.layout();
      textPainter.paint(canvas, Offset(textObject.x, textObject.y));
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
