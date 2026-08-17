import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/flashcard.dart';
import 'flashcard_deck_page.dart';
import 'flashcard_generator_page.dart';
import 'flashcard_editor_page.dart';
import '../widgets/mini_audio_player.dart';
import '../widgets/mini_stopwatch_bar.dart';
import 'stopwatch_page.dart';

class FlashcardsPage extends StatefulWidget {
  const FlashcardsPage({super.key});

  @override
  State<FlashcardsPage> createState() => _FlashcardsPageState();
}

class _FlashcardsPageState extends State<FlashcardsPage> {
  List<FlashcardDeck> _decks = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadDecks();
  }

  Future<void> _loadDecks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('flashcard_decks');
    if (data != null) {
      final List decoded = jsonDecode(data);
      setState(() {
        _decks = decoded.map((item) => FlashcardDeck.fromJson(item)).toList();
      });
    }
  }

  Future<void> _saveDecks() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(_decks.map((d) => d.toJson()).toList());
    await prefs.setString('flashcard_decks', data);
  }

  Future<void> _generateDeck() async {
    final deck = await Navigator.of(context).push<FlashcardDeck>(
      MaterialPageRoute(builder: (_) => const FlashcardGeneratorPage()),
    );
    if (deck == null) return;

    setState(() => _decks.insert(0, deck));
    _saveDecks();

    if (!mounted) return;
    _openDeck(deck);
  }

  Future<void> _createNewDeck() async {
    final deck = await Navigator.of(context).push<FlashcardDeck>(
      MaterialPageRoute(builder: (_) => const FlashcardEditorPage()),
    );
    if (deck == null) return;

    setState(() => _decks.insert(0, deck));
    _saveDecks();
  }

  Future<void> _editDeck(FlashcardDeck deck) async {
  final updatedDeck = await Navigator.of(context).push<FlashcardDeck>(
    MaterialPageRoute(
      builder: (_) => FlashcardEditorPage(initialDeck: deck),
    ),
  );

  if (updatedDeck == null) return;

  setState(() {
    final index = _decks.indexWhere((d) => d.id == updatedDeck.id);
    if (index != -1) {
      _decks[index] = updatedDeck;
    }
  });
  _saveDecks();
}

  void _openDeck(FlashcardDeck deck) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FlashcardDeckPage(
          deck: deck,
          onDeckUpdated: (updatedDeck) {
            setState(() {
              final index = _decks.indexWhere((d) => d.id == updatedDeck.id);
              if (index != -1) {
                _decks[index] = updatedDeck;
              }
            });
            _saveDecks();
          },
          onDeckDeleted: (deletedId) {
            setState(() => _decks.removeWhere((d) => d.id == deletedId));
            _saveDecks();
          },
        ),
      ),
    );
  }

 List<FlashcardDeck> get _filteredDecks {
  if (_searchQuery.trim().isEmpty) return _decks;
  
  // Clean search query: trim spaces and drop leading '#' if typed
  final query = _searchQuery.trim().toLowerCase().replaceAll(RegExp(r'^#'), '');

  return _decks.where((d) {
    final titleMatch = d.title.toLowerCase().contains(query);
    final tagMatch = d.tags.any(
      (tag) => tag.toLowerCase().replaceAll(RegExp(r'^#'), '').contains(query),
    );
    return titleMatch || tagMatch;
  }).toList();
}

  void _showFlashcardTechniquesGuide() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Text('📚', style: TextStyle(fontSize: 26)),
                      SizedBox(width: 8),
                      Text(
                        'Flashcard Mastery Tips',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Mastering flashcards with these powerful techniques!',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 20),

                  // Active Recall Card
                  _buildTechniqueCard(
                    emoji: '🎯',
                    title: '1. Active Recall',
                    subtitle: 'Retrieval Over Recognition',
                    accentColor: Colors.purple.shade100,
                    borderColor: Colors.purple.shade400,
                    description:
                        'Active recall is the practice of forcing your brain to retrieve information from memory rather than passively re-reading it. 🧠',
                    steps: const [
                      'Read the Front: Look at the question and cover the back. 👁️',
                      'Commit to an Answer: Say it out loud or write it down before flipping the card. 🗣️',
                      "No Half-Credit: If you didn't state it clearly before checking, mark it wrong—no guessing! 🔍",
                      'Why It Works: Mental effort creates stronger neural connections, eliminating the "illusion" that you know something just because it looks familiar. 🏋️‍♂️',
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Spaced Repetition Card
                  _buildTechniqueCard(
                    emoji: '🗓️',
                    title: '2. Spaced Repetition',
                    subtitle: 'Beat the Forgetting Curve',
                    accentColor: Colors.teal.shade100,
                    borderColor: Colors.teal.shade400,
                    description:
                        'Spaced repetition is a review schedule that spaces out reviews over increasing time intervals to fight the forgetting curve. ⏳',
                    steps: const [
                      'The Leitner System (5 Boxes):\n   • Box 1: Review daily 📅\n   • Box 2: Review every 3 days 🗓️\n   • Box 3: Review weekly 📊\n   • Box 4: Review every 2 weeks ⌛\n   • Box 5: Review monthly 🏆',
                      'The One Rule: Answer correctly? Move the card up one box. Get it wrong? Send it back to Box 1! 🔁',
                      'Why It Works: You spend time only on cards you struggle with, reviewing them right before you forget them to lock facts into long-term memory. 🎯',
                    ],
                  ),

                  const SizedBox(height: 20),
                  Center(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.rocket_launch, size: 18),
                      label: const Text("Got it! Let's Review"),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTechniqueCard({
    required String emoji,
    required String title,
    required String subtitle,
    required Color accentColor,
    required Color borderColor,
    required String description,
    required List<String> steps,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(fontSize: 13, height: 1.3),
          ),
          const Divider(height: 20),
          ...steps.map(
            (step) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                step,
                style: const TextStyle(fontSize: 12.5, height: 1.35),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudyBanner() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.amber.shade100,
              Colors.orange.shade50,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.shade300, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.shade200.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _showFlashcardTechniquesGuide,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade300,
                      shape: BoxShape.circle,
                    ),
                    child: const Text('💡', style: TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Study Smarter!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'Learn Active Recall & Spaced Repetition',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: Colors.amber.shade900,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flashcard Studio'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStudyBanner(),
              TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search decks or tags...',
                  prefixIcon: const Icon(Icons.search),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Dual Button Action Bar
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: _generateDeck,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0A6C3E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text(
                      'Ingest New Source / Create Deck',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _createNewDeck,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text(
                      'Create Custom Deck',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _filteredDecks.isEmpty
                    ? Center(
                        child: Text(
                          _decks.isEmpty
                              ? 'No decks yet — generate or create your first one!'
                              : 'No matching decks found.',
                          style: TextStyle(
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color
                                ?.withOpacity(0.6),
                          ),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final crossAxisCount =
                              constraints.maxWidth > 700 ? 3 : 2;

                          return GridView.builder(
  itemCount: _filteredDecks.length,
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: crossAxisCount,
    crossAxisSpacing: 12,
    mainAxisSpacing: 12,
    childAspectRatio: 1.35,
  ),
    itemBuilder: (context, index) {
      final deck = _filteredDecks[index];
      return _DeckCardTile(
        deck: deck,
        onTap: () => _openDeck(deck),
        onEdit: () => _editDeck(deck),
      );
    },
          );
                        },
                      ),
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
}

class _DeckCardTile extends StatelessWidget {
  final FlashcardDeck deck;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _DeckCardTile({
    required this.deck,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalCards = deck.cards.length;
    final dueCount = deck.cards.where((c) => c.isDue).length;

    final int gotItCount =
        deck.cardRatings.values.where((v) => v == true).length;
    final int missedCount =
        deck.cardRatings.values.where((v) => v == false).length;
    final int unratedCount = totalCards - (gotItCount + missedCount);

    return Stack(
      // Default Stack clipping would cut the badge off where it pokes
      // past the card's corner — this lets it sit half on, half off.
      clipBehavior: Clip.none,
      children: [
        Material(
          color: isDark ? const Color(0xFF1E222A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: deck.color.withOpacity(0.8),
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              deck.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: onEdit,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$totalCards Cards',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.color
                              ?.withOpacity(0.65),
                        ),
                      ),
                      if (deck.tags.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: deck.tags
                                .map(
                                  (t) => Container(
                                    margin: const EdgeInsets.only(right: 4),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: deck.color.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '#$t',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: deck.color,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          height: 6,
                          child: Row(
                            children: [
                              Expanded(
                                flex: gotItCount == 0 ? 1 : gotItCount,
                                child: Container(
                                  color: Colors.green.shade500
                                      .withOpacity(gotItCount > 0 ? 1.0 : 0.2),
                                ),
                              ),
                              const SizedBox(width: 2),
                              Expanded(
                                flex: missedCount == 0 ? 1 : missedCount,
                                child: Container(
                                  color: Colors.red.shade400.withOpacity(
                                      missedCount > 0 ? 1.0 : 0.2),
                                ),
                              ),
                              const SizedBox(width: 2),
                              Expanded(
                                flex: unratedCount == 0 ? 1 : unratedCount,
                                child: Container(
                                  color: deck.color.withOpacity(
                                      unratedCount > 0 ? 1.0 : 0.2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _statusLabel(
                              'Got it', gotItCount, Colors.green.shade500),
                          _statusLabel(
                              'Missed', missedCount, Colors.red.shade400),
                          _statusLabel('New', unratedCount, deck.color),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // Due-today badge — only shown when there's actually something
        // to review, so decks with nothing due stay uncluttered.
        if (dueCount > 0)
          Positioned(
            top: -6,
            right: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.shade500,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                '$dueCount due',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _statusLabel(String title, int value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$title ',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}