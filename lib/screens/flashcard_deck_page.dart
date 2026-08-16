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
  // Visual style for each rating button — color and label only; the
  // interval preview text is computed per-card, not stored here.
  static const Map<ReviewRating, ({Color color, String label})>
      _ratingStyles = {
    ReviewRating.again: (color: Color(0xFFEF5350), label: 'Again'),
    ReviewRating.hard: (color: Color(0xFFFFA726), label: 'Hard'),
    ReviewRating.good: (color: Color(0xFF66BB6A), label: 'Good'),
    ReviewRating.easy: (color: Color(0xFF42A5F5), label: 'Easy'),
  };

  late PageController _pageController;
  late Color _color;
  late String _title;
  late Set<int> _reviewedIndexes;
  late Map<int, bool> _cardRatings;

  // Indexes into widget.deck.cards that make up *this session's* queue —
  // due cards only, unless _reviewAllMode is on. Keeping the original
  // deck-wide index (rather than a 0-based session index) is what keeps
  // _cardRatings compatible with the stats shown on the deck list page.
  late List<int> _queueIndexes;
  bool _reviewAllMode = false;

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

    _queueIndexes = [
      for (int i = 0; i < widget.deck.cards.length; i++)
        if (widget.deck.cards[i].isDue) i,
    ];

    _sessionStopwatch = Stopwatch()..start();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _showSummary) setState(() {});
    });

    if (_queueIndexes.isNotEmpty) {
      _reviewedIndexes.add(_queueIndexes[0]);
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
      tags: widget.deck.tags,
    );
    widget.onDeckUpdated(updatedDeck);
  }

  // Rebuilds the session queue — due-only by default, or every card when
  // includeAll is true (used by "Review all cards anyway" and restart).
  void _rebuildQueue({required bool includeAll}) {
    setState(() {
      _reviewAllMode = includeAll;
      _queueIndexes = [
        for (int i = 0; i < widget.deck.cards.length; i++)
          if (includeAll || widget.deck.cards[i].isDue) i,
      ];
      _index = 0;
      _showSummary = false;
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  void _rateCard(ReviewRating rating) {
    final cardIndex = _queueIndexes[_index];
    final card = widget.deck.cards[cardIndex];

    setState(() {
      // Mutates the card in place — repetitions/intervalMinutes/
      // easeFactor/nextDueDate all live directly on the Flashcard
      // object, and widget.deck.cards holds the same references, so
      // this is enough to update the underlying deck without rebuilding
      // the list.
      card.processReview(rating);

      // Again = missed, everything else = got it. This is what keeps the
      // deck tile's Got it / Missed counters (elsewhere in the app)
      // working without changes, since they only know true/false.
      _cardRatings[cardIndex] = rating != ReviewRating.again;
      _reviewedIndexes.add(cardIndex);
    });
    _notifyUpdate();

    if (_index < _queueIndexes.length - 1) {
      _next();
    } else {
      setState(() => _showSummary = true);
    }
  }

  void _onCardSwiped(int index) {
    if (index >= _queueIndexes.length) {
      setState(() => _showSummary = true);
      return;
    }
    setState(() {
      _showSummary = false;
      _index = index;
      _reviewedIndexes.add(_queueIndexes[index]);
    });
    _notifyUpdate();
  }

  void _next() {
    if (_index < _queueIndexes.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else if (_index == _queueIndexes.length - 1) {
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
    _sessionStopwatch.reset();
    _sessionStopwatch.start();
    _rebuildQueue(includeAll: _reviewAllMode);
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

  // Formats a minute count the way Anki's own buttons do — minutes for
  // short intervals, then hours, days, months, years as it grows.
  String _formatIntervalPreview(int minutes) {
    if (minutes < 60) return '${minutes}m';
    if (minutes < 1440) return '${(minutes / 60).round()}h';
    final days = minutes / 1440;
    if (days < 30) return '${days.round()}d';
    if (days < 365) return '${(days / 30).round()}mo';
    return '${(days / 365).round()}y';
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.deck.cards;
    final int gotItCount = _cardRatings.values.where((v) => v == true).length;
    final int missedCount =
        _cardRatings.values.where((v) => v == false).length;
    final bool hasQueue = _queueIndexes.isNotEmpty;

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
              // Progress Bar Header — hidden while there's nothing queued
              // and no summary to show, since "0 / 0" isn't meaningful.
              if (hasQueue || _showSummary) ...[
                Row(
                  children: [
                    Text(
                      _showSummary
                          ? '${_queueIndexes.length} / ${_queueIndexes.length}'
                          : '${_index + 1} / ${_queueIndexes.length}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _showSummary
                              ? 1.0
                              : (_index + 1) / _queueIndexes.length,
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
              ],

              // Main Viewer
              Expanded(
                child: _showSummary
                    ? _buildSummaryView(cards.length, gotItCount, missedCount)
                    : !hasQueue
                        ? _buildAllCaughtUpView()
                        : PageView.builder(
                            controller: _pageController,
                            itemCount: _queueIndexes.length,
                            onPageChanged: _onCardSwiped,
                            itemBuilder: (context, i) {
                              final card = cards[_queueIndexes[i]];
                              return Center(
                                child: FlipCard(
                                  key: ValueKey(_queueIndexes[i]),
                                  front: card.question,
                                  back: card.answer,
                                  color: _color,
                                ),
                              );
                            },
                          ),
              ),

              if (!_showSummary && hasQueue) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: _index > 0 ? _previous : null,
                      icon: const Icon(Icons.arrow_back),
                      iconSize: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child:
                          _buildRatingButtons(cards[_queueIndexes[_index]]),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

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

  // The four Again/Hard/Good/Easy buttons, each showing what interval
  // picking it would produce — same idea as Anki's own button captions.
  Widget _buildRatingButtons(Flashcard card) {
    return Row(
      children: ReviewRating.values.map((rating) {
        final style = _ratingStyles[rating]!;
        final minutes = card.previewIntervalMinutes(rating);
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: InkWell(
              onTap: () => _rateCard(rating),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: style.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: style.color.withValues(alpha: 0.5)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      style.label,
                      style: TextStyle(
                        color: style.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatIntervalPreview(minutes),
                      style: TextStyle(
                        color: style.color.withValues(alpha: 0.8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // Shown when every card is already scheduled for a future date.
  Widget _buildAllCaughtUpView() {
    final nextDue = widget.deck.cards.isEmpty
        ? DateTime.now()
        : widget.deck.cards
            .map((c) => c.nextDueDate)
            .reduce((a, b) => a.isBefore(b) ? a : b);
    final untilNext = nextDue.difference(DateTime.now());

    String nextLabel;
    if (untilNext.inMinutes <= 0) {
      nextLabel = 'Next review is ready soon';
    } else if (untilNext.inHours < 1) {
      nextLabel = 'Next review in ${untilNext.inMinutes} min';
    } else if (untilNext.inDays < 1) {
      nextLabel = 'Next review in ${untilNext.inHours}h';
    } else {
      final d = untilNext.inDays;
      nextLabel = 'Next review in $d day${d == 1 ? '' : 's'}';
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: _color),
          const SizedBox(height: 16),
          const Text(
            'All caught up!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            nextLabel,
            style: TextStyle(
              color: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.color
                  ?.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          if (widget.deck.cards.isNotEmpty)
            OutlinedButton.icon(
              onPressed: () => _rebuildQueue(includeAll: true),
              icon: const Icon(Icons.replay),
              label: const Text('Review all cards anyway'),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
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
                        backgroundColor: Colors.grey.withValues(alpha: 0.2),
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
          label: Text(
              _reviewAllMode ? 'Review again' : 'Check for more due cards'),
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