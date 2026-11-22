import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/note.dart';
import 'note_editor_page.dart';
import '../widgets/mini_audio_player.dart';
import '../widgets/mini_stopwatch_bar.dart';
import 'stopwatch_page.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  List<Note> _notes = [];

  // Preset soft pastel colors for card backgrounds
  final List<Color> _noteColors = const [
    Colors.white,
    Color(0xFFFFCDD2), // Soft Red
    Color(0xFFFFE0B2), // Soft Orange
    Color(0xFFFFF9C4), // Soft Yellow
    Color(0xFFC8E6C9), // Soft Green
    Color(0xFFB3E5FC), // Soft Blue
    Color(0xFFE1BEE7), // Soft Purple
  ];

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('notes');
    if (data != null) {
      final List decoded = jsonDecode(data);
      setState(() {
        _notes = decoded.map((item) => Note.fromJson(item)).toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      });
    }
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(_notes.map((n) => n.toJson()).toList());
    await prefs.setString('notes', data);
  }

  Future<void> _openNote([Note? note]) async {
    final result = await Navigator.of(context).push<Note>(
      MaterialPageRoute(builder: (_) => NoteEditorPage(note: note)),
    );
    if (result == null) return; // backed out without saving

    setState(() {
      final index = _notes.indexWhere((n) => n.id == result.id);
      if (index == -1) {
        _notes.add(result);
      } else {
        _notes[index] = result;
      }
      _notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    });
    _saveNotes();
  }

  void _updateNoteColor(Note note, Color newColor) {
    setState(() {
      final index = _notes.indexWhere((n) => n.id == note.id);
      if (index != -1) {
        _notes[index] = note.copyWith(colorValue: newColor.value);
      }
    });
    _saveNotes();
  }

  void _deleteNote(Note note) {
    setState(() => _notes.removeWhere((n) => n.id == note.id));
    _saveNotes();
  }

  Future<bool> _confirmDelete(Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete note?'),
        content: Text(
          '"${note.title.isEmpty ? 'Untitled note' : note.title}" will be '
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

  void _showColorPickerSheet(Note note) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Note Accent Color',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 50,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _noteColors.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final color = _noteColors[index];
                    final isSelected = (note.colorValue == color.value);

                    return GestureDetector(
                      onTap: () {
                        _updateNoteColor(note, color);
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.grey.shade400,
                            width: isSelected ? 3 : 1,
                          ),
                          boxShadow: [
                            if (isSelected)
                              BoxShadow(
                                color: color.withOpacity(0.6),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                          ],
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, size: 24, color: Colors.black54)
                            : null,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _showStudyTechniquesGuide() {
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
                      Text('🧠', style: TextStyle(fontSize: 26)),
                      SizedBox(width: 8),
                      Text(
                        'Efficient Note-Taking Tips',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Supercharge your learning with these proven techniques!',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 20),

                  // Blurting Technique Card
                  _buildTechniqueCard(
                    emoji: '⚡',
                    title: '1. The Blurting Method',
                    subtitle: 'Active Memory Dump',
                    accentColor: Colors.amber.shade100,
                    borderColor: Colors.amber.shade400,
                    description:
                        'Blurting tests your baseline memory by forcing your brain to retrieve information without looking at source material.',
                    steps: const [
                      '📖 Step 1: Read & Absorb – Review your source notes or textbook chapter for 10–15 minutes.',
                      '✍️ Step 2: The Dump – Close all materials. On a blank sheet of paper, write down everything you can remember about the topic (definitions, steps, dates, formulas, bullet points) as quickly as possible without stopping.',
                      '🔍 Step 3: The Gap Audit – Open your source notes and grab a colored pen. Mark missing information, correct mistakes, and circle concepts you struggled to articulate.',
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Feynman Technique Card
                  _buildTechniqueCard(
                    emoji: '💡',
                    title: '2. The Feynman Technique',
                    subtitle: 'Simplification & Mastery',
                    accentColor: Colors.lightBlue.shade100,
                    borderColor: Colors.lightBlue.shade400,
                    description:
                        'While blurting reveals facts you forgot, the Feynman Technique targets weak logical links and forces true comprehension.',
                    steps: const [
                      '🎯 Step 1: Select a Target Concept – Take a topic you stumbled on during your Blurting gap audit.',
                      '👶 Step 2: Explain it to a 12-Year-Old – Write an explanation of the topic on a clean page using simple, plain language. Avoid jargon—if you must use a technical term, explain it with an everyday analogy.',
                      '⚙️ Step 3: Pinpoint & Refine Friction – When you get stuck or catch yourself using overly complex words to mask confusion, return to your reference notes. Refine your explanation until it flows simply and clearly.',
                    ],
                  ),

                  const SizedBox(height: 20),
                  Center(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.rocket_launch, size: 18),
                      label: const Text('Got it! Let\'s Study'),
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
        color: accentColor.withValues(alpha: 0.25),
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
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
      padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 4.0),
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
            onTap: _showStudyTechniquesGuide,
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
                          'Learn Blurting & Feynman techniques',
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

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Today, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Notes', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
      ),
      body: Column(
        children: [
          _buildStudyBanner(),
          Expanded(
            child: _notes.isEmpty ? _buildEmptyState() : _buildNotesGrid(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openNote(),
        icon: const Icon(Icons.add),
        label: const Text('New Note'),
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withAlpha(80),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.edit_note_rounded,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No notes here yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Capture thoughts, draw ideas, or keep quick memos anytime.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _openNote(),
              icon: const Icon(Icons.add),
              label: const Text('Create Your First Note'),
            ),
          ],
        ),
      ),
    );
  }

Widget _buildNotesGrid() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.85,
        ),
        itemCount: _notes.length,
        itemBuilder: (context, index) {
          final note = _notes[index];
          final hasDrawing = note.strokes.isNotEmpty;
          final hasText = note.textDelta.isNotEmpty;

          // Use dark surface for default uncolored cards in dark mode,
          // while preserving chosen pastel colors with dark foreground ink.
          final bool isDefaultWhite =
              note.colorValue == null || note.colorValue == Colors.white.toARGB32();
          final Color cardColor = isDefaultWhite
              ? (isDark
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                  : Colors.white)
              : Color(note.colorValue!);

          final bool isLightCard = cardColor.computeLuminance() > 0.5;
          final Color titleColor =
              isLightCard ? Colors.black87 : Theme.of(context).colorScheme.onSurface;
          final Color subTextColor = isLightCard
              ? Colors.black54
              : Theme.of(context).colorScheme.onSurfaceVariant;
          final Color innerBoxColor = isLightCard
              ? Colors.white.withValues(alpha: 0.65)
              : Colors.black.withValues(alpha: 0.2);
          final Color chipBgColor = isLightCard
              ? Colors.white.withValues(alpha: 0.85)
              : Theme.of(context).colorScheme.surfaceContainerHigh;

          return Card(
            color: cardColor,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isLightCard
                    ? Colors.grey.shade300
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _openNote(note),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            note.title.isEmpty ? 'Untitled' : note.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: titleColor,
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, size: 20, color: titleColor),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onSelected: (value) async {
                            if (value == 'color') {
                              _showColorPickerSheet(note);
                            } else if (value == 'delete') {
                              if (await _confirmDelete(note)) {
                                _deleteNote(note);
                              }
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'color',
                              child: Row(
                                children: [
                                  Icon(Icons.palette_outlined, size: 18),
                                  SizedBox(width: 8),
                                  Text('Change Color'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                  SizedBox(width: 8),
                                  Text('Delete', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: innerBoxColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          hasText
                              ? 'Tap to view note content...'
                              : (hasDrawing ? 'Drawing attached' : 'Empty note'),
                          style: TextStyle(
                            fontSize: 12,
                            color: subTextColor,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      children: [
                        if (hasText)
                          Chip(
                            avatar: Icon(Icons.text_fields, size: 12, color: titleColor),
                            label: Text(
                              'Text',
                              style: TextStyle(fontSize: 10, color: titleColor),
                            ),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            backgroundColor: chipBgColor,
                          ),
                        if (hasDrawing)
                          Chip(
                            avatar: Icon(Icons.brush, size: 12, color: titleColor),
                            label: Text(
                              'Sketch',
                              style: TextStyle(fontSize: 10, color: titleColor),
                            ),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            backgroundColor: chipBgColor,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(note.updatedAt),
                      style: TextStyle(fontSize: 11, color: subTextColor),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}