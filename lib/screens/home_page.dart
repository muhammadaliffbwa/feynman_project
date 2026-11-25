// lib/screens/home_page.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'flashcards_page.dart';
import 'focus_audio_page.dart';
import 'notes_page.dart';
import 'pomodoro_page.dart';
import 'stopwatch_page.dart';
import 'todo_page.dart';
import '../services/focus_stats_service.dart';
import '../services/music_player_service.dart';
import '../widgets/mini_audio_player.dart';
import '../widgets/mini_stopwatch_bar.dart';

class HomePage extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  // Optional live-status hooks for your other module controllers/storage
  final Listenable? statusListenable;
  final String? Function()? flashcardsStatusBuilder;
  final String? Function()? notesStatusBuilder;
  final String? Function()? todoStatusBuilder;
  final String? Function()? pomodoroStatusBuilder;
  final String? Function()? stopwatchStatusBuilder;

  const HomePage({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
    this.statusListenable,
    this.flashcardsStatusBuilder,
    this.notesStatusBuilder,
    this.todoStatusBuilder,
    this.pomodoroStatusBuilder,
    this.stopwatchStatusBuilder,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  static const String _orderStorageKey = 'home_module_card_order';
  static const List<String> _defaultOrder = [
    'flashcards',
    'notes',
    'todo',
    'pomodoro',
    'stopwatch',
    'focus_audio',
  ];

  final MusicPlayerService _audioService = MusicPlayerService();
  final FocusStatsService _statsService = FocusStatsService();

  List<String> _cardOrder = List<String>.from(_defaultOrder);
  String? _draggingId;

  bool get _isCustomOrder => !listEquals(_cardOrder, _defaultOrder);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCardOrder();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
    }
  }

  Future<void> _loadCardOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_orderStorageKey);
      if (saved == null || saved.isEmpty || !mounted) return;

      final reconciled = saved.where(_defaultOrder.contains).toList();
      for (final id in _defaultOrder) {
        if (!reconciled.contains(id)) {
          reconciled.add(id);
        }
      }

      setState(() {
        _cardOrder = reconciled;
      });
    } catch (e) {
      debugPrint('Error loading home card order: $e');
    }
  }

  Future<void> _saveCardOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_orderStorageKey, _cardOrder);
    } catch (e) {
      debugPrint('Error saving home card order: $e');
    }
  }

  void _reorderCards(String draggedId, String targetId) {
    if (draggedId == targetId) return;
    final fromIndex = _cardOrder.indexOf(draggedId);
    final toIndex = _cardOrder.indexOf(targetId);
    if (fromIndex == -1 || toIndex == -1) return;

    setState(() {
      final moved = _cardOrder.removeAt(fromIndex);
      _cardOrder.insert(toIndex, moved);
    });
    HapticFeedback.selectionClick();
    _saveCardOrder();
  }

  Future<void> _resetCardOrder() async {
    setState(() {
      _cardOrder = List<String>.from(_defaultOrder);
    });
    HapticFeedback.lightImpact();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_orderStorageKey);
    } catch (e) {
      debugPrint('Error resetting home card order: $e');
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Home layout reset to default order'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openModule(WidgetBuilder builder) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: builder),
    );
    if (mounted) {
      setState(() {});
    }
  }

  String _buildAudioSubtitle() {
    final url = _audioService.currentUrl;
    if (url != null) {
      final trackName = _audioService.getDisplayName(url);
      return _audioService.isPlaying
          ? 'Playing: $trackName'
          : 'Paused: $trackName';
    }

    final playlistCount = _audioService.playlists.length;
    if (playlistCount > 0) {
      return playlistCount == 1
          ? '1 saved playlist'
          : '$playlistCount saved playlists';
    }

    return 'Auditory masking & Lo-Fi';
  }

  String? _defaultPomodoroSubtitle() {
    if (_statsService.todayPomodoroSeconds <= 0) return null;
    return '${_statsService.formatFocusMinutes(_statsService.todayPomodoroDuration)} logged today';
  }

  String? _defaultStopwatchSubtitle() {
    if (_statsService.todayStopwatchSeconds <= 0) return null;
    return '${_statsService.formatFocusMinutes(_statsService.todayStopwatchDuration)} logged today';
  }

  void _showTodayFocusBreakdown() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return ListenableBuilder(
          listenable: _statsService,
          builder: (context, _) {
            final colorScheme = Theme.of(context).colorScheme;
            final totalLabel = _statsService
                .formatFocusMinutes(_statsService.todayTotalDuration);
            final pomodoroLabel = _statsService
                .formatFocusMinutes(_statsService.todayPomodoroDuration);
            final stopwatchLabel = _statsService
                .formatFocusMinutes(_statsService.todayStopwatchDuration);
            final streak = _statsService.currentStreak;

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Today's Focus Summary",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.local_fire_department_rounded,
                              size: 16,
                              color: Colors.orange.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              streak == 1
                                  ? '1 day streak'
                                  : '$streak days streak',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _BreakdownRow(
                    icon: Icons.bolt_rounded,
                    color: const Color(0xFF6C5CE7),
                    label: 'Combined Total Today',
                    value: totalLabel,
                    isBold: true,
                  ),
                  const Divider(height: 20),
                  _BreakdownRow(
                    icon: Icons.timer_outlined,
                    color: const Color(0xFFFB8C00),
                    label: 'Pomodoro Sessions',
                    value: pomodoroLabel,
                  ),
                  const SizedBox(height: 12),
                  _BreakdownRow(
                    icon: Icons.hourglass_bottom,
                    color: const Color(0xFF8E24AA),
                    label: 'Study Stopwatch',
                    value: stopwatchLabel,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDailyFocusBar(BuildContext context, {required bool isCompact}) {
    final isDark = widget.isDarkMode;
    final colorScheme = Theme.of(context).colorScheme;
    final totalLabel =
        _statsService.formatFocusMinutes(_statsService.todayTotalDuration);
    final pomodoroLabel =
        _statsService.formatFocusMinutes(_statsService.todayPomodoroDuration);
    final stopwatchLabel =
        _statsService.formatFocusMinutes(_statsService.todayStopwatchDuration);
    final streak = _statsService.currentStreak;
    final hasStreak = streak > 0;

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.07),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _showTodayFocusBreakdown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C5CE7).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.schedule_rounded,
                    size: 18,
                    color: Color(0xFF6C5CE7),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          "Today's Focus: ",
                          style: TextStyle(
                            fontSize: isCompact ? 12 : 13,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        totalLabel,
                        style: TextStyle(
                          fontSize: isCompact ? 13.5 : 14.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (!isCompact) ...[
                        const SizedBox(width: 8),
                        Text(
                          '($pomodoroLabel Pomodoro · $stopwatchLabel Stopwatch)',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Daily Study Streak Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: hasStreak
                        ? Colors.orange.withValues(alpha: isDark ? 0.22 : 0.12)
                        : colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: hasStreak
                          ? Colors.orange.withValues(alpha: 0.4)
                          : colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_fire_department_rounded,
                        size: 16,
                        color: hasStreak
                            ? Colors.orange.shade600
                            : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${streak}d streak',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: hasStreak
                              ? (isDark
                                  ? Colors.orange.shade300
                                  : Colors.orange.shade800)
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Listenable combinedListenable = Listenable.merge([
      _audioService,
      _statsService,
      if (widget.statusListenable != null) widget.statusListenable!,
    ]);

    return ListenableBuilder(
      listenable: combinedListenable,
      builder: (context, _) {
        final String? flashcardsLive =
            widget.flashcardsStatusBuilder?.call()?.trim();
        final String? notesLive = widget.notesStatusBuilder?.call()?.trim();
        final String? todoLive = widget.todoStatusBuilder?.call()?.trim();
        final String? pomodoroLive =
            (widget.pomodoroStatusBuilder?.call() ?? _defaultPomodoroSubtitle())
                ?.trim();
        final String? stopwatchLive = (widget.stopwatchStatusBuilder?.call() ??
                _defaultStopwatchSubtitle())
            ?.trim();

        final bool isAudioLive = _audioService.currentUrl != null;

        final Map<String, _Feature> featureMap = {
          'flashcards': _Feature(
            id: 'flashcards',
            title: 'Flashcards & Diagrams',
            subtitle: (flashcardsLive != null && flashcardsLive.isNotEmpty)
                ? flashcardsLive
                : 'Review concepts visually',
            isLive: flashcardsLive != null && flashcardsLive.isNotEmpty,
            icon: Icons.style_outlined,
            color: const Color(0xFF0A6C3E),
            builder: (_) => const FlashcardsPage(),
          ),
          'notes': _Feature(
            id: 'notes',
            title: 'Notes',
            subtitle: (notesLive != null && notesLive.isNotEmpty)
                ? notesLive
                : 'Capture your thoughts',
            isLive: notesLive != null && notesLive.isNotEmpty,
            icon: Icons.edit_note_outlined,
            color: const Color(0xFF1E88E5),
            builder: (_) => const NotesPage(),
          ),
          'todo': _Feature(
            id: 'todo',
            title: 'To-Do List',
            subtitle: (todoLive != null && todoLive.isNotEmpty)
                ? todoLive
                : 'Track your tasks',
            isLive: todoLive != null && todoLive.isNotEmpty,
            icon: Icons.checklist_rounded,
            color: const Color(0xFFE53935),
            builder: (_) => const TodoPage(),
          ),
          'pomodoro': _Feature(
            id: 'pomodoro',
            title: 'Pomodoro Timer',
            subtitle: (pomodoroLive != null && pomodoroLive.isNotEmpty)
                ? pomodoroLive
                : 'Focused work sessions',
            isLive: pomodoroLive != null && pomodoroLive.isNotEmpty,
            icon: Icons.timer_outlined,
            color: const Color(0xFFFB8C00),
            builder: (_) => const PomodoroPage(),
          ),
          'stopwatch': _Feature(
            id: 'stopwatch',
            title: 'Study Stopwatch',
            subtitle: (stopwatchLive != null && stopwatchLive.isNotEmpty)
                ? stopwatchLive
                : 'Measure your study time',
            isLive: stopwatchLive != null && stopwatchLive.isNotEmpty,
            icon: Icons.hourglass_bottom,
            color: const Color(0xFF8E24AA),
            builder: (_) => const StopwatchPage(),
          ),
          'focus_audio': _Feature(
            id: 'focus_audio',
            title: 'Focus Audio',
            subtitle: _buildAudioSubtitle(),
            isLive: isAudioLive,
            icon: Icons.headphones_rounded,
            color: const Color(0xFF6C5CE7),
            builder: (_) => const FocusAudioPage(),
          ),
        };

        final List<_Feature> features = _cardOrder
            .map((id) => featureMap[id])
            .whereType<_Feature>()
            .toList();

        final subtitleColor = Theme.of(context)
            .textTheme
            .bodyMedium
            ?.color
            ?.withValues(alpha: 0.65);

        return Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double availableWidth = constraints.maxWidth;
                final double availableHeight = constraints.maxHeight;

                // Layout breakpoints
                final bool isDesktop = availableWidth >= 900;
                final int crossAxisCount = isDesktop ? 3 : 2;
                final int rowCount = isDesktop ? 2 : 3;

                // Spacing parameters
                const double horizontalPadding = 20.0;
                const double verticalPadding = 16.0;
                const double spacing = 12.0;
                const double headerEstimatedHeight = 68.0;
                const double focusBarHeight = 52.0;
                const double focusBarSpacing = 12.0;

                // Calculate precise card dimensions to guarantee zero-scroll fit
                final double gridWidth =
                    availableWidth - (horizontalPadding * 2);
                final double gridHeight = availableHeight -
                    headerEstimatedHeight -
                    focusBarHeight -
                    focusBarSpacing -
                    (verticalPadding * 2);

                final double colWidth =
                    (gridWidth - ((crossAxisCount - 1) * spacing)) /
                        crossAxisCount;
                final double rowHeight =
                    (gridHeight - ((rowCount - 1) * spacing)) / rowCount;

                final double calculatedAspectRatio =
                    (colWidth > 0 && rowHeight > 0)
                        ? (colWidth / rowHeight)
                        : 1.2;

                final double safeTileWidth = colWidth > 0 ? colWidth : 160.0;
                final double safeTileHeight = rowHeight > 0 ? rowHeight : 110.0;

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: verticalPadding,
                  ),
                  child: Column(
                    children: [
                      // Header Row
                      SizedBox(
                        height: headerEstimatedHeight,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Hi, Student 👋',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _draggingId != null
                                        ? 'Drop onto any tile to swap positions'
                                        : 'What would you like to focus on today?',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _draggingId != null
                                          ? const Color(0xFF6C5CE7)
                                          : subtitleColor,
                                      fontWeight: _draggingId != null
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (_isCustomOrder) ...[
                              Container(
                                decoration: BoxDecoration(
                                  color: widget.isDarkMode
                                      ? Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest
                                      : Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: widget.isDarkMode
                                        ? Colors.white.withValues(alpha: 0.12)
                                        : Colors.black.withValues(alpha: 0.08),
                                  ),
                                ),
                                child: IconButton(
                                  onPressed: _resetCardOrder,
                                  tooltip: 'Reset card order',
                                  constraints: const BoxConstraints(
                                    minWidth: 40,
                                    minHeight: 40,
                                  ),
                                  padding: EdgeInsets.zero,
                                  icon: Icon(
                                    Icons.restart_alt_rounded,
                                    size: 20,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            // Theme Toggle in Pill
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: widget.isDarkMode
                                    ? Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: widget.isDarkMode
                                      ? Colors.white.withValues(alpha: 0.12)
                                      : Colors.black.withValues(alpha: 0.08),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                onPressed: widget.onToggleTheme,
                                tooltip: widget.isDarkMode
                                    ? 'Switch to light mode'
                                    : 'Switch to dark mode',
                                constraints: const BoxConstraints(
                                  minWidth: 40,
                                  minHeight: 40,
                                ),
                                padding: EdgeInsets.zero,
                                icon: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 250),
                                  transitionBuilder: (child, anim) =>
                                      RotationTransition(
                                    turns: anim,
                                    child: child,
                                  ),
                                  child: Icon(
                                    widget.isDarkMode
                                        ? Icons.dark_mode_rounded
                                        : Icons.light_mode_rounded,
                                    key: ValueKey(widget.isDarkMode),
                                    color: widget.isDarkMode
                                        ? Colors.indigo.shade200
                                        : Colors.amber.shade700,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Slim Daily Focus Time & Streak Bar
                      _buildDailyFocusBar(context, isCompact: !isDesktop),
                      const SizedBox(height: focusBarSpacing),

                      // Fixed Reorderable Grid fitting entire viewport
                      Expanded(
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: features.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            mainAxisSpacing: spacing,
                            crossAxisSpacing: spacing,
                            childAspectRatio: calculatedAspectRatio,
                          ),
                          itemBuilder: (context, i) {
                            final feature = features[i];
                            return DragTarget<String>(
                              onWillAcceptWithDetails: (details) =>
                                  details.data != feature.id,
                              onAcceptWithDetails: (details) =>
                                  _reorderCards(details.data, feature.id),
                              builder: (context, candidateData, _) {
                                final isTargeted = candidateData.isNotEmpty;
                                return LongPressDraggable<String>(
                                  data: feature.id,
                                  delay: const Duration(milliseconds: 220),
                                  onDragStarted: () {
                                    HapticFeedback.mediumImpact();
                                    setState(() => _draggingId = feature.id);
                                  },
                                  onDragEnd: (_) {
                                    if (mounted) {
                                      setState(() => _draggingId = null);
                                    }
                                  },
                                  onDraggableCanceled: (_, __) {
                                    if (mounted) {
                                      setState(() => _draggingId = null);
                                    }
                                  },
                                  feedback: Material(
                                    color: Colors.transparent,
                                    child: Transform.scale(
                                      scale: 1.04,
                                      child: SizedBox(
                                        width: safeTileWidth,
                                        height: safeTileHeight,
                                        child: _FeatureCard(
                                          feature: feature,
                                          isCompact: !isDesktop,
                                          isElevatedFeedback: true,
                                        ),
                                      ),
                                    ),
                                  ),
                                  childWhenDragging: Container(
                                    decoration: BoxDecoration(
                                      color:
                                          feature.color.withValues(alpha: 0.04),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: feature.color
                                            .withValues(alpha: 0.35),
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                  child: AnimatedScale(
                                    scale: isTargeted ? 0.96 : 1.0,
                                    duration: const Duration(milliseconds: 140),
                                    child: _FeatureCard(
                                      feature: feature,
                                      isCompact: !isDesktop,
                                      isDropTarget: isTargeted,
                                      showDragHint: _draggingId != null &&
                                          _draggingId != feature.id,
                                      onTap: () => _openModule(feature.builder),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
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
                onTap: () => _openModule((_) => const StopwatchPage()),
              ),
              const MiniAudioPlayer(),
            ],
          ),
        );
      },
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final bool isBold;

  const _BreakdownRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 14.5,
            fontWeight: FontWeight.w700,
            color: isBold ? color : null,
          ),
        ),
      ],
    );
  }
}

class _Feature {
  final String id;
  final String title;
  final String subtitle;
  final bool isLive;
  final IconData icon;
  final Color color;
  final WidgetBuilder builder;

  const _Feature({
    required this.id,
    required this.title,
    required this.subtitle,
    this.isLive = false,
    required this.icon,
    required this.color,
    required this.builder,
  });
}

class _FeatureCard extends StatelessWidget {
  final _Feature feature;
  final bool isCompact;
  final VoidCallback? onTap;
  final bool isDropTarget;
  final bool isElevatedFeedback;
  final bool showDragHint;

  const _FeatureCard({
    required this.feature,
    required this.isCompact,
    this.onTap,
    this.isDropTarget = false,
    this.isElevatedFeedback = false,
    this.showDragHint = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double baseAlpha = isDark ? 0.22 : 0.08;
    final cardTint = isElevatedFeedback
        ? Color.alphaBlend(
            feature.color.withValues(alpha: isDark ? 0.30 : 0.14),
            Theme.of(context).colorScheme.surface,
          )
        : feature.color.withValues(
            alpha: isDropTarget ? (baseAlpha + 0.08) : baseAlpha,
          );
    final defaultSubtitleColor = Theme.of(context)
        .textTheme
        .bodySmall
        ?.color
        ?.withValues(alpha: 0.65);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: isDropTarget
            ? Border.all(color: feature.color, width: 2)
            : null,
        boxShadow: isElevatedFeedback
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Material(
        color: cardTint,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(isCompact ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Row: Icon Badge + Live / Drag Indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(isCompact ? 8 : 10),
                      decoration: BoxDecoration(
                        color: feature.color,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: feature.color.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        feature.icon,
                        color: Colors.white,
                        size: isCompact ? 20 : 24,
                      ),
                    ),
                    if (showDragHint)
                      Icon(
                        Icons.drag_indicator_rounded,
                        size: 18,
                        color: feature.color.withValues(alpha: 0.7),
                      )
                    else if (feature.isLive)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 4, right: 2),
                        decoration: BoxDecoration(
                          color: feature.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),

                // Title & Subtitle Section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feature.title,
                      style: TextStyle(
                        fontSize: isCompact ? 14 : 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: isCompact ? 2 : 4),
                    Text(
                      feature.subtitle,
                      style: TextStyle(
                        fontSize: isCompact ? 11 : 12,
                        fontWeight: feature.isLive
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: feature.isLive
                            ? feature.color
                            : defaultSubtitleColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}