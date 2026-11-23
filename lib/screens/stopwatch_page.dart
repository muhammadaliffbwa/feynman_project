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

  static const List<String> _checkpointPresets = [
    'Finished section',
    'Solved problem set',
    'Reviewed notes',
    'Quick recap',
  ];

  @override
  void initState() {
    super.initState();

    if (_controller.hasActiveSession) {
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

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool get _hasCompletedSessionToday {
    final now = DateTime.now();
    return _history.any((s) => _isSameDay(s.endedAt.toLocal(), now));
  }

  int _calculateStreak() {
    if (_history.isEmpty) return 0;

    final studyDays = <DateTime>{};
    for (final session in _history) {
      final local = session.endedAt.toLocal();
      studyDays.add(DateTime(local.year, local.month, local.day));
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);

    DateTime cursor;
    if (studyDays.contains(today)) {
      cursor = today;
    } else if (studyDays.contains(yesterday)) {
      cursor = yesterday;
    } else {
      return 0;
    }

    int streak = 0;
    while (studyDays.contains(cursor)) {
      streak++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    return streak;
  }

  List<_SubjectFocusSlice> _todaySubjectBreakdown() {
    final now = DateTime.now();
    final Map<String, Duration> durationsByKey = {};
    final Map<String, String> labelsByKey = {};
    final Map<String, Color> colorsByKey = {};

    for (final session in _history) {
      if (!_isSameDay(session.endedAt.toLocal(), now)) continue;
      final displayLabel = session.subject.trim();
      final key = displayLabel.toLowerCase();

      durationsByKey[key] = (durationsByKey[key] ?? Duration.zero) + session.duration;
      labelsByKey.putIfAbsent(key, () => displayLabel);
      if (session.colorValue != null) {
        colorsByKey.putIfAbsent(key, () => Color(session.colorValue!));
      }
    }

    // Include live active session time so the header ticks in real time
    if (_controller.hasActiveSession &&
        _controller.stopwatch.elapsed.inSeconds > 0 &&
        _controller.currentSubject.trim().isNotEmpty) {
      final activeLabel = _controller.currentSubject.trim();
      final key = activeLabel.toLowerCase();
      durationsByKey[key] =
          (durationsByKey[key] ?? Duration.zero) + _controller.stopwatch.elapsed;
      labelsByKey[key] = activeLabel;
      colorsByKey[key] = _controller.barColor;
    }

    final palette = ColorSwatchPicker.options;
    int fallbackIndex = 0;
    final slices = <_SubjectFocusSlice>[];

    for (final entry in durationsByKey.entries) {
      final color = colorsByKey[entry.key] ??
          palette[fallbackIndex++ % palette.length];
      slices.add(
        _SubjectFocusSlice(
          subject: labelsByKey[entry.key] ?? entry.key,
          duration: entry.value,
          color: color,
        ),
      );
    }

    slices.sort((a, b) => b.duration.compareTo(a.duration));
    return slices;
  }

  String _formatCompactDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);

    if (hours > 0) {
      return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
    }
    if (minutes > 0) {
      return '${minutes}m';
    }
    if (seconds > 0) {
      return '${seconds}s';
    }
    return '0m';
  }

  Widget _buildFocusHeaderCard() {
    final colorScheme = Theme.of(context).colorScheme;
    final streak = _calculateStreak();
    final completedToday = _hasCompletedSessionToday;
    final slices = _todaySubjectBreakdown();
    final todayTotal = slices.fold<Duration>(
      Duration.zero,
      (sum, item) => sum + item.duration,
    );

    final bool hasStreak = streak > 0;
    final Color streakAccent = completedToday
        ? Colors.deepOrange
        : (hasStreak ? Colors.amber.shade800 : colorScheme.onSurfaceVariant);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          "TODAY'S FOCUS",
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (_controller.isRunning) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: _controller.barColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatCompactDuration(todayTotal),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: hasStreak
                      ? streakAccent.withValues(alpha: 0.14)
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: hasStreak
                        ? streakAccent.withValues(alpha: 0.45)
                        : colorScheme.outlineVariant,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasStreak
                          ? Icons.local_fire_department_rounded
                          : Icons.local_fire_department_outlined,
                      size: 18,
                      color: streakAccent,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$streak-day streak',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: streakAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (slices.isEmpty)
            Text(
              'Start a session below to log today\'s focus and build your streak.',
              style: TextStyle(
                fontSize: 12.5,
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 9,
                child: Row(
                  children: [
                    for (int i = 0; i < slices.length; i++) ...[
                      if (i > 0) const SizedBox(width: 2),
                      Expanded(
                        flex: slices[i].duration.inSeconds.clamp(1, 86400),
                        child: Container(color: slices[i].color),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: slices
                  .map(
                    (slice) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: slice.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${slice.subject} (${_formatCompactDuration(slice.duration)})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  void _handleStart() {
    if (_subjectController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a subject or topic first')),
      );
      return;
    }
    _controller.start(_subjectController.text);
  }

  void _handleStop() {
    final session = _controller.stop();
    if (session != null) {
      setState(() {
        _history.insert(0, session);
      });
      _saveHistory();
      _subjectController.clear();
      _showSummary(session);
    }
  }

  void _showAddCheckpointDialog() {
    final capturedElapsed = _controller.stopwatch.elapsed;
    final previousElapsed = _controller.checkpoints.isEmpty
        ? Duration.zero
        : _controller.checkpoints.last.elapsed;
    final previewSplit = capturedElapsed - previousElapsed;
    final noteController = TextEditingController();

    void submit(BuildContext dialogContext) {
      _controller.addCheckpoint(
        label: noteController.text,
        atElapsed: capturedElapsed,
      );
      Navigator.of(dialogContext).pop();
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.flag_rounded, size: 22),
            SizedBox(width: 8),
            Text('Log Checkpoint'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Timestamp: ${_controller.formatDuration(capturedElapsed)} (+${_controller.formatDuration(previewSplit.isNegative ? Duration.zero : previewSplit)})',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(dialogContext).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => submit(dialogContext),
                decoration: InputDecoration(
                  labelText: 'What did you finish?',
                  hintText:
                      'Checkpoint #${_controller.checkpoints.length + 1} (optional)',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _checkpointPresets
                    .map(
                      (preset) => ActionChip(
                        label: Text(
                          preset,
                          style: const TextStyle(fontSize: 12),
                        ),
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          noteController.text = preset;
                          noteController.selection = TextSelection.fromPosition(
                            TextPosition(offset: preset.length),
                          );
                        },
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => submit(dialogContext),
            child: const Text('Save Lap'),
          ),
        ],
      ),
    );
  }

  void _showSummary(StudySession session) {
    final distractionSummary = session.distractions == 0
        ? 'Zero distractions — locked in! 🎯'
        : 'Paused ${session.distractions} ${session.distractions == 1 ? 'time' : 'times'}';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Session complete! 🎉'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.subject,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                  'Studied for ${_controller.formatDuration(session.duration)}'),
              const SizedBox(height: 4),
              Text(
                distractionSummary,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (session.checkpoints.isNotEmpty) ...[
                const Divider(height: 20),
                Text(
                  'Checkpoints (${session.checkpoints.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 8),
                ...session.checkpoints.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final cp = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '#$idx ',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            cp.label,
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_controller.formatDuration(cp.elapsed)} (+${_controller.formatDuration(cp.splitDuration)})',
                          style: TextStyle(
                            fontSize: 11.5,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
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

  void _showSessionDetails(StudySession session) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      session.subject,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    _controller.formatDuration(session.duration),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${_formatDate(session.endedAt)} • ${session.distractions} ${session.distractions == 1 ? 'distraction' : 'distractions'}',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Divider(height: 24),
              if (session.checkpoints.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No checkpoints logged during this session.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: session.checkpoints.length,
                    separatorBuilder: (_, __) => const Divider(height: 12),
                    itemBuilder: (context, index) {
                      final cp = session.checkpoints[index];
                      return Row(
                        children: [
                          CircleAvatar(
                            radius: 13,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .primaryContainer,
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              cp.label,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '+${_controller.formatDuration(cp.splitDuration)}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '@ ${_controller.formatDuration(cp.elapsed)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';

  // --- Focus Techniques Guide (banner opens this bottom sheet) ---
  void _showFocusTechniquesGuide() {
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
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
                      Text('⏱️', style: TextStyle(fontSize: 26)),
                      SizedBox(width: 8),
                      Text(
                        'Efficient Study-Tracking Tips',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Track your study sessions with these simple techniques!',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Flow-State Tracking Card
                  _buildTechniqueCard(
                    emoji: '🌊',
                    title: '1. Flow-State Tracking',
                    subtitle: 'Active Focus',
                    accentColor: Colors.cyan.shade100,
                    borderColor: Colors.cyan.shade400,
                    description:
                        'Counting up removes the pressure of a ticking deadline and lets you ride deep concentration for as long as it naturally lasts. 🧘',
                    steps: const [
                      '▶️ Step 1: Start on Engagement – Hit start the exact moment you begin reading or solving problems, not while setting up your desk or picking a playlist.',
                      '⏸️ Step 2: Pause for Every Distraction – Immediately pause the timer whenever you check your phone, grab a snack, or daydream so your total reflects true focus.',
                      '🛑 Step 3: Stop at Mental Fatigue – End the session when your comprehension drops or you hit a natural stopping point, logging the total minutes completed.',
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Earned Recovery Card
                  _buildTechniqueCard(
                    emoji: '🔋',
                    title: '2. Earned Recovery',
                    subtitle: 'Rest & Calibration',
                    accentColor: Colors.green.shade100,
                    borderColor: Colors.green.shade400,
                    description:
                        'While tracking builds focus endurance, structured breaks prevent burnout and turn raw time data into smarter study habits. 🌱',
                    steps: const [
                      '⚖️ Step 1: Calculate Your Break Ratio – Reward yourself with a rest period proportional to your effort, such as taking one minute of rest for every five minutes of focused study.',
                      '🌿 Step 2: Step Away Completely – Spend your break away from screens and study materials to let your brain consolidate information and reset.',
                      '📈 Step 3: Audit Your Focus Trends – Compare your daily totals over a week to identify your peak concentration hours and gradually stretch your average session length.',
                    ],
                  ),

                  const SizedBox(height: 20),
                  Center(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.rocket_launch, size: 18),
                      label: const Text("Got it! Let's Focus"),
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
      padding: const EdgeInsets.only(bottom: 20.0),
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
              color: Colors.amber.shade200.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _showFocusTechniquesGuide,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
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
                          'Focus Smarter!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'Learn Flow-State Tracking & Earned Recovery',
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

  Widget _buildSessionStatusRow({
    required bool isPaused,
    required int distractionCount,
    required Color barColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasDistractions = distractionCount > 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isPaused
                ? Colors.amber.withValues(alpha: 0.16)
                : barColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isPaused
                  ? Colors.amber.shade600
                  : barColor.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPaused ? Icons.pause_circle_filled : Icons.bolt_rounded,
                size: 16,
                color: isPaused ? Colors.amber.shade800 : barColor,
              ),
              const SizedBox(width: 6),
              Text(
                isPaused ? 'Paused' : 'Focusing',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isPaused ? Colors.amber.shade900 : barColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: hasDistractions
                ? Colors.orange.withValues(alpha: 0.14)
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: hasDistractions
                  ? Colors.orange.shade400
                  : colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasDistractions
                    ? Icons.notifications_paused_outlined
                    : Icons.shield_outlined,
                size: 16,
                color: hasDistractions
                    ? Colors.orange.shade800
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                'Distractions: $distractionCount',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: hasDistractions
                      ? Colors.orange.shade900
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCheckpointsCard(Color barColor) {
    final checkpoints = _controller.checkpoints;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_rounded, size: 18, color: barColor),
              const SizedBox(width: 6),
              const Text(
                'Session Checkpoints',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: barColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${checkpoints.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: barColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...checkpoints.asMap().entries.map((entry) {
            final index = entry.key;
            final cp = entry.value;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: barColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: barColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      cp.label,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '+${_controller.formatDuration(cp.splitDuration)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: barColor,
                        ),
                      ),
                      Text(
                        '@ ${_controller.formatDuration(cp.elapsed)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    tooltip: 'Remove checkpoint',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _controller.removeCheckpoint(index),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRunning = _controller.isRunning;
    final isPaused = _controller.isPaused;
    final isActive = _controller.hasActiveSession;
    final distractionCount = _controller.distractionCount;
    final barColor = _controller.barColor;

    final elapsedMs = _controller.stopwatch.elapsed.inMilliseconds;
    final double progressValue = isActive ? (elapsedMs % 60000) / 60000.0 : 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Study Stopwatch')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildFocusHeaderCard(),
            _buildStudyBanner(),
            TextField(
              controller: _subjectController,
              enabled: !isActive,
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
                          onPressed: isActive
                              ? null
                              : () => setState(
                                  () => _subjectController.text = s),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 28),
            if (isActive) ...[
              _buildSessionStatusRow(
                isPaused: isPaused,
                distractionCount: distractionCount,
                barColor: barColor,
              ),
              const SizedBox(height: 14),
            ],
            // Striped Animated Progress Bar
            AnimatedStripedProgressBar(
              value: progressValue,
              baseColor: isPaused ? barColor.withValues(alpha: 0.65) : barColor,
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
                  color: isPaused ? barColor.withValues(alpha: 0.75) : barColor,
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (!isActive) ...[
              ColorSwatchPicker(
                selectedColor: barColor,
                onColorSelected: (color) => _controller.setBarColor(color),
              ),
              const SizedBox(height: 20),
            ],
            if (!isActive)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: barColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _handleStart,
                  child: const Text('Start Studying'),
                ),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: isPaused
                        ? FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: barColor,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onPressed: _controller.resume,
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Resume'),
                          )
                        : FilledButton.tonalIcon(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onPressed: _controller.pause,
                            icon: const Icon(Icons.pause_rounded),
                            label: const Text('Pause'),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.error,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _handleStop,
                      icon: const Icon(Icons.stop_rounded),
                      label: const Text('Stop'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: barColor,
                    side: BorderSide(color: barColor.withValues(alpha: 0.6)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onPressed: _showAddCheckpointDialog,
                  icon: const Icon(Icons.flag_outlined, size: 20),
                  label: const Text('Log Checkpoint / Lap'),
                ),
              ),
              if (_controller.checkpoints.isNotEmpty)
                _buildCheckpointsCard(barColor),
            ],
            if (_history.isNotEmpty) ...[
              const SizedBox(height: 36),
              const Text(
                'Recent sessions',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ..._history.take(10).map((s) {
                final distractionText = s.distractions == 0
                    ? '0 distractions'
                    : '${s.distractions} ${s.distractions == 1 ? 'distraction' : 'distractions'}';
                final checkpointText = s.checkpoints.isEmpty
                    ? ''
                    : ' • ${s.checkpoints.length} ${s.checkpoints.length == 1 ? 'checkpoint' : 'checkpoints'}';

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () => _showSessionDetails(s),
                  leading: Icon(
                    Icons.check_circle_outline,
                    color: s.colorValue != null ? Color(s.colorValue!) : null,
                  ),
                  title: Text(s.subject),
                  subtitle: Text(
                    '${_formatDate(s.endedAt)} • $distractionText$checkpointText',
                  ),
                  trailing: Text(
                    _controller.formatDuration(s.duration),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
      bottomNavigationBar: const MiniAudioPlayer(),
    );
  }
}

class _SubjectFocusSlice {
  final String subject;
  final Duration duration;
  final Color color;

  _SubjectFocusSlice({
    required this.subject,
    required this.duration,
    required this.color,
  });
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
      ..color = Colors.white.withValues(alpha: 0.22)
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