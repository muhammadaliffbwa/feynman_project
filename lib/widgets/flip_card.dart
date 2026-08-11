import 'dart:math';
import 'package:flutter/material.dart';

/// A card that flips like a physical flashcard when tapped, revealing
/// [back] in place of [front]. Give each instance a distinct `key` (e.g.
/// based on its position in a deck) — that makes Flutter treat a new
/// card as a genuinely new widget, so it starts on the front face again
/// instead of staying flipped when you move to the next card.
class FlipCard extends StatefulWidget {
  final String front;
  final String back;
  final Color color;

  const FlipCard({
    super.key,
    required this.front,
    required this.back,
    required this.color,
  });

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _showingFront = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flip() {
    setState(() {
      _showingFront ? _controller.forward() : _controller.reverse();
      _showingFront = !_showingFront;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _flip,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          // The controller runs 0 -> 1 over the flip; multiplying by pi
          // turns that into a half-turn in radians. Past the halfway
          // point we're looking at the back of the rotated card, so we
          // swap in the answer text and apply a second rotation to
          // un-mirror it (otherwise it would render backwards).
          final angle = _controller.value * pi;
          final showingBackFace = angle > pi / 2;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // perspective, so it looks 3D not squashed
              ..rotateY(angle),
            child: showingBackFace
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(pi),
                    child: _face(widget.back),
                  )
                : _face(widget.front),
          );
        },
      ),
    );
  }

  Widget _face(String text) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 220),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}