// lib/screens/pomodoro_page.dart

import 'package:flutter/material.dart';

import '../services/noise_player.dart';
import '../services/pomodoro_service.dart';
import '../widgets/color_swatch_picker.dart';
import '../widgets/dial_timer.dart';
import '../widgets/mini_audio_player.dart';
import '../widgets/mini_stopwatch_bar.dart';
import 'stopwatch_page.dart';

class PomodoroPage extends StatelessWidget {
  const PomodoroPage({super.key});

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