import 'package:flutter/material.dart';
import 'package:whiteboards_android/utils/AppConstants.dart';

import 'Draw.dart';

void main() => runApp(const DrawingPadApp());

class DrawingPadApp extends StatelessWidget {
  const DrawingPadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.Whiteboard,
      home: DrawingPad(),
      debugShowCheckedModeBanner: false,
    );
  }
}
