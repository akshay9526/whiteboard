import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:whiteboards_android/utils/AppConstants.dart';
import 'package:whiteboards_android/utils/Tools.dart';
import 'package:whiteboards_android/utils/utils.dart';

import 'draw/DrawAction.dart';
import 'draw/DrawingPainter.dart';
import 'draw/TextObject.dart';
import 'draw/TextPainterCanvas.dart';

class DrawingPad extends StatefulWidget {
  const DrawingPad({Key? key}) : super(key: key);

  @override
  State<DrawingPad> createState() => _DrawingPadState();
}

class _DrawingPadState extends State<DrawingPad> {
  final GlobalKey _globalKey = GlobalKey();
  final List<DrawAction> _actions = [];
  final List<DrawAction> _redoStack = [];

  Offset? _start;
  Offset? _end;
  Offset? _pointerPosition;
  bool _showPointer = false;

  // Current tool and drawing styles
  Tool _currentTool = Tool.pencil;
  Color _currentColor = Colors.black;
  double _strokeWidth = 2.0;
  int _polygonSides = 5;
  bool _isFilled = false;
  ui.Image? _backgroundImage;
  double _scale = 1.0;

  int? _selectedActionIndex;
  bool _isDragging = false;
  Offset _dragOffset = Offset.zero;

  DateTime now = DateTime.now();

  // Variables for the text tool
  String _currentText = '';
  TextStyle _currentTextStyle = TextStyle(fontSize: 20, color: Colors.black);
  final List<TextObject> textObjects = [];
  final TextEditingController textController = TextEditingController();
  final FocusNode textFocusNode = FocusNode();
  int? currentTextIndex;
  bool isTextFieldVisible = false;

  bool hasPermision = false;

  @override
  void initState() {
    super.initState();
    _requestStoragePermission();
  }

  // Starts a new drawing action
  void _startDraw(Offset offset) {
    setState(() {
      _start = offset;
      _end = offset;
      // Add a new action for pencil or eraser tools
      if (_currentTool == Tool.pencil || _currentTool == Tool.eraser) {
        _actions.add(DrawAction(
          _currentTool,
          [_start!],
          _currentTool == Tool.eraser ? Colors.transparent : _currentColor,
          _strokeWidth,
          _polygonSides,
          _isFilled,
        ));
        _redoStack.clear(); // Clear redo stack on a new action
      }
    });
  }

  // Updates the current drawing action
  void _updateDraw(Offset offset) {
    setState(() {
      _end = offset;
      if ((_currentTool == Tool.pencil || _currentTool == Tool.eraser) &&
          _actions.isNotEmpty) {
        _actions.last.pathPoints.add(offset);
      }
    });
  }

  // Ends the current drawing action
  void _endDraw() {
    if (_start != null &&
        _end != null &&
        _currentTool != Tool.pencil &&
        _currentTool != Tool.eraser) {
      _actions.add(DrawAction(
        _currentTool,
        [_start!, _end!],
        _currentColor,
        _strokeWidth,
        _currentTool == Tool.polygon ? _polygonSides : 0,
        _isFilled,
      ));
      _redoStack.clear();
    }
    _start = null;
    _end = null;
    setState(() {});
  }

  // Selection and movement methods
  void _handleSelection(Offset position) {
    for (int i = _actions.length - 1; i >= 0; i--) {
      if (_isPositionInAction(position, _actions[i])) {
        setState(() {
          _selectedActionIndex = i;
          _isDragging = true;
          _dragOffset = position;
        });
        return;
      }
    }
    setState(() {
      _selectedActionIndex = null;
    });
  }

  // Moves the selected object based on the drag position
  void _moveSelectedObject(Offset position) {
    if (_selectedActionIndex != null && _isDragging) {
      final delta = position - _dragOffset;
      setState(() {
        for (int i = 0;
            i < _actions[_selectedActionIndex!].pathPoints.length;
            i++) {
          _actions[_selectedActionIndex!].pathPoints[i] += delta;
        }
        _dragOffset = position;
      });
    }
  }

