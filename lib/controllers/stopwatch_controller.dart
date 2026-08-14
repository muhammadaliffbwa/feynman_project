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

  void start(String subject) {
    if (subject.trim().isEmpty) return;
    currentSubject = subject.trim();
    isRunning = true;
    stopwatch.start();

    _uiTimer?.cancel();
    _uiTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      notifyListeners();
    });
    notifyListeners();
  }

  StudySession? stop() {
    stopwatch.stop();
    _uiTimer?.cancel();
    isRunning = false;

    if (stopwatch.elapsed.inSeconds == 0) return null;

    final session = StudySession(
      subject: currentSubject,
      duration: stopwatch.elapsed,
      endedAt: DateTime.now(),
    );

    stopwatch.reset();
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