import 'package:flutter/material.dart';

import 'flashcards_page.dart';
import 'focus_audio_page.dart'; // 6th Feature Page
import 'notes_page.dart';
import 'pomodoro_page.dart';
import 'stopwatch_page.dart';
import 'todo_page.dart';
import '../widgets/mini_audio_player.dart';
import '../widgets/mini_stopwatch_bar.dart'; // Import mini stopwatch widget

class HomePage extends StatelessWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const HomePage({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  Widget build(BuildContext context) {
    final features = <_Feature>[
      _Feature(
        title: 'Flashcards & Diagrams',
        subtitle: 'Review concepts visually',
        icon: Icons.style_outlined,
        color: const Color(0xFF0A6C3E),
        builder: (_) => const FlashcardsPage(),
      ),
      _Feature(
        title: 'Notes',
        subtitle: 'Capture your thoughts',
        icon: Icons.edit_note_outlined,
        color: const Color(0xFF1E88E5),
        builder: (_) => const NotesPage(),
      ),
      _Feature(
        title: 'To-Do List',
        subtitle: 'Track your tasks',
        icon: Icons.checklist_rounded,
        color: const Color(0xFFE53935),
        builder: (_) => const TodoPage(),
      ),
      _Feature(
        title: 'Pomodoro Timer',
        subtitle: 'Focused work sessions',
        icon: Icons.timer_outlined,
        color: const Color(0xFFFB8C00),
        builder: (_) => const PomodoroPage(),
      ),
      _Feature(
        title: 'Study Stopwatch',
        subtitle: 'Measure your study time',
        icon: Icons.hourglass_bottom,
        color: const Color(0xFF8E24AA),
        builder: (_) => const StopwatchPage(),
      ),
      _Feature(
        title: 'Focus Audio',
        subtitle: 'Auditory masking & Lo-Fi',
        icon: Icons.headphones_rounded,
        color: const Color(0xFF6C5CE7),
        builder: (_) => const FocusAudioPage(),
      ),
    ];

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
            const double headerEstimatedHeight = 72.0;

            // Calculate precise card dimensions to guarantee zero-scroll fit
            final double gridWidth = availableWidth - (horizontalPadding * 2);
            final double gridHeight = availableHeight -
                headerEstimatedHeight -
                (verticalPadding * 2);

            final double colWidth =
                (gridWidth - ((crossAxisCount - 1) * spacing)) / crossAxisCount;
            final double rowHeight =
                (gridHeight - ((rowCount - 1) * spacing)) / rowCount;

            // Protect against potential division by zero or negative space
            final double calculatedAspectRatio = (colWidth > 0 && rowHeight > 0)
                ? (colWidth / rowHeight)
                : 1.2;

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
                                'What would you like to focus on today?',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: subtitleColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Sun Toggle in White Background Pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                : Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: isDarkMode
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
                            onPressed: onToggleTheme,
                            tooltip: isDarkMode
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
                                  RotationTransition(turns: anim, child: child),
                              child: Icon(
                                isDarkMode
                                    ? Icons.dark_mode_rounded
                                    : Icons.light_mode_rounded,
                                key: ValueKey(isDarkMode),
                                color: isDarkMode
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

                  // Fixed Grid fitting entire viewport
                  Expanded(
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(), // Ensures single-page lock
                      itemCount: features.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: spacing,
                        crossAxisSpacing: spacing,
                        childAspectRatio: calculatedAspectRatio,
                      ),
                      itemBuilder: (context, i) => _FeatureCard(
                        feature: features[i],
                        isCompact: !isDesktop,
                      ),
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

class _Feature {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final WidgetBuilder builder;

  _Feature({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.builder,
  });
}

class _FeatureCard extends StatelessWidget {
  final _Feature feature;
  final bool isCompact;

  const _FeatureCard({
    required this.feature,
    required this.isCompact,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardTint = feature.color.withValues(alpha: isDark ? 0.22 : 0.08);
    final subtitleColor = Theme.of(context)
        .textTheme
        .bodySmall
        ?.color
        ?.withValues(alpha: 0.65);

    return Material(
      color: cardTint,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: feature.builder)),
        child: Padding(
          padding: EdgeInsets.all(isCompact ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Icon Badge
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
                      color: subtitleColor,
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
    );
  }
}