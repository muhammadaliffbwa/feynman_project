import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:google_fonts/google_fonts.dart';

import '../models/note.dart';
import '../widgets/color_swatch_picker.dart';
import '../widgets/draw_toolbar.dart';
import '../widgets/drawing_canvas.dart';
import '../widgets/mini_audio_player.dart';
import '../widgets/mini_stopwatch_bar.dart';
import 'stopwatch_page.dart';

enum _EditorMode { text, draw }

class NoteEditorPage extends StatefulWidget {
  final Note? note; // null when creating a brand new note

  const NoteEditorPage({super.key, this.note});

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  // Fonts offered in the Text-mode toolbar. Using GoogleFonts.xxx()
  // .fontFamily here (instead of typing the name as a plain string)
  // guarantees it matches exactly what got registered in main(), which
  // is what makes the font actually render.
  static final Map<String, String> _fontFamilies = {
    'Poppins': GoogleFonts.poppins().fontFamily!,
    'Merriweather': GoogleFonts.merriweather().fontFamily!,
    'Courier Prime': GoogleFonts.courierPrime().fontFamily!,
    'Caveat': GoogleFonts.caveat().fontFamily!,
    'Germania One': GoogleFonts.germaniaOne().fontFamily!,
  };

  late final TextEditingController _titleController;
  late final quill.QuillController _quillController;
  late List<DrawStroke> _strokes;

  _EditorMode _mode = _EditorMode.text;
  StrokeType _tool = StrokeType.pen;
  Color _drawColor = ColorSwatchPicker.options.first;
  double _strokeWidth = 5;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _strokes = List<DrawStroke>.from(widget.note?.strokes ?? []);

    _quillController =
        widget.note != null && widget.note!.textDelta.isNotEmpty
            ? quill.QuillController(
                document: quill.Document.fromJson(widget.note!.textDelta),
                selection: const TextSelection.collapsed(offset: 0),
              )
            : quill.QuillController.basic();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _quillController.dispose();
    super.dispose();
  }

  void _save() {
    final note = Note(
      id: widget.note?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      textDelta: _quillController.document.toDelta().toJson(),
      strokes: _strokes,
      updatedAt: DateTime.now(),
    );
    Navigator.of(context).pop(note);
  }

  void _insertTextBox() {
    final index = _quillController.selection.baseOffset;
    final length = _quillController.selection.extentOffset - index;
    _quillController.replaceText(
      index,
      length,
      '\n',
      TextSelection.collapsed(offset: index + 1),
    );
  }

  // Replaces Quill's built-in background-color button (broken picker).
  //
  // The fix that matters here: the selection is captured *before* the
  // bottom sheet opens. Opening it moves focus away from the editor,
  // which collapses the editor's live selection — so reading
  // `_quillController.selection` again *after* the sheet closes would
  // grab an empty range instead of the text you picked, and applying a
  // color to an empty range does nothing visible. Capturing it early
  // and formatting that exact range with formatText() sidesteps that.
  Future<void> _pickBackgroundColor() async {
    final selection = _quillController.selection;

    if (selection.isCollapsed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select some text first, then tap Background'),
        ),
      );
      return;
    }

    final result = await showModalBottomSheet<Color>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Highlight background',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 16),
              ColorSwatchPicker(
                selectedColor: ColorSwatchPicker.options.first,
                onColorSelected: (color) => Navigator.of(context).pop(color),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(Colors.transparent),
                child: const Text('Remove background'),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == null) return; // dismissed without picking anything

    final attribute = result == Colors.transparent
        ? const quill.BackgroundAttribute(null)
        : quill.BackgroundAttribute(
            '#${(result.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
          );

    // Format the range we captured up front — not whatever the live
    // selection happens to be right now.
    _quillController.formatText(
      selection.start,
      selection.end - selection.start,
      attribute,
    );
  }

  void _undoStroke() {
    if (_strokes.isEmpty) return;
    setState(() => _strokes = List<DrawStroke>.from(_strokes)..removeLast());
  }

  void _clearCanvas() => setState(() => _strokes = []);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            hintText: 'Note title',
            border: InputBorder.none,
          ),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(onPressed: _save, icon: const Icon(Icons.check)),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: SegmentedButton<_EditorMode>(
              segments: const [
                ButtonSegment(
                  value: _EditorMode.text,
                  label: Text('Text'),
                  icon: Icon(Icons.text_fields),
                ),
                ButtonSegment(
                  value: _EditorMode.draw,
                  label: Text('Draw'),
                  icon: Icon(Icons.brush),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (selection) =>
                  setState(() => _mode = selection.first),
            ),
          ),
        ),
      ),
      body: _mode == _EditorMode.text ? _buildTextMode() : _buildDrawMode(),
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

  Widget _buildTextMode() {
    return Container(
      color: Colors.grey.shade100, // Light neutral background for outer area
      child: Column(
        children: [
          Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _insertTextBox,
                            icon: const Icon(Icons.add_box_outlined, size: 18),
                            label: const Text('New text box'),
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _pickBackgroundColor,
                        icon: const Icon(Icons.format_color_fill, size: 18),
                        label: const Text('Text Background'),
                      ),
                    ],
                  ),
                ),
                quill.QuillSimpleToolbar(
                  controller: _quillController,
                  config: quill.QuillSimpleToolbarConfig(
                    showBackgroundColorButton: false,
                    buttonOptions: quill.QuillSimpleToolbarButtonOptions(
                      fontFamily: quill.QuillToolbarFontFamilyButtonOptions(
                        items: _fontFamilies,
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1, thickness: 1),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: quill.QuillEditor.basic(
                  controller: _quillController,
                  config: const quill.QuillEditorConfig(
                    placeholder: 'Start writing your note here...',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawMode() {
    return Column(
      children: [
        Expanded(
          child: DrawingCanvas(
            strokes: _strokes,
            onStrokesChanged: (updated) => setState(() => _strokes = updated),
            color: _drawColor,
            strokeWidth: _strokeWidth,
            tool: _tool,
          ),
        ),
        DrawToolbar(
          tool: _tool,
          onToolChanged: (t) => setState(() => _tool = t),
          color: _drawColor,
          onColorChanged: (c) => setState(() => _drawColor = c),
          strokeWidth: _strokeWidth,
          onWidthChanged: (w) => setState(() => _strokeWidth = w),
          onUndo: _undoStroke,
          onClear: _clearCanvas,
        ),
      ],
    );
  }
}