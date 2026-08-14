import 'dart:async';
import 'package:flutter/material.dart';

import '../models/flashcard.dart';
import '../widgets/color_swatch_picker.dart';
import '../widgets/flip_card.dart';
import '../widgets/mini_audio_player.dart';
import '../widgets/mini_stopwatch_bar.dart';
import 'stopwatch_page.dart';

class FlashcardDeckPage extends StatefulWidget {
  final FlashcardDeck deck;
  final ValueChanged<FlashcardDeck> onDeckUpdated;
  final ValueChanged<String> onDeckDeleted;

  const FlashcardDeckPage({
    super.key,
    required this.deck,
    required this.onDeckUpdated,
    required this.onDeckDeleted,
  });

  @override
  State<FlashcardDeckPage> createState() => _FlashcardDeckPageState();
}

class _FlashcardDeckPageState extends State<FlashcardDeckPage> {
  late PageController _pageController;
  late Color _color;
  late String _title;
  late Set<int> _reviewedIndexes;
  late Map<int, bool> _cardRatings;

  int _index = 0;
  bool _showSummary = false;
  late Stopwatch _sessionStopwatch;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _color = widget.deck.color;
    _title = widget.deck.title;
    _reviewedIndexes = Set<int>.from(widget.deck.reviewedCardIndexes);
    _cardRatings = Map<int, bool>.from(widget.deck.cardRatings);

    _sessionStopwatch = Stopwatch()..start();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _showSummary) setState(() {});
    });

    if (widget.deck.cards.isNotEmpty) {
      _reviewedIndexes.add(0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _notifyUpdate();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sessionStopwatch.stop();
    _pageController.dispose();
    super.dispose();
  }

  void _notifyUpdate() {
    final updatedDeck = FlashcardDeck(
      id: widget.deck.id,
      title: _title,
      cards: widget.deck.cards,
      color: _color,
      createdAt: widget.deck.createdAt,
      reviewedCardIndexes: _reviewedIndexes,
      cardRatings: _cardRatings,
      tags: widget.deck.tags, // Preserves tags on review updates
    );
    widget.onDeckUpdated(updatedDeck);
  }

  void _rateCard(bool gotIt) {
    setState(() {
      _cardRatings[_index] = gotIt;
      _reviewedIndexes.add(_index);
    });
    _notifyUpdate();

    if (_index < widget.deck.cards.length - 1) {
      _next();
    } else {
      setState(() => _showSummary = true);
    }
  }

  void _onCardSwiped(int index) {
    if (index >= widget.deck.cards.length) {
      setState(() => _showSummary = true);
      return;
    }
    setState(() {
      _showSummary = false;
      _index = index;
      _reviewedIndexes.add(index);
    });
    _notifyUpdate();
  }

  void _next() {
    if (_index < widget.deck.cards.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else if (_index == widget.deck.cards.length - 1) {
      setState(() => _showSummary = true);
    }
  }

  void _previous() {
    if (_showSummary) {
      setState(() => _showSummary = false);
      return;
    }
    if (_index > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _restartDeck() {
    setState(() {
      _index = 0;
      _showSummary = false;
      _sessionStopwatch.reset();
      _sessionStopwatch.start();
    });
    _pageController.jumpToPage(0);
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete deck?'),
        content: Text(
          '"$_title" and its ${widget.deck.cards.length} cards will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      widget.onDeckDeleted(widget.deck.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.deck.cards;
    final int gotItCount = _cardRatings.values.where((v) => v == true).length;
    final int missedCount = _cardRatings.values.where((v) => v == false).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              // Progress Bar Header
              Row(
                children: [
                  Text(
                    _showSummary
                        ? '${cards.length} / ${cards.length}'
                        : '${_index + 1} / ${cards.length}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _showSummary ? 1.0 : (_index + 1) / cards.length,
                        minHeight: 8,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation(_color),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Main Viewer (Card PageView or Summary Dashboard)
              Expanded(
                child: _showSummary
                    ? _buildSummaryView(cards.length, gotItCount, missedCount)
                    : PageView.builder(
                        controller: _pageController,
                        itemCount: cards.length,
                        onPageChanged: _onCardSwiped,
                        itemBuilder: (context, i) {
                          final card = cards[i];
                          return Center(
                            child: FlipCard(
                              key: ValueKey(i),
                              front: card.question,
                              back: card.answer,
                              color: _color,
                            ),
                          );
                        },
                      ),
              ),

              if (!_showSummary) ...[
                const SizedBox(height: 12),

                // NotebookLM Action Control Row (Cross, Checkmark & Nav Arrows)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Back Arrow
                    IconButton.filledTonal(
                      onPressed: _index > 0 ? _previous : null,
                      icon: const Icon(Icons.arrow_back),
                      iconSize: 20,
                    ),
                    const SizedBox(width: 16),

                    // Missed Button (Cross)
                    InkWell(
                      onTap: () => _rateCard(false),
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: _cardRatings[_index] == false
                              ? Colors.red.shade900.withOpacity(0.4)
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.red.shade400.withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.close,
                                color: Colors.red.shade400, size: 20),
                            const SizedBox(width: 6),
                            Text(
                              '$missedCount',
                              style: TextStyle(
                                color: Colors.red.shade400,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Got It Button (Checkmark)
                    InkWell(
                      onTap: () => _rateCard(true),
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: _cardRatings[_index] == true
                              ? Colors.green.shade900.withOpacity(0.4)
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.green.shade400.withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '$gotItCount',
                              style: TextStyle(
                                color: Colors.green.shade400,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.check,
                                color: Colors.green.shade400, size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Forward Arrow
                    IconButton.filledTonal(
                      onPressed: _next,
                      icon: const Icon(Icons.arrow_forward),
                      iconSize: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // Color Swatch Picker
              ColorSwatchPicker(
                selectedColor: _color,
                onColorSelected: (color) {
                  setState(() => _color = color);
                  _notifyUpdate();
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MiniStopwatchBar(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StopwatchPage()),
              );
            },
          ),
          const MiniAudioPlayer(),
        ],
      ),
    );
  }

  // NotebookLM Summary Card Widget
  Widget _buildSummaryView(int total, int gotIt, int missed) {
    final int skipped = total - (gotIt + missed);
    final double pct = total > 0 ? (gotIt / total) : 0.0;
    final int percentage = (pct * 100).round();
    final elapsedSec = _sessionStopwatch.elapsed.inSeconds;

    String headline = 'Great effort!';
    if (percentage >= 80) headline = 'Mastery achieved!';
    if (percentage < 50) headline = "You'll get it next time";

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          headline,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Circular Percentage Indicator
              SizedBox(
                width: 110,
                height: 110,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: CircularProgressIndicator(
                        value: pct,
                        strokeWidth: 8,
                        backgroundColor: Colors.grey.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation(
                          percentage >= 50 ? Colors.green : Colors.amber,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$gotIt/$total',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '$percentage%',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          '${elapsedSec}s',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Summary Stats List
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _summaryRow('Got it', gotIt, Colors.green.shade400),
                  const SizedBox(height: 10),
                  _summaryRow('Missed it', missed, Colors.red.shade400),
                  const SizedBox(height: 10),
                  _summaryRow('Skipped', skipped, Colors.grey),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _restartDeck,
          icon: const Icon(Icons.refresh),
          label: const Text('Restart deck'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, int value, Color color) {
    return Row(
      children: [
        Text(
          '$label  ',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}