// lib/screens/pomodoro_page.dart

import 'package:flutter/material.dart';

import '../services/noise_player.dart';
import '../services/pomodoro_service.dart';
import '../widgets/color_swatch_picker.dart';
import '../widgets/dial_timer.dart';
import '../widgets/mini_audio_player.dart';
import '../widgets/mini_stopwatch_bar.dart';
import 'stopwatch_page.dart';

class PomodoroPage extends StatefulWidget {
  const PomodoroPage({super.key});

  @override
  State<PomodoroPage> createState() => _PomodoroPageState();
}

class _PomodoroPageState extends State<PomodoroPage> {
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
                      Text('🍅', style: TextStyle(fontSize: 26)),
                      SizedBox(width: 8),
                      Text(
                        'Pomodoro Focus Tips',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Boost your daily focus with these timed techniques!',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 20),

                  // Time-Boxed Sprints Technique Card
                  _buildTechniqueCard(
                    emoji: '⚡',
                    title: '1. Time-Boxed Sprints',
                    subtitle: 'Focused Intensity',
                    accentColor: Colors.amber.shade100,
                    borderColor: Colors.amber.shade400,
                    description:
                        'Working against a fixed countdown creates healthy urgency and lowers the mental friction of getting started.',
                    steps: const [
                      '🎯 Step 1: Define a Single Target – Pick one specific task before starting the clock so you never waste focus time deciding what to do next.',
                      '⏱️ Step 2: Commit to 25 Minutes – Start the timer and work exclusively on that target until the alarm rings, ignoring all notifications and urges to multitask.',
                      '📝 Step 3: Capture Stray Distractions – Jot down sudden thoughts or unrelated tasks on a scratchpad to handle later rather than breaking your current sprint.',
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Structured Intervals Technique Card
                  _buildTechniqueCard(
                    emoji: '🔋',
                    title: '2. Structured Intervals',
                    subtitle: 'Recovery & Momentum',
                    accentColor: Colors.lightBlue.shade100,
                    borderColor: Colors.lightBlue.shade400,
                    description:
                        'While sprints drive intense concentration, scheduled breaks protect your cognitive stamina across multi-hour sessions.',
                    steps: const [
                      '🌿 Step 1: Take a 5-Minute Reset – Step away from your desk as soon as the timer chimes to stretch, hydrate, or rest your eyes without scrolling on your phone.',
                      '🏆 Step 2: Earn a Long Break – After completing four consecutive Pomodoros, take a full 15- to 30-minute break to recharge before starting a new cycle.',
                      '⚙️ Step 3: Adjust Sprint Lengths – Scale up to 50-minute sprints with 10-minute breaks once you build stamina or tackle deep analytical work.',
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
    // The page padding already insets this row, so only a gap underneath is needed.
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
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
                          'Learn Time-Boxed Sprints & Structured Intervals',
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

  @override
  Widget build(BuildContext context) {
    final service = PomodoroService();

    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Pomodoro Timer')),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                children: [
                  _buildStudyBanner(),

                  // Dial Timer View
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: DialTimer(
                          progress: service.progress,
                          color: service.dialColor,
                          label: service.centerLabel,
                          sublabel: service.sublabel,
                          onChanged: service.isRunning
                              ? null
                              : (p) => service.setDialMinutes(
                                    (p * PomodoroService.maxMinutes).round(),
                                  ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Pomodoro Preset Dropdown Menu
                  if (!service.isRunning) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<PomodoroPreset>(
                          value: service.selectedPreset,
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down),
                          items: PomodoroService.presets.map((preset) {
                            return DropdownMenuItem<PomodoroPreset>(
                              value: preset,
                              child: Text(
                                preset.label,
                                style: const TextStyle(fontSize: 14),
                              ),
                            );
                          }).toList(),
                          onChanged: (preset) {
                            if (preset != null) service.setPreset(preset);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Background Noise Selector Chips
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Background Noise',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.color
                              ?.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          _buildNoiseChip(service, NoiseType.off, 'Off',
                              Icons.volume_off_rounded),
                          _buildNoiseChip(service, NoiseType.white, 'White',
                              Icons.graphic_eq_rounded),
                          _buildNoiseChip(service, NoiseType.pink, 'Pink',
                              Icons.waves_rounded),
                          _buildNoiseChip(service, NoiseType.brown, 'Brown',
                              Icons.air_rounded),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  if (!service.isRunning) ...[
                    ColorSwatchPicker(
                      selectedColor: service.dialColor,
                      onColorSelected: service.setDialColor,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Start/Stop Action Button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: service.dialColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: service.isRunning
                          ? service.stopTimer
                          : service.startTimer,
                      child: Text(service.isRunning
                          ? 'Stop'
                          : (service.isWorkSession
                              ? 'Start Studying'
                              : 'Start Rest')),
                    ),
                  ),
                ],
              ),
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
      },
    );
  }

  Widget _buildNoiseChip(
    PomodoroService service,
    NoiseType type,
    String label,
    IconData icon,
  ) {
    final isSelected = service.selectedNoise == type;
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected ? Colors.white : service.dialColor,
      ),
      label: Text(label),
      selected: isSelected,
      selectedColor: service.dialColor,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : null,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) => service.setSelectedNoise(type),
    );
  }
}
