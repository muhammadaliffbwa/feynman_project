import 'package:flutter/material.dart';
import '../models/note.dart';
import 'color_swatch_picker.dart';

/// The control bar shown under the drawing canvas: pick a tool, a size,
/// a color, or undo/clear.
class DrawToolbar extends StatelessWidget {
  static const List<double> _baseSizes = [2, 5, 10]; // thin / medium / thick

  final StrokeType tool;
  final ValueChanged<StrokeType> onToolChanged;
  final Color color;
  final ValueChanged<Color> onColorChanged;
  final double strokeWidth;
  final ValueChanged<double> onWidthChanged;
  final VoidCallback onUndo;
  final VoidCallback onClear;

  const DrawToolbar({
    super.key,
    required this.tool,
    required this.onToolChanged,
    required this.color,
    required this.onColorChanged,
    required this.strokeWidth,
    required this.onWidthChanged,
    required this.onUndo,
    required this.onClear,
  });

  // Highlighter and eraser strokes read as too thin at pen-sized widths,
  // so each tool scales the same three base sizes up by a different amount.
  double _multiplierFor(StrokeType t) {
    switch (t) {
      case StrokeType.pen:
        return 1;
      case StrokeType.highlighter:
        return 2.5;
      case StrokeType.eraser:
        return 3.5;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ToggleButtons(
                isSelected: StrokeType.values.map((t) => t == tool).toList(),
                onPressed: (index) => onToolChanged(StrokeType.values[index]),
                borderRadius: BorderRadius.circular(10),
                children: const [
                  Padding(padding: EdgeInsets.all(8), child: Icon(Icons.edit)),
                  Padding(
                      padding: EdgeInsets.all(8), child: Icon(Icons.brush)),
                  Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.auto_fix_normal)),
                ],
              ),
              Row(
                children: [
                  IconButton(onPressed: onUndo, icon: const Icon(Icons.undo)),
                  IconButton(
                      onPressed: onClear,
                      icon: const Icon(Icons.delete_outline)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final base in _baseSizes)
                GestureDetector(
                  onTap: () => onWidthChanged(base * _multiplierFor(tool)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Container(
                      width: base * 2 + 8,
                      height: base * 2 + 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: tool == StrokeType.eraser
                            ? Colors.grey.shade400
                            : color,
                        border: (strokeWidth == base * _multiplierFor(tool))
                            ? Border.all(color: Colors.black87, width: 2)
                            : null,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (tool != StrokeType.eraser) ...[
            const SizedBox(height: 8),
            ColorSwatchPicker(
                selectedColor: color, onColorSelected: onColorChanged),
          ],
        ],
      ),
    );
  }
}