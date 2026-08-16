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