  // Checks if a given position is within the bounds of a drawn action
  bool _isPositionInAction(Offset position, DrawAction action) {
    switch (action.tool) {
      case Tool.pencil:
      case Tool.eraser:
        for (int i = 0; i < action.pathPoints.length - 1; i++) {
          if (_isPointNearLine(position, action.pathPoints[i],
              action.pathPoints[i + 1], action.strokeWidth)) {
            return true;
          }
        }
        return false;
      case Tool.line:
        return _isPointNearLine(position, action.pathPoints[0],
            action.pathPoints[1], action.strokeWidth);
      case Tool.rectangle:
        final rect =
            Rect.fromPoints(action.pathPoints[0], action.pathPoints[1]);
        return rect.contains(position) ||
            _isPointNearRectBorder(position, rect, action.strokeWidth);
      case Tool.circle:
        final center = (action.pathPoints[0] + action.pathPoints[1]) / 2;
        final radius =
            (action.pathPoints[0] - action.pathPoints[1]).distance / 2;
        final distance = (position - center).distance;
        return action.isFilled
            ? distance <= radius
            : (distance - radius).abs() <= action.strokeWidth / 2;
      case Tool.polygon:
        return _isPointInPolygon(position, action);
      case Tool.text:
        return _isPointInTextBounds(position, action);
      case Tool.select:
        return false;
    }
  }

  // Checks if a point is near a line segment
  bool _isPointNearLine(
      Offset point, Offset start, Offset end, double strokeWidth) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final length = sqrt(dx * dx + dy * dy);

    if (length < 0.0001) return (point - start).distance <= strokeWidth / 2;

    final t = ((point.dx - start.dx) * dx + (point.dy - start.dy) * dy) /
        (length * length);

    if (t < 0) return (point - start).distance <= strokeWidth / 2;
    if (t > 1) return (point - end).distance <= strokeWidth / 2;

    final projectionX = start.dx + t * dx;
    final projectionY = start.dy + t * dy;
    final distance = (point - Offset(projectionX, projectionY)).distance;

    return distance <= strokeWidth / 2;
  }

  // Checks if a point is near the border of a rectangle
  bool _isPointNearRectBorder(Offset point, Rect rect, double strokeWidth) {
    final threshold = strokeWidth / 2;

    if (point.dx >= rect.left - threshold &&
        point.dx <= rect.left + threshold &&
        point.dy >= rect.top - threshold &&
        point.dy <= rect.bottom + threshold) {
      return true;
    }

    if (point.dx >= rect.right - threshold &&
        point.dx <= rect.right + threshold &&
        point.dy >= rect.top - threshold &&
        point.dy <= rect.bottom + threshold) {
      return true;
    }

    if (point.dy >= rect.top - threshold &&
        point.dy <= rect.top + threshold &&
        point.dx >= rect.left - threshold &&
        point.dx <= rect.right + threshold) {
      return true;
    }

    if (point.dy >= rect.bottom - threshold &&
        point.dy <= rect.bottom + threshold &&
        point.dx >= rect.left - threshold &&
        point.dx <= rect.right + threshold) {
      return true;
    }
    return false;
  }

  // Checks if a point is inside or near a polygon
  bool _isPointInPolygon(Offset point, DrawAction action) {
    final sides = action.polygonSides;
    if (sides < 3) return false;
    final center = (action.pathPoints[0] + action.pathPoints[1]) / 2;
    final radius = (action.pathPoints[0] - action.pathPoints[1]).distance / 2;

    if (action.isFilled) {
      bool inside = false;
      List<Offset> vertices = [];
      for (int i = 0; i < sides; i++) {
        final angle = (2 * pi / sides) * i;
        final x = center.dx + radius * cos(angle);
        final y = center.dy + radius * sin(angle);
        vertices.add(Offset(x, y));
      }

      for (int i = 0, j = vertices.length - 1; i < vertices.length; j = i++) {
        if (((vertices[i].dy > point.dy) != (vertices[j].dy > point.dy)) &&
            (point.dx <
                (vertices[j].dx - vertices[i].dx) *
                        (point.dy - vertices[i].dy) /
                        (vertices[j].dy - vertices[i].dy) +
                    vertices[i].dx)) {
          inside = !inside;
        }
      }
      return inside;
    } else {
      for (int i = 0; i < sides; i++) {
        final angle1 = (2 * pi / sides) * i;
        final angle2 = (2 * pi / sides) * ((i + 1) % sides);
        final x1 = center.dx + radius * cos(angle1);
        final y1 = center.dy + radius * sin(angle1);
        final x2 = center.dx + radius * cos(angle2);
        final y2 = center.dy + radius * sin(angle2);
        if (_isPointNearLine(
            point, Offset(x1, y1), Offset(x2, y2), action.strokeWidth)) {
          return true;
        }
      }
      return false;
    }
  }

  // Checks if a point is within the approximate bounds of a text object
  bool _isPointInTextBounds(Offset point, DrawAction action) {
    if (action.pathPoints.isEmpty) return false;
    final start = action.pathPoints[0];
    final textLength = action.text.length;
    final textWidth = textLength * 10.0;
    final textHeight = 20.0;
    final rect =
        Rect.fromLTWH(start.dx, start.dy - textHeight, textWidth, textHeight);
    return rect.contains(point);
  }

  // Undoes the last drawing action
  void _undo() {
    if (_actions.isNotEmpty) {
      setState(() {
        _redoStack.add(_actions.removeLast());
      });
    }
  }

  // Redoes the last undone action
  void _redo() {
    if (_redoStack.isNotEmpty) {
      setState(() {
        _actions.add(_redoStack.removeLast());
      });
    }
  }

  // Clears all drawing actions and background image
  void _clear() {
    setState(() {
      _actions.clear();
      _redoStack.clear();
      _backgroundImage = null;
      textObjects.clear();
    });
  }

  // Sets the current drawing tool
  void _setTool(Tool tool) {
    setState(() {
      _currentTool = tool;
      if (tool != Tool.text) {
        isTextFieldVisible = false;
      }
    });
  }

  // Sets the current drawing color
  void _setColor(Color color) {
    setState(() => _currentColor = color);
  }

  // Sets the current stroke width
  void _setStroke(double width) {
    setState(() => _strokeWidth = width);
  }

  Future<void> _exportCanvas() async {
    try {
      final boundary = _globalKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      // Generate a filename
      final fileName = "Whiteboard_" + Utils.generateFileName(now) + ".png";

      // Use SaverGallery to save the image file
      final result = await SaverGallery.saveImage(
        Uint8List.fromList(pngBytes),
        quality: 100,
        name: fileName,
        androidRelativePath: "Pictures/appName/whiteboards",
        androidExistNotSave: false,
      );

      if (result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppConstants.Image_Saved)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error exporting image: ${result.errorMessage}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting image: $e')),
      );
    }
  }

  // Imports an image to be used as the background
  Future<void> _importImage() async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      final data = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(data);
      final frame = await codec.getNextFrame();
      setState(() => _backgroundImage = frame.image);
    }
  }

  // Zooms in on the canvas
  void _zoomIn() {
    setState(() {
      _scale = min(_scale + 0.1, 3.0);
    });
  }

  // Zooms out on the canvas
  void _zoomOut() {
    setState(() {
      _scale = max(_scale - 0.1, 0.5);
    });
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(30.0),
        child: AppBar(
          title: Text(
            AppConstants.Whiteboard,
            style: const TextStyle(fontSize: 18),
          ),
          backgroundColor: Colors.grey[200],
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Image.asset(
              'assets/icons/whiteboard.png',
            ),
          ),
        ),
      ),
      body: Row(
        children: [
          Container(
              width: 300,
              color: Colors.grey[100],
              child: SafeArea(child: _buildSidebar(context))),
          Expanded(
            child: GestureDetector(
              onPanStart: (details) {
                if (_currentTool == Tool.select) {
                  _handleSelection(details.localPosition);
                } else {
                  _startDraw(details.localPosition);
                }
              },
              onPanUpdate: (details) {
                if (_currentTool == Tool.select &&
                    _selectedActionIndex != null) {
                  _moveSelectedObject(details.localPosition);
                } else {
                  _updateDraw(details.localPosition);
                }
              },
              onPanEnd: (_) {
                if (_currentTool != Tool.select) {
                  _endDraw();
                } else {
                  _endDrag();
                }
              },
              child: Stack(
                children: [
                  RepaintBoundary(
                    key: _globalKey,
                    child: Stack(
                      children: [
                        CustomPaint(
                          size: Size.infinite,
                          painter: DrawingPainter(
                            _actions,
                            _backgroundImage,
                            _scale,
                            _currentTextStyle,
                          ),
                        ),
                        CustomPaint(
                          size: Size.infinite,
                          painter: TextPainterCanvas(textObjects),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTapUp: (details) {
                        final position = details.localPosition;
                        bool tappedOnText = false;

                        for (int i = 0; i < textObjects.length; i++) {
                          final textObject = textObjects[i];
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

                          final rect = Rect.fromLTWH(
                            textObject.x,
                            textObject.y,
                            textPainter.width,
                            textPainter.height,
                          );

                          if (rect.contains(position)) {
                            setState(() {
                              currentTextIndex = i;
                              textController.text = textObject.text;
                              textFocusNode.requestFocus();
                              isTextFieldVisible = true;
                            });
                            tappedOnText = true;
                            break;
                          }
                        }

                        if (!tappedOnText && _currentTool == Tool.text) {
                          setState(() {
                            textObjects.add(
                                TextObject(x: position.dx, y: position.dy));
                            currentTextIndex = textObjects.length - 1;
                            textController.clear();
                            textFocusNode.requestFocus();
                            isTextFieldVisible = true;
                          });
                        }
                      },
                      child: CustomPaint(
                        size: Size(double.infinity, double.infinity),
                        painter: TextPainterCanvas(textObjects),
                      ),
                    ),
                  ),
                  if (isTextFieldVisible && currentTextIndex != null)
                    Positioned(
                      left: textObjects[currentTextIndex!].x,
                      top: textObjects[currentTextIndex!].y,
                      child: SizedBox(
                        width: 150,
                        height: 30,
                        child: TextField(
                          controller: textController,
                          focusNode: textFocusNode,
                          onChanged: (text) {
                            setState(() {
                              textObjects[currentTextIndex!].text = text;
                            });
                          },
                          onSubmitted: (_) {
                            setState(() {
                              isTextFieldVisible = false;
                            });
                          },
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Ends the drag operation for selection
  void _endDrag() {
    setState(() {
      _isDragging = false;
    });
  }

  @override
  void dispose() {
    textFocusNode.dispose();
    super.dispose();
  }

  // Builds the sidebar UI
  Widget _buildSidebar(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        Text(AppConstants.SelectTool,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 0),
        GridView.count(
          shrinkWrap: true,
          crossAxisCount: 4,
          mainAxisSpacing: 20,
          crossAxisSpacing: 0,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1,
          children: Tool.values.map((tool) {
            final isSelected = _currentTool == tool;
            return GestureDetector(
              onTap: () {
                _setTool(tool);
                if (tool != Tool.text) {
                  isTextFieldVisible = false;
                }
              },
              child: Card(
                color: isSelected ? Colors.blue.shade100 : Colors.white,
                elevation: isSelected ? 6 : 2,
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    color: isSelected ? Colors.blue : Colors.grey.shade300,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_getIconForTool(tool),
                        size: 18,
                        color: isSelected ? Colors.blue : Colors.black87),
                    const SizedBox(height: 8),
                    Text(tool.toString().split('.').last,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const Divider(),
        Text(AppConstants.PickColor,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        // Wrap for color selection
        Wrap(
          spacing: 10,
          children: Colors.primaries
              .map((color) => GestureDetector(
                    onTap: () => _setColor(color),
                    child: Container(
                      width: 25,
                      height: 25,
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          width: _currentColor == color ? 3 : 1,
                          color: Colors.grey[600]!,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const Divider(),
        Text(AppConstants.Stroke_Width,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        // Slider for stroke width
        Slider(
          activeColor: Colors.blueAccent,
          value: _strokeWidth,
          min: 1,
          max: 8,
          divisions: 7,
          label: _strokeWidth.toString(),
          onChanged: _setStroke,
        ),

        if (_currentTool == Tool.polygon) ...[
          const Divider(),
          Text(AppConstants.Polygon_Sides,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          Slider(
            activeColor: Colors.blueAccent,
            min: 3,
            max: 10,
            divisions: 7,
            value: _polygonSides.toDouble(),
            label: _polygonSides.toString(),
            onChanged: (val) => setState(() => _polygonSides = val.toInt()),
          ),
        ],

        if (_currentTool == Tool.text) ...[],
        const Divider(),
        Text(AppConstants.Shape_Options,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        // Switch for filling shapes
        SwitchListTile(
          activeColor: Colors.blueAccent,
          title: Text(
            AppConstants.Fill_Shapes,
            style: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
          ),
          value: _isFilled,
          onChanged: (val) => setState(() => _isFilled = val),
        ),
        const Divider(),
        Text(AppConstants.Canvas_Controls,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        // List tiles for canvas controls
        ListTile(
            leading: const Icon(Icons.undo),
            title: Text(AppConstants.Undo,
                style: const TextStyle(
                    fontWeight: FontWeight.normal, fontSize: 14)),
            onTap: _undo),
        ListTile(
            leading: const Icon(Icons.redo),
            title: Text(AppConstants.Redo,
                style: const TextStyle(
                    fontWeight: FontWeight.normal, fontSize: 12)),
            onTap: _redo),
        ListTile(
            leading: const Icon(Icons.clear_all),
            title: Text(AppConstants.Clear_All,
                style: const TextStyle(
                    fontWeight: FontWeight.normal, fontSize: 12)),
            onTap: _clear),
        const Divider(),
        // List tiles for file operations
        ListTile(
            leading: const Icon(Icons.image),
            title: Text(AppConstants.Import_Image,
                style: const TextStyle(
                    fontWeight: FontWeight.normal, fontSize: 12)),
            onTap: _importImage),
        ListTile(
          leading: const Icon(Icons.download),
          title: Text(AppConstants.Export_Image,
              style:
                  const TextStyle(fontWeight: FontWeight.normal, fontSize: 12)),
          onTap: _exportCanvas,
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.upload_file),
          title: Text(AppConstants.Import_JSON,
              style:
                  const TextStyle(fontWeight: FontWeight.normal, fontSize: 12)),
          onTap: _importJson,
        ),
        ListTile(
          leading: const Icon(Icons.download),
          title: Text(AppConstants.Export_JSON,
              style:
                  const TextStyle(fontWeight: FontWeight.normal, fontSize: 12)),
          onTap: _exportJson,
        ),
        const Divider(),
        // List tiles for zoom controls
        Card(
          child: ListTile(
            leading: const Icon(Icons.zoom_in),
            title: Text(AppConstants.Zoom_In,
                style: const TextStyle(
                    fontWeight: FontWeight.normal, fontSize: 12)),
            onTap: _zoomIn,
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.zoom_out),
            title: Text(AppConstants.Zoom_Out,
                style: const TextStyle(
                    fontWeight: FontWeight.normal, fontSize: 12)),
            onTap: _zoomOut,
          ),
        )
      ],
    );
  }

  // Gets the appropriate icon for a given tool
  IconData _getIconForTool(Tool tool) {
    switch (tool) {
      case Tool.pencil:
        return Icons.edit;
      case Tool.line:
        return Icons.linear_scale;
      case Tool.rectangle:
        return Icons.crop_square;
      case Tool.circle:
        return Icons.circle_outlined;
      case Tool.polygon:
        return Icons.change_history;
      case Tool.eraser:
        return Icons.cleaning_services;
      case Tool.text:
        return Icons.format_color_text_outlined;
      case Tool.select:
        return Icons.pan_tool;
    }
  }

  // Imports drawing data from a JSON file
  Future<void> _importJson() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String jsonString = await file.readAsString();
        _deserializeFromJson(jsonString);
      } else {}
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error importing JSON: $e')),
      );
    }
  }

  String _serializeToJson() {
    List<Map<String, dynamic>> jsonList = _actions.map((action) {
      return {
        'tool': action.tool.toString().split('.').last,
        'pathPoints': action.pathPoints
            .map((point) => {'dx': point.dx, 'dy': point.dy})
            .toList(),
        'color': action.color.value,
        'strokeWidth': action.strokeWidth,
        'polygonSides': action.polygonSides,
        'isFilled': action.isFilled,
        'text': action.text,
      };
    }).toList();
    return jsonEncode(jsonList);
  }

  void _deserializeFromJson(String jsonString) {
    try {
      List<dynamic> jsonList = jsonDecode(jsonString);
      List<DrawAction> actions = jsonList.map((json) {
        return DrawAction(
          Tool.values.firstWhere(
              (tool) => tool.toString().split('.').last == json['tool']),
          (json['pathPoints'] as List)
              .map((point) => Offset(point['dx'], point['dy']))
              .toList(),
          Color(json['color']),
          json['strokeWidth'].toDouble(),
          json['polygonSides'] ?? 5,
          json['isFilled'] ?? false,
          json['text'] ?? '',
        );
      }).toList();

      setState(() {
        _actions.clear();
        _actions.addAll(actions);
        _selectedActionIndex = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error parsing JSON: $e')),
      );
    }
  }

  Future<void> _exportJson() async {
    try {
      final jsonString = _serializeToJson();

      final directory = await Directory('/storage/emulated/0/Download');
      if (directory.exists() == false) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not access temporary directory.')),
        );
        return;
      }

      final tempPath = directory.path;

      final fileName =
          'drawing_${"Whiteboard_" + Utils.generateFileName(DateTime.now())}.json';

      final tempFile = File('$tempPath/$fileName');
      await tempFile.writeAsString(jsonString);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppConstants.Image_Saved),
          duration: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting JSON: $e')),
      );
      print("Error exporting JSON: $e");
    }
  }

  Future<void> _requestStoragePermission() async {
    var status = await Utils.checkAndRequestPermissions(skipIfExists: true);
    if (status == false) {
      openAppSettings();
    }
  }
}
