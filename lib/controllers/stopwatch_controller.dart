import 'dart:async';
import 'package:flutter/material.dart';
import '../models/study_session.dart';
import '../services/focus_stats_service.dart';
import '../widgets/color_swatch_picker.dart';

class StopwatchController extends ChangeNotifier {
  static final StopwatchController instance = StopwatchController._internal();
  StopwatchController._internal();

  final Stopwatch stopwatch = Stopwatch();
  Timer? _uiTimer;

  String currentSubject = '';
  Color barColor = ColorSwatchPicker.options.first;
  bool isRunning = false;
  bool? _isPaused;
  int? _distractionCount;
  List<StudyCheckpoint>? _checkpoints;

  List<StudyCheckpoint> get _checkpointList => _checkpoints ??= [];

  bool get isPaused => _isPaused ?? false;
  bool get hasActiveSession => isRunning || isPaused;
  int get distractionCount => _distractionCount ?? 0;
  List<StudyCheckpoint> get checkpoints => List.unmodifiable(_checkpointList);

  void _startUiTimer() {
    _uiTimer?.cancel();
    _uiTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      FocusStatsService().updateLiveSessionSeconds(
        stopwatchSeconds: stopwatch.elapsed.inSeconds,
      );
      notifyListeners();
    });
  }

  void start(String subject) {
    if (subject.trim().isEmpty) return;
    currentSubject = subject.trim();
    isRunning = true;
    _isPaused = false;
    _distractionCount = 0;
    _checkpointList.clear();
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
    _distractionCount = distractionCount + 1;
    notifyListeners();
  }

  void resume() {
    if (!isPaused) return;
    stopwatch.start();
    isRunning = true;
    _isPaused = false;
    _startUiTimer();
    notifyListeners();
  }

  void addCheckpoint({String? label, Duration? atElapsed}) {
    if (!hasActiveSession) return;

    final list = _checkpointList;
    final recordedElapsed = atElapsed ?? stopwatch.elapsed;
    final previousElapsed =
        list.isEmpty ? Duration.zero : list.last.elapsed;
    final rawSplit = recordedElapsed - previousElapsed;
    final split = rawSplit.isNegative ? Duration.zero : rawSplit;

    final cleanedLabel = label?.trim() ?? '';
    final finalLabel = cleanedLabel.isNotEmpty
        ? cleanedLabel
        : 'Checkpoint #${list.length + 1}';

    list.add(
      StudyCheckpoint(
        label: finalLabel,
        elapsed: recordedElapsed,
        splitDuration: split,
      ),
    );
    notifyListeners();
  }

  void removeCheckpoint(int index) {
    final list = _checkpointList;
    if (index < 0 || index >= list.length) return;
    list.removeAt(index);

    for (int i = 0; i < list.length; i++) {
      final prevElapsed = i == 0 ? Duration.zero : list[i - 1].elapsed;
      final item = list[i];
      final recalculatedSplit = item.elapsed - prevElapsed;
      list[i] = StudyCheckpoint(
        label: item.label,
        elapsed: item.elapsed,
        splitDuration:
            recalculatedSplit.isNegative ? Duration.zero : recalculatedSplit,
      );
    }
    notifyListeners();
  }

  StudySession? stop() {
    if (!hasActiveSession) return null;

    stopwatch.stop();
    _uiTimer?.cancel();
    isRunning = false;
    _isPaused = false;

    final elapsed = stopwatch.elapsed;
    if (elapsed.inSeconds > 0) {
      FocusStatsService().logStopwatchDuration(elapsed);
    }

    final distractions = distractionCount;
    final subject = currentSubject;
    final recordedCheckpoints = List<StudyCheckpoint>.from(_checkpointList);
    final selectedColorValue = barColor.toARGB32();

    stopwatch.reset();
    _distractionCount = 0;
    _checkpointList.clear();
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
      colorValue: selectedColorValue,
      checkpoints: recordedCheckpoints,
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
