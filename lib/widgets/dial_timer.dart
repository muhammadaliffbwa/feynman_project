import 'dart:math';
import 'package:flutter/material.dart';

/// A circular "oven knob" style dial.
///
/// - [progress] is 0.0–1.0: how far around the circle the arc/knob sits.
///   0 = 12 o'clock, and it fills clockwise up to 1.0 (back to 12 o'clock).
/// - [color] tints the arc, knob, and center text.
/// - [label] / [sublabel] sit in the middle (e.g. "25" / "minutes").
/// - [onChanged] fires with a new progress value while the user drags or
///   taps. Pass null to make the dial read-only (used while running).
class DialTimer extends StatelessWidget {
  final double progress;
  final Color color;
  final String label;
  final String sublabel;
  final ValueChanged<double>? onChanged;

  const DialTimer({
    super.key,
    required this.progress,
    required this.color,
    required this.label,
    this.sublabel = '',
    this.onChanged,
  });

  void _handleTouch(Offset localPosition, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;

    final angle = atan2(dy, dx);
    double normalized = (angle + pi / 2) / (2 * pi);
    if (normalized < 0) normalized += 1;
    if (normalized > 1) normalized -= 1;

    onChanged?.call(normalized);
  }

  @override
  Widget build(BuildContext context) {
    // Reads the theme's own text color (flips light/dark automatically)
    // instead of a hardcoded grey that would vanish on a dark background.
    final sublabelColor =
        Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onPanUpdate: onChanged == null
              ? null
              : (details) => _handleTouch(details.localPosition, size),
          onTapDown: onChanged == null
              ? null
              : (details) => _handleTouch(details.localPosition, size),
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: CustomPaint(
              painter: _DialPainter(
                progress: progress,
                color: color,
                interactive: onChanged != null,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    if (sublabel.isNotEmpty)
                      Text(
                        sublabel,
                        style: TextStyle(fontSize: 14, color: sublabelColor),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DialPainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool interactive;

  _DialPainter({
    required this.progress,
    required this.color,
    required this.interactive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 12;

    final trackPaint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    const startAngle = -pi / 2;
    final sweepAngle = 2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      arcPaint,
    );

    if (interactive) {
      final knobAngle = startAngle + sweepAngle;
      final knobCenter = Offset(
        center.dx + radius * cos(knobAngle),
        center.dy + radius * sin(knobAngle),
      );
      canvas.drawCircle(knobCenter, 14, Paint()..color = color);
      canvas.drawCircle(
        knobCenter,
        14,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DialPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.interactive != interactive;
  }
}