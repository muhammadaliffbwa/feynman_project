import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/flashcard.dart';
import 'flashcard_deck_page.dart';
import 'flashcard_generator_page.dart';

class FlashcardsPage extends StatefulWidget {
  const FlashcardsPage({super.key});

  @override
  State<FlashcardsPage> createState() => _FlashcardsPageState();
}

class _FlashcardsPageState extends State<FlashcardsPage> {
  List<FlashcardDeck> _decks = [];

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

  void _openDeck(FlashcardDeck deck) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FlashcardDeckPage(
          deck: deck,
          onColorChanged: (color) {
            setState(() {
              final index = _decks.indexWhere((d) => d.id == deck.id);
              if (index != -1) {
                _decks[index] = FlashcardDeck(
                  id: deck.id,
                  title: deck.title,
                  cards: deck.cards,
                  color: color,
                  createdAt: deck.createdAt,
                );
              }
            });
            _saveDecks();
          },
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(FlashcardDeck deck) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete deck?'),
        content: Text(
          '"${deck.title}" and its ${deck.cards.length} cards will be '
          'permanently deleted.',
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
    return confirmed ?? false;
  }

  void _deleteDeck(FlashcardDeck deck) {
    setState(() => _decks.removeWhere((d) => d.id == deck.id));
    _saveDecks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flashcards')),
      body: _decks.isEmpty
          ? const Center(
              child: Text('No decks yet — generate your first one!'),
            )
          : ListView.builder(
              itemCount: _decks.length,
              itemBuilder: (context, index) {
                final deck = _decks[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: deck.color,
                    child: Text(
                      '${deck.cards.length}',
                      style:
                          const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  title: Text(deck.title),
                  subtitle: Text('${deck.cards.length} cards'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      if (await _confirmDelete(deck)) _deleteDeck(deck);
                    },
                  ),
                  onTap: () => _openDeck(deck),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _generateDeck,
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Generate'),
      ),
    );
  }
}