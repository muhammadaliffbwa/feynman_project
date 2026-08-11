import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

import '../widgets/color_swatch_picker.dart';
import '../widgets/dial_timer.dart';

class PomodoroPage extends StatefulWidget {
  const PomodoroPage({super.key});

  @override
  State<PomodoroPage> createState() => _PomodoroPageState();
}

class _PomodoroPageState extends State<PomodoroPage> {
  static const int _maxMinutes = 60; // one full lap of the dial

  int _selectedMinutes = 25; // chosen while the dial is being set
  int _remainingSeconds = 0; // ticks down once running
  bool _isRunning = false;
  Color _dialColor = ColorSwatchPicker.options.first;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // While setting: how far around the dial the chosen minutes sit.
  // While running: how much time is left, as a fraction of the total —
  // this makes the arc visually "unwind" as the countdown proceeds.
  double get _progress {
    if (_isRunning) {
      final totalSeconds = _selectedMinutes * 60;
      return totalSeconds == 0 ? 0 : _remainingSeconds / totalSeconds;
    }
    return _selectedMinutes / _maxMinutes;
  }

  String get _centerLabel {
    if (_isRunning) {
      final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
      final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
      return '$minutes:$seconds';
    }
    return '$_selectedMinutes';
  }

  void _onDialChanged(double progress) {
    int minutes = (progress * _maxMinutes).round();
    if (minutes < 1) minutes = 1; // never let it drop to a 0-minute timer
    if (minutes > _maxMinutes) minutes = _maxMinutes;
    setState(() => _selectedMinutes = minutes);
  }

  void _startTimer() {
    setState(() {
      _isRunning = true;
      _remainingSeconds = _selectedMinutes * 60;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  void _tick(Timer timer) {
    setState(() => _remainingSeconds--);
    if (_remainingSeconds <= 0) {
      timer.cancel();
      _onTimerComplete();
    }
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _remainingSeconds = 0;
    });
  }

  Future<void> _onTimerComplete() async {
    // Buzz the phone. Wrapped in try/catch since some devices/emulators
    // have no vibration motor and would otherwise throw.
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator) {
        Vibration.vibrate(pattern: [0, 500, 200, 500]);
      } else {
        HapticFeedback.heavyImpact(); // fallback: a short haptic tick
      }
    } catch (_) {
      // No vibration available — not worth interrupting the flow for.
    }

    if (!mounted) return;
    setState(() => _isRunning = false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Time's up!", textAlign: TextAlign.center),
        content: const Text(
          'Your study session has ended. What would you like to do?',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() => _selectedMinutes = 25); // back to default
            },
            child: const Text('End Study Session'),
          ),
          FilledButton(
            // Just closes the dialog — the dial is already back in
            // "set" mode underneath, ready to drag to a new duration.
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continue Flow State'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pomodoro Timer')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: DialTimer(
                      progress: _progress,
                      color: _dialColor,
                      label: _centerLabel,
                      sublabel:
                          _isRunning ? 'remaining' : 'minutes — drag to set',
                      onChanged: _isRunning ? null : _onDialChanged,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (!_isRunning) ...[
                ColorSwatchPicker(
                  selectedColor: _dialColor,
                  onColorSelected: (color) =>
                      setState(() => _dialColor = color),
                ),
                const SizedBox(height: 24),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _dialColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _isRunning ? _stopTimer : _startTimer,
                  child: Text(_isRunning ? 'Stop' : 'Start Studying'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}