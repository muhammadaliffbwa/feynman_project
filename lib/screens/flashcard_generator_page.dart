import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';

import '../models/flashcard.dart';
import '../widgets/color_swatch_picker.dart';
import '../widgets/mini_audio_player.dart';
import '../widgets/mini_stopwatch_bar.dart';
import 'stopwatch_page.dart';

class FlashcardGeneratorPage extends StatefulWidget {
  const FlashcardGeneratorPage({super.key});

  @override
  State<FlashcardGeneratorPage> createState() =>
      _FlashcardGeneratorPageState();
}

class _FlashcardGeneratorPageState extends State<FlashcardGeneratorPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final List<PlatformFile> _files = [];
  bool _isGenerating = false;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _addFiles() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
    );
    if (picked.isEmpty) return;
    setState(() => _files.addAll(picked));
  }

  void _removeFile(PlatformFile file) => setState(() => _files.remove(file));

  String _mimeTypeFor(String filename) {
    switch (filename.split('.').last.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _generate() async {
    if (_files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one file first')),
      );
      return;
    }
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give this deck a name first')),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      // Forces Gemini's response to match this exact shape — a list of
      // {question, answer} objects — instead of hoping it follows
      // instructions in the prompt. This is what makes jsonDecode()
      // below safe to trust.
      final schema = Schema.array(
        items: Schema.object(
          properties: {
            'question': Schema.string(),
            'answer': Schema.string(),
          },
        ),
      );

      final model = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-3.6-flash',
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          responseSchema: schema,
        ),
      );

      final extra = _notesController.text.trim();
      final parts = <Part>[
        TextPart(
          'You are helping a student create study flashcards from the '
          'attached materials. Read everything provided and generate '
          'clear, focused flashcards covering the key concepts, '
          'definitions, and facts. Write natural questions (not just '
          'fill-in-the-blank) and concise, correct answers. Generate as '
          'many flashcards as the material reasonably supports.'
          '${extra.isEmpty ? '' : '\n\nExtra instructions from the student: $extra'}',
        ),
        for (final file in _files)
          InlineDataPart(_mimeTypeFor(file.name), await file.readAsBytes()),
      ];

      final response = await model.generateContent([Content.multi(parts)]);
      final raw = response.text;
      if (raw == null || raw.isEmpty) {
        throw Exception('The model returned an empty response.');
      }

      final decoded = jsonDecode(raw) as List;
      final cards = decoded
          .map((item) => Flashcard.fromJson(item as Map<String, dynamic>))
          .toList();

      if (cards.isEmpty) {
        throw Exception('No flashcards were generated — try different files.');
      }

      final deck = FlashcardDeck(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        cards: cards,
        color: ColorSwatchPicker.options.first,
      );

      if (!mounted) return;
      Navigator.of(context).pop(deck);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Generation failed'),
          content: Text('$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Generate Flashcards')),
      body: _isGenerating
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Reading your files and writing flashcards…'),
                  SizedBox(height: 4),
                  Text(
                    'This can take up to a minute for longer documents',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Deck name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: _addFiles,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Add files (PDF or image)'),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Add 2–3 files or more for the best results. Export '
                  'slides as PDF first — raw .pptx files aren\'t supported.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                ..._files.map(
                  (file) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.description_outlined),
                    title: Text(file.name, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => _removeFile(file),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Extra instructions (optional)',
                    hintText: 'e.g. focus only on chapter 3',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _generate,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Generate Flashcards'),
                  ),
                ),
              ],
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