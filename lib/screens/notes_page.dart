import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/note.dart';
import 'note_editor_page.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  List<Note> _notes = [];

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

  void _deleteNote(Note note) {
    setState(() => _notes.removeWhere((n) => n.id == note.id));
    _saveNotes();
  }

  // Shared confirmation used by both the trailing delete icon and the
  // swipe-to-delete gesture, so a note never disappears without asking.
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

  String _formatDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notes')),
      body: _notes.isEmpty
          ? const Center(child: Text('No notes yet — tap + to create one'))
          : ListView.builder(
              itemCount: _notes.length,
              itemBuilder: (context, index) {
                final note = _notes[index];
                return Dismissible(
                  key: ValueKey(note.id),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (_) => _confirmDelete(note),
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => _deleteNote(note),
                  child: ListTile(
                    leading: Icon(
                        note.strokes.isNotEmpty ? Icons.brush : Icons.notes),
                    title: Text(
                        note.title.isEmpty ? 'Untitled note' : note.title),
                    subtitle: Text(_formatDate(note.updatedAt)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Delete note',
                      onPressed: () async {
                        if (await _confirmDelete(note)) _deleteNote(note);
                      },
                    ),
                    onTap: () => _openNote(note),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openNote(),
        child: const Icon(Icons.add),
      ),
    );
  }
}