import 'package:flutter/material.dart';

import 'flashcards_page.dart';
import 'notes_page.dart';
import 'pomodoro_page.dart';
import 'stopwatch_page.dart';
import 'todo_page.dart';

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
    ];

    // Theme.of(context).textTheme's default color already flips between
    // near-black and near-white with the theme — reading it here (instead
    // of hardcoding a grey) is what makes this subtitle legible in both.
    final subtitleColor =
        Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Hello, Student 👋',
                            style: TextStyle(
                                fontSize: 28, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'What would you like to do today?',
                            style:
                                TextStyle(fontSize: 16, color: subtitleColor),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onToggleTheme,
                      tooltip: isDarkMode
                          ? 'Switch to light mode'
                          : 'Switch to dark mode',
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
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 1,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _FeatureCard(feature: features[i]),
                  childCount: features.length,
                ),
              ),
            ),
          ],
        ),
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
  const _FeatureCard({required this.feature});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // A 0.08 tint reads fine on white but nearly disappears on black —
    // bump it up in dark mode so the cards stay visible.
    final cardTint = feature.color.withValues(alpha: isDark ? 0.22 : 0.08);
    final subtitleColor =
        Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6);

    return Material(
      color: cardTint,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: feature.builder)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: feature.color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(feature.icon, color: Colors.white, size: 26),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(feature.title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(feature.subtitle,
                      style: TextStyle(fontSize: 12, color: subtitleColor)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}