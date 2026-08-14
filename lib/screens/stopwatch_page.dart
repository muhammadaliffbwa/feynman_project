import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../controllers/stopwatch_controller.dart';
import '../models/study_session.dart';
import '../widgets/color_swatch_picker.dart';
import '../widgets/mini_audio_player.dart';

class StopwatchPage extends StatefulWidget {
  const StopwatchPage({super.key});

  @override
  State<StopwatchPage> createState() => _StopwatchPageState();
}

class _StopwatchPageState extends State<StopwatchPage> {
  final TextEditingController _subjectController = TextEditingController();
  final StopwatchController _controller = StopwatchController.instance;
  List<StudySession> _history = [];

  @override
  void initState() {
    super.initState();

    if (_controller.isRunning) {
      _subjectController.text = _controller.currentSubject;
    }

    _controller.addListener(_onControllerUpdate);
    _loadHistory();
  }

  void _onControllerUpdate() {
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
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

  void _handleToggle() {
    if (_controller.isRunning) {
      final session = _controller.stop();
      if (session != null) {
        setState(() {
          _history.insert(0, session);
        });
        _saveHistory();
        _subjectController.clear();
        _showSummary(session);
      }
    } else {
      if (_subjectController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add a subject or topic first')),
        );
        return;
      }
      _controller.start(_subjectController.text);
    }
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
            Text('Studied for ${_controller.formatDuration(session.duration)}'),
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

  String _formatDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';

  @override
  Widget build(BuildContext context) {
    final isRunning = _controller.isRunning;
    final barColor = _controller.barColor;

    // Calculate progress directly from elapsed millisecond state
    final elapsedMs = _controller.stopwatch.elapsed.inMilliseconds;
    final double progressValue = isRunning ? (elapsedMs % 60000) / 60000.0 : 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Study Stopwatch')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(
              controller: _subjectController,
              enabled: !isRunning,
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
                          onPressed: isRunning
                              ? null
                              : () => setState(
                                  () => _subjectController.text = s),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 32),
            // Striped Animated Progress Bar
            AnimatedStripedProgressBar(
              value: progressValue,
              baseColor: barColor,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              totalElapsedMs: elapsedMs,
              isRunning: isRunning,
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                _controller.formatDuration(_controller.stopwatch.elapsed),
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: barColor,
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (!isRunning) ...[
              ColorSwatchPicker(
                selectedColor: barColor,
                onColorSelected: (color) => _controller.setBarColor(color),
              ),
              const SizedBox(height: 20),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: barColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _handleToggle,
                child: Text(isRunning ? 'Stop' : 'Start Studying'),
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
                        _controller.formatDuration(s.duration),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: const MiniAudioPlayer(),
    );
  }
}

class AnimatedStripedProgressBar extends StatelessWidget {
  final double value;
  final Color baseColor;
  final Color backgroundColor;
  final int totalElapsedMs;
  final bool isRunning;

  const AnimatedStripedProgressBar({
    super.key,
    required this.value,
    required this.baseColor,
    required this.backgroundColor,
    required this.totalElapsedMs,
    required this.isRunning,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: CustomPaint(
          painter: _StripedProgressBarPainter(
            value: value.clamp(0.0, 1.0),
            baseColor: baseColor,
            stripeOffset: isRunning ? (totalElapsedMs / 30.0) % 30.0 : 0.0,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _StripedProgressBarPainter extends CustomPainter {
  final double value;
  final Color baseColor;
  final double stripeOffset;

  _StripedProgressBarPainter({
    required this.value,
    required this.baseColor,
    required this.stripeOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (value <= 0) return;

    final double fillWidth = size.width * value;
    final Rect fillRect = Rect.fromLTWH(0, 0, fillWidth, size.height);

    canvas.save();
    canvas.clipRect(fillRect);

    final Paint basePaint = Paint()..color = baseColor;
    canvas.drawRect(fillRect, basePaint);

    final Paint stripePaint = Paint()
      ..color = Colors.white.withOpacity(0.22)
      ..style = PaintingStyle.fill;

    const double stripeWidth = 15.0;
    const double stripeSpacing = 30.0;

    final Path path = Path();
    final double startX = -size.height - stripeSpacing + stripeOffset;
    final double endX = fillWidth + size.height + stripeSpacing;

    for (double x = startX; x < endX; x += stripeSpacing) {
      path.reset();
      path.moveTo(x, size.height);
      path.lineTo(x + stripeWidth, size.height);
      path.lineTo(x + stripeWidth + size.height, 0);
      path.lineTo(x + size.height, 0);
      path.close();

      canvas.drawPath(path, stripePaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StripedProgressBarPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.stripeOffset != stripeOffset ||
        oldDelegate.baseColor != baseColor;
  }
}