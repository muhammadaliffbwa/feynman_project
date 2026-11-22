import 'dart:async';
import 'package:flutter/material.dart';
import '../models/study_session.dart';
import '../widgets/color_swatch_picker.dart';

class StopwatchController extends ChangeNotifier {
  static final StopwatchController instance = StopwatchController._internal();
  StopwatchController._internal();

  final Stopwatch stopwatch = Stopwatch();
  Timer? _uiTimer;

  String currentSubject = '';
  Color barColor = ColorSwatchPicker.options.first;
  bool isRunning = false;
  bool _isPaused = false;
  int _distractionCount = 0;

  bool get isPaused => _isPaused;
  bool get hasActiveSession => isRunning || _isPaused;
  int get distractionCount => _distractionCount;

  void _startUiTimer() {
    _uiTimer?.cancel();
    _uiTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      notifyListeners();
    });
  }

  void start(String subject) {
    if (subject.trim().isEmpty) return;
    currentSubject = subject.trim();
    isRunning = true;
    _isPaused = false;
    _distractionCount = 0;
    stopwatch.reset();
    stopwatch.start();

    _startUiTimer();
    notifyListeners();
  }

  void pause() {
    if (!isRunning) return;
    stopwatch.stop();
    _uiTimer?.cancel();
    isRunning = false;
    _isPaused = true;
    _distractionCount++;
    notifyListeners();
  }

  void resume() {
    if (!_isPaused) return;
    stopwatch.start();
    isRunning = true;
    _isPaused = false;
    _startUiTimer();
    notifyListeners();
  }

  StudySession? stop() {
    if (!hasActiveSession) return null;

    stopwatch.stop();
    _uiTimer?.cancel();
    isRunning = false;
    _isPaused = false;

    final elapsed = stopwatch.elapsed;
    final distractions = _distractionCount;
    final subject = currentSubject;

    stopwatch.reset();
    _distractionCount = 0;
    currentSubject = '';

    if (elapsed.inSeconds == 0) {
      notifyListeners();
      return null;
    }

    final session = StudySession(
      subject: subject,
      duration: elapsed,
      endedAt: DateTime.now(),
      distractions: distractions,
    );

    notifyListeners();
    return session;
  }

  void setBarColor(Color color) {
    barColor = color;
    notifyListeners();
  }

  String formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}