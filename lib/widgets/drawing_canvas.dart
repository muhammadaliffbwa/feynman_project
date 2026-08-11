import 'package:flutter/material.dart';
import '../models/note.dart';

/// A freehand drawing surface. Holds the finished [strokes] plus whatever
/// stroke is currently mid-draw, and repaints as the finger moves.
class DrawingCanvas extends StatefulWidget {
  final List<DrawStroke> strokes;
  final ValueChanged<List<DrawStroke>> onStrokesChanged;
  final Color color;
  final double strokeWidth;
  final StrokeType tool;

  const DrawingCanvas({
    super.key,
    required this.strokes,
    required this.onStrokesChanged,
    required this.color,
    required this.strokeWidth,
    required this.tool,
  });

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  DrawStroke? _current;

  void _startStroke(Offset point) {
    setState(() {
      _current = DrawStroke(
        points: [point],
        color: widget.color,
        width: widget.strokeWidth,
        type: widget.tool,
      );
    });
  }

  void _extendStroke(Offset point) {
    if (_current == null) return;
    setState(() => _current!.points.add(point));
  }

  void _endStroke() {
    if (_current == null) return;
    final updated = List<DrawStroke>.from(widget.strokes)..add(_current!);
    widget.onStrokesChanged(updated);
    setState(() => _current = null);
  }

  @override
  Widget build(BuildContext context) {
    final allStrokes = [
      ...widget.strokes,
      if (_current != null) _current!,
    ];

    return GestureDetector(
      onPanStart: (details) => _startStroke(details.localPosition),
      onPanUpdate: (details) => _extendStroke(details.localPosition),
      onPanEnd: (_) => _endStroke(),
      child: Container(
        color: Colors.white,
        width: double.infinity,
        height: double.infinity,
        child: CustomPaint(
          painter: _StrokesPainter(allStrokes),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _StrokesPainter extends CustomPainter {
  final List<DrawStroke> strokes;
  _StrokesPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    // Everything is painted into one offscreen layer first. That's what
    // lets the eraser (BlendMode.clear) punch a genuinely transparent
    // hole through strokes drawn earlier, instead of just drawing a
    // white line on top of them (which would look wrong over color).
    canvas.saveLayer(Offset.zero & size, Paint());

    for (final stroke in strokes) {
      if (stroke.points.length < 2) continue;

      final paint = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke.width;

      switch (stroke.type) {
        case StrokeType.pen:
          paint.color = stroke.color;
        case StrokeType.highlighter:
          paint.color = stroke.color.withValues(alpha: 0.35);
          paint.strokeCap = StrokeCap.square;
        case StrokeType.eraser:
          paint.blendMode = BlendMode.clear;
      }

      final path = Path()
        ..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (final point in stroke.points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }

    canvas.restore();
  }

  // Repaints on every stroke change — fine at note-taking scale. If a
  // note ever grows to thousands of strokes, this is the spot to add a
  // smarter check instead of always returning true.
  @override
  bool shouldRepaint(covariant _StrokesPainter oldDelegate) => true;
}