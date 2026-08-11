import 'package:flutter/material.dart';

/// A row of selectable color circles. Tapping a swatch calls
/// [onColorSelected]; the current selection is shown slightly larger
/// with an outline. Reused by Pomodoro, the drawing toolbar, and the
/// study stopwatch.
class ColorSwatchPicker extends StatelessWidget {
  static const List<Color> options = [
    Color(0xFF0A6C3E), // green — matches the app's default theme
    Color(0xFF1E88E5), // blue
    Color(0xFFFB8C00), // orange
    Color(0xFFE53935), // red
    Color(0xFF8E24AA), // purple
    Color(0xFF00897B), // teal
  ];

  final Color selectedColor;
  final ValueChanged<Color> onColorSelected;

  const ColorSwatchPicker({
    super.key,
    required this.selectedColor,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    // onSurface flips between near-black (light theme) and near-white
    // (dark theme) automatically, so the selection ring stays visible
    // against the page background either way — a hardcoded black87
    // border used to blend into a dark background.
    final borderColor = Theme.of(context).colorScheme.onSurface;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: options.map((color) {
        final isSelected = color.toARGB32() == selectedColor.toARGB32();
        return GestureDetector(
          onTap: () => onColorSelected(color),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 6),
            width: isSelected ? 36 : 28,
            height: isSelected ? 36 : 28,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border:
                  isSelected ? Border.all(color: borderColor, width: 2) : null,
            ),
          ),
        );
      }).toList(),
    );
  }
}