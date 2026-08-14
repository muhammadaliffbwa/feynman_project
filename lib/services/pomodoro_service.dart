import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import '../services/noise_player.dart';

class PomodoroPreset {
  final int workMinutes;
  final int restMinutes;

  const PomodoroPreset({required this.workMinutes, required this.restMinutes});

  String get label => '$workMinutes min work / $restMinutes min rest';
}

class PomodoroService extends ChangeNotifier {
  static final PomodoroService _instance = PomodoroService._internal();
  factory PomodoroService() => _instance;
  PomodoroService._internal();

  static const int maxMinutes = 60;
  static const List<PomodoroPreset> presets = [
    PomodoroPreset(workMinutes: 25, restMinutes: 5),
    PomodoroPreset(workMinutes: 30, restMinutes: 10),
    PomodoroPreset(workMinutes: 45, restMinutes: 15),
    PomodoroPreset(workMinutes: 60, restMinutes: 20),
  ];

  PomodoroPreset selectedPreset = presets.first;
  bool isWorkSession = true;
  int selectedMinutes = 25;
  int remainingSeconds = 0;
  bool isRunning = false;
  Color dialColor = const Color(0xFF1B5E20);

  Timer? _timer;
  final NoisePlayer noisePlayer = NoisePlayer();
  NoiseType selectedNoise = NoiseType.off;

  GlobalKey<NavigatorState>? navigatorKey;

  double get progress {
    if (isRunning) {
      final totalSeconds = selectedMinutes * 60;
      return totalSeconds == 0 ? 0 : remainingSeconds / totalSeconds;
    }
    return selectedMinutes / maxMinutes;
  }

  String get centerLabel {
    if (isRunning) {
      final minutes = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
      final seconds = (remainingSeconds % 60).toString().padLeft(2, '0');
      return '$minutes:$seconds';
    }
    return '$selectedMinutes';
  }

  String get sublabel => isWorkSession ? 'work' : 'rest';

  void setPreset(PomodoroPreset preset) {
    if (isRunning) return;
    selectedPreset = preset;
    selectedMinutes = isWorkSession ? preset.workMinutes : preset.restMinutes;
    notifyListeners();
  }

  void setDialMinutes(int minutes) {
    if (isRunning) return;
    selectedMinutes = minutes.clamp(1, maxMinutes);
    notifyListeners();
  }

  void setDialColor(Color color) {
    dialColor = color;
    notifyListeners();
  }

  void setSelectedNoise(NoiseType type) {
    selectedNoise = type;
    if (isRunning) {
      noisePlayer.play(type);
    }
    notifyListeners();
  }

  void startTimer() {
    isRunning = true;
    remainingSeconds = selectedMinutes * 60;

    if (selectedNoise != NoiseType.off) {
      noisePlayer.play(selectedNoise);
    }

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
    notifyListeners();
  }

  void _tick(Timer timer) {
    if (remainingSeconds > 1) {
      remainingSeconds--;
      notifyListeners();
    } else {
      timer.cancel();
      _onTimerComplete();
    }
  }

  void stopTimer() {
    _timer?.cancel();
    noisePlayer.stop();
    isRunning = false;
    remainingSeconds = 0;
    notifyListeners();
  }

  Future<void> _onTimerComplete() async {
    noisePlayer.stop();
    isRunning = false;
    
    // Store finished session state for notification display
    final completedSessionName = isWorkSession ? 'Work session' : 'Rest session';

    // Toggle next phase & reset dial back to main setup view
    isWorkSession = !isWorkSession;
    selectedMinutes =
        isWorkSession ? selectedPreset.workMinutes : selectedPreset.restMinutes;
    remainingSeconds = 0;

    // Trigger UI updates immediately to leave the 0-timer state
    notifyListeners();

    // Haptics & Vibration
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator) {
        Vibration.vibrate(pattern: [0, 500, 200, 500]);
      } else {
        HapticFeedback.heavyImpact();
      }
    } catch (_) {}

    // Display global floating completion notification
    _showCompletionNotification(completedSessionName);
  }

  void _showCompletionNotification(String completedSession) {
    final overlayState = navigatorKey?.currentState?.overlay;
    if (overlayState == null) return;

    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) {
        final theme = Theme.of(context);
        return Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          left: 16,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.inverseSurface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.notifications_active_rounded,
                    color: theme.colorScheme.onInverseSurface,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$completedSession complete!',
                      style: TextStyle(
                        color: theme.colorScheme.onInverseSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: theme.colorScheme.onInverseSurface,
                      size: 18,
                    ),
                    onPressed: () {
                      if (overlayEntry.mounted) {
                        overlayEntry.remove();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    overlayState.insert(overlayEntry);

    // Auto dismiss after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }
}