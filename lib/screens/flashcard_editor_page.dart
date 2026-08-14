import 'package:flutter/material.dart';

import '../models/flashcard.dart';
import '../widgets/color_swatch_picker.dart';
import '../widgets/mini_audio_player.dart';
import '../widgets/mini_stopwatch_bar.dart';
import 'stopwatch_page.dart';

class FlashcardEditorPage extends StatefulWidget {
  final FlashcardDeck? initialDeck;

  const FlashcardEditorPage({super.key, this.initialDeck});

  @override
  State<FlashcardEditorPage> createState() => _FlashcardEditorPageState();
}

class _FlashcardEditorPageState extends State<FlashcardEditorPage> {
  final _titleController = TextEditingController();
  final _questionController = TextEditingController();
  final _answerController = TextEditingController();
  final _tagInputController = TextEditingController();

  List<Flashcard> _cards = [];
  List<String> _tags = [];
  Color _selectedColor = const Color(0xFF2196F3);
  int? _editingCardIndex;

  @override
  void initState() {
    super.initState();
    if (widget.initialDeck != null) {
      _titleController.text = widget.initialDeck!.title;
      _cards = List.from(widget.initialDeck!.cards);
      _tags = List.from(widget.initialDeck!.tags);
      _selectedColor = widget.initialDeck!.color;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _questionController.dispose();
    _answerController.dispose();
    _tagInputController.dispose();
    super.dispose();
  }

  void _addOrUpdateCard() {
    final q = _questionController.text.trim();
    final a = _answerController.text.trim();

    if (q.isEmpty || a.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both question and answer.')),
      );
      return;
    }

    setState(() {
      if (_editingCardIndex != null) {
        _cards[_editingCardIndex!] = Flashcard(question: q, answer: a);
        _editingCardIndex = null;
      } else {
        _cards.add(Flashcard(question: q, answer: a));
      }
      _questionController.clear();
      _answerController.clear();
    });
  }

  void _editCard(int index) {
    setState(() {
      _editingCardIndex = index;
      _questionController.text = _cards[index].question;
      _answerController.text = _cards[index].answer;
    });
  }

  void _deleteCard(int index) {
    setState(() {
      if (_editingCardIndex == index) {
        _editingCardIndex = null;
        _questionController.clear();
        _answerController.clear();
      }
      _cards.removeAt(index);
    });
  }

  void _addTag() {
    final tag = _tagInputController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagInputController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
  }

  // In _FlashcardEditorPageState:

void _saveDeck() {
  final title = _titleController.text.trim();
  if (title.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please enter a deck title.')),
    );
    return;
  }

  if (_cards.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please add at least one card.')),
    );
    return;
  }

  final newDeck = FlashcardDeck(
    id: widget.initialDeck?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
    title: title,
    cards: _cards,
    color: _selectedColor,
    tags: List<String>.from(_tags), // Ensure deep copy of tags list
    createdAt: widget.initialDeck?.createdAt,
    reviewedCardIndexes: widget.initialDeck?.reviewedCardIndexes,
    cardRatings: widget.initialDeck?.cardRatings,
  );

  Navigator.of(context).pop(newDeck);
}

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialDeck == null ? 'Create Flashcard Deck' : 'Edit Flashcard Deck'),
        actions: [
          FilledButton.icon(
            onPressed: _saveDeck,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0A6C3E),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Save Deck'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _buildCardBuilderPanel(isDark)),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(flex: 2, child: _buildDeckConfigPanel(isDark)),
                ],
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildDeckConfigPanel(isDark),
                  const SizedBox(height: 24),
                  _buildCardBuilderPanel(isDark),
                ],
              ),
            );
          },
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

  // Left Section - Card Editor
  Widget _buildCardBuilderPanel(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _editingCardIndex == null ? 'Add Card' : 'Edit Card #${_editingCardIndex! + 1}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _questionController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Question (Front)',
              alignLabelWithHint: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _answerController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Answer (Back)',
              alignLabelWithHint: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _addOrUpdateCard,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0A6C3E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              icon: Icon(_editingCardIndex == null ? Icons.add : Icons.save, size: 20),
              label: Text(_editingCardIndex == null ? 'Add Card' : 'Update Card'),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Cards in this Deck (${_cards.length})',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _cards.isEmpty
              ? Container(
                  height: 100,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E222A) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('No cards created yet. Add one above!', style: TextStyle(color: Colors.grey)),
                )
              : SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _cards.length,
                    itemBuilder: (context, index) {
                      final card = _cards[index];
                      final isEditingThis = _editingCardIndex == index;

                      return Container(
                        width: 160,
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isEditingThis
                              ? _selectedColor.withOpacity(0.2)
                              : (isDark ? const Color(0xFF1E222A) : Colors.white),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isEditingThis ? _selectedColor : Colors.grey.withOpacity(0.3),
                            width: isEditingThis ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Front', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                            Text(
                              card.question,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            const Spacer(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                InkWell(
                                  onTap: () => _editCard(index),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4.0),
                                    child: Icon(Icons.edit_outlined, size: 16, color: Colors.blue),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: () => _deleteCard(index),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4.0),
                                    child: Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }

  // Right Section - Deck Settings & Tags
  Widget _buildDeckConfigPanel(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Deck Configuration',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Deck Title',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Theme Color', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          ColorSwatchPicker(
            selectedColor: _selectedColor,
            onColorSelected: (c) => setState(() => _selectedColor = c),
          ),
          const SizedBox(height: 24),
          const Text('Tags & Labels', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagInputController,
                  decoration: InputDecoration(
                    hintText: 'Add a tag...',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onSubmitted: (_) => _addTag(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: _addTag,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tags
                .map(
                  (tag) => Chip(
                    label: Text(tag, style: const TextStyle(fontSize: 12)),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () => _removeTag(tag),
                    backgroundColor: isDark ? const Color(0xFF2C303B) : Colors.grey.shade200,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}