import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/study_session.dart';
import '../widgets/color_swatch_picker.dart';

class StopwatchPage extends StatefulWidget {
  const StopwatchPage({super.key});

  @override
  State<StopwatchPage> createState() => _StopwatchPageState();
}

class _StopwatchPageState extends State<StopwatchPage>
    with SingleTickerProviderStateMixin {
  // Drives the visual bar only — it loops every 60s regardless of how
  // long the session actually runs, so there's always motion to look at.
  late final AnimationController _progressController;

  // Tracks the real elapsed time. Dart's Stopwatch class is built for
  // exactly this — accurate start/stop/elapsed, independent of how
  // often the UI happens to redraw.
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _uiTimer; // just triggers periodic repaints of the time text

  final TextEditingController _subjectController = TextEditingController();
  bool _isRunning = false;
  Color _barColor = ColorSwatchPicker.options.first;
  List<StudySession> _history = [];

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    );
    _loadHistory();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _uiTimer?.cancel();
    _subjectController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('study_sessions');
    if (data != null) {
      final List decoded = jsonDecode(data);
      setState(() {
        _history = decoded.map((item) => StudySession.fromJson(item)).toList();
      });
    }
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(_history.map((s) => s.toJson()).toList());
    await prefs.setString('study_sessions', data);
  }

  // Unique subjects from past sessions, most recent first — powers the
  // quick-select chips.
  List<String> get _recentSubjects {
    final seen = <String>{};
    final result = <String>[];
    for (final session in _history) {
      if (seen.add(session.subject)) {
        result.add(session.subject);
        if (result.length >= 6) break;
      }
    }
    return result;
  }

  void _start() {
    if (_subjectController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a subject or topic first')),
      );
      return;
    }
    setState(() => _isRunning = true);
    _stopwatch.start();
    _progressController.repeat();
    _uiTimer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => setState(() {}),
    );
  }

  void _stop() {
    _stopwatch.stop();
    _progressController.stop();
    _uiTimer?.cancel();

    final session = StudySession(
      subject: _subjectController.text.trim(),
      duration: _stopwatch.elapsed,
      endedAt: DateTime.now(),
    );

    setState(() {
      _isRunning = false;
      _history.insert(0, session);
    });
    _saveHistory();

    _stopwatch.reset();
    _progressController.reset();
    _subjectController.clear();

    _showSummary(session);
  }

  void _showSummary(StudySession session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Session complete! 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              session.subject,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text('Studied for ${_formatDuration(session.duration)}'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Study Stopwatch')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(
              controller: _subjectController,
              enabled: !_isRunning,
              decoration: const InputDecoration(
                labelText: 'Subject / topic',
                border: OutlineInputBorder(),
              ),
            ),
            if (_recentSubjects.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _recentSubjects
                    .map((s) => ActionChip(
                          label: Text(s),
                          onPressed: _isRunning
                              ? null
                              : () => setState(() => _subjectController.text = s),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 32),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AnimatedBuilder(
                animation: _progressController,
                builder: (context, _) => LinearProgressIndicator(
                  value: _progressController.value,
                  minHeight: 28,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation(_barColor),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: AnimatedBuilder(
                animation: _progressController,
                builder: (context, _) => Text(
                  _formatDuration(_stopwatch.elapsed),
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: _barColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (!_isRunning) ...[
              ColorSwatchPicker(
                selectedColor: _barColor,
                onColorSelected: (color) => setState(() => _barColor = color),
              ),
              const SizedBox(height: 20),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _barColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _isRunning ? _stop : _start,
                child: Text(_isRunning ? 'Stop' : 'Start Studying'),
              ),
            ),
            if (_history.isNotEmpty) ...[
              const SizedBox(height: 36),
              const Text(
                'Recent sessions',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ..._history.take(10).map(
                    (s) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.check_circle_outline),
                      title: Text(s.subject),
                      subtitle: Text(_formatDate(s.endedAt)),
                      trailing: Text(
                        _formatDuration(s.duration),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}