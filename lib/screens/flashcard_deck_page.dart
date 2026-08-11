import 'package:flutter/material.dart';

import '../models/flashcard.dart';
import '../widgets/color_swatch_picker.dart';
import '../widgets/flip_card.dart';

class FlashcardDeckPage extends StatefulWidget {
  final FlashcardDeck deck;
  final ValueChanged<Color> onColorChanged;

  const FlashcardDeckPage({
    super.key,
    required this.deck,
    required this.onColorChanged,
  });

  @override
  State<FlashcardDeckPage> createState() => _FlashcardDeckPageState();
}

class _FlashcardDeckPageState extends State<FlashcardDeckPage> {
  late Color _color;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _color = widget.deck.color;
  }

  void _next() =>
      setState(() => _index = (_index + 1) % widget.deck.cards.length);

  void _previous() => setState(
      () => _index = (_index - 1 + widget.deck.cards.length) % widget.deck.cards.length);

  @override
  Widget build(BuildContext context) {
    final card = widget.deck.cards[_index];

    return Scaffold(
      appBar: AppBar(title: Text(widget.deck.title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                '${_index + 1} / ${widget.deck.cards.length}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Center(
                  child: FlipCard(
                    // New key each card → Flutter treats it as a fresh
                    // widget, so it always starts showing the question.
                    key: ValueKey(_index),
                    front: card.question,
                    back: card.answer,
                    color: _color,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap the card to flip',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton.filledTonal(
                    onPressed: _previous,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  IconButton.filledTonal(
                    onPressed: _next,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ColorSwatchPicker(
                selectedColor: _color,
                onColorSelected: (color) {
                  setState(() => _color = color);
                  widget.onColorChanged(color);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}