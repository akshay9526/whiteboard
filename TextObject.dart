// Represents a text object on the canvas
class TextObject {
  double x;
  double y;
  String text;

  TextObject({
    required this.x,
    required this.y,
    this.text = '',
  });
}
