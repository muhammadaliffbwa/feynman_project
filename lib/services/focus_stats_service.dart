// lib/services/focus_stats_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FocusStatsService extends ChangeNotifier {
  static final FocusStatsService _instance = FocusStatsService._internal();
  factory FocusStatsService() => _instance;

  FocusStatsService._internal() {
    _loadHistory();
  }

  static const String _storageKey = 'daily_focus_history';

  // Map<'YYYY-MM-DD', {'pomodoro': intSeconds, 'stopwatch': intSeconds}>
  Map<String, Map<String, int>> _dailyHistory = {};

  // Optional live in-progress seconds from active timers before they save
  int _activePomodoroSeconds = 0;
  int _activeStopwatchSeconds = 0;

  String _dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  int get todayPomodoroSeconds {
    final saved = _dailyHistory[_dateKey(DateTime.now())]?['pomodoro'] ?? 0;
    return saved + _activePomodoroSeconds;
  }

  int get todayStopwatchSeconds {
    final saved = _dailyHistory[_dateKey(DateTime.now())]?['stopwatch'] ?? 0;
    return saved + _activeStopwatchSeconds;
  }

  int get todayTotalSeconds => todayPomodoroSeconds + todayStopwatchSeconds;

  Duration get todayPomodoroDuration => Duration(seconds: todayPomodoroSeconds);
  Duration get todayStopwatchDuration =>
      Duration(seconds: todayStopwatchSeconds);
  Duration get todayTotalDuration => Duration(seconds: todayTotalSeconds);

  int _savedSecondsForDate(DateTime date) {
    final entry = _dailyHistory[_dateKey(date)];
    if (entry == null) return 0;
    return (entry['pomodoro'] ?? 0) + (entry['stopwatch'] ?? 0);
  }

  /// Counts consecutive days with logged focus time.
  /// If today has no logged time yet, preserves the active streak through yesterday.
  int get currentStreak {
    final today = _dateOnly(DateTime.now());
    final hasToday = todayTotalSeconds > 0;

    DateTime cursor = hasToday ? today : today.subtract(const Duration(days: 1));
    int streak = 0;

    while (true) {
      final hasFocus = (cursor == today && hasToday) ||
          _savedSecondsForDate(cursor) > 0;
      if (!hasFocus) break;
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return streak;
  }

  Future<void> logPomodoroDuration(Duration duration) async {
    if (duration.inSeconds <= 0) return;
    await _addSeconds(pomodoroSeconds: duration.inSeconds);
  }

  Future<void> logStopwatchDuration(Duration duration) async {
    if (duration.inSeconds <= 0) return;
    await _addSeconds(stopwatchSeconds: duration.inSeconds);
  }

  /// Optional: update in-progress timer seconds for live readout before saving.
  void updateLiveSessionSeconds({
    int? pomodoroSeconds,
    int? stopwatchSeconds,
  }) {
    bool changed = false;
    if (pomodoroSeconds != null && pomodoroSeconds != _activePomodoroSeconds) {
      _activePomodoroSeconds = pomodoroSeconds.clamp(0, 86400);
      changed = true;
    }
    if (stopwatchSeconds != null &&
        stopwatchSeconds != _activeStopwatchSeconds) {
      _activeStopwatchSeconds = stopwatchSeconds.clamp(0, 86400);
      changed = true;
    }
    if (changed) notifyListeners();
  }

  Future<void> _addSeconds({
    int pomodoroSeconds = 0,
    int stopwatchSeconds = 0,
  }) async {
    final key = _dateKey(DateTime.now());
    final current = _dailyHistory[key] ?? {'pomodoro': 0, 'stopwatch': 0};

    _dailyHistory[key] = {
      'pomodoro': (current['pomodoro'] ?? 0) + pomodoroSeconds,
      'stopwatch': (current['stopwatch'] ?? 0) + stopwatchSeconds,
    };

    if (pomodoroSeconds > 0) _activePomodoroSeconds = 0;
    if (stopwatchSeconds > 0) _activeStopwatchSeconds = 0;

    notifyListeners();
    await _saveHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return;

      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _dailyHistory = decoded.map((dateKey, value) {
        final map = value as Map<String, dynamic>;
        return MapEntry(dateKey, {
          'pomodoro': (map['pomodoro'] as num?)?.toInt() ?? 0,
          'stopwatch': (map['stopwatch'] as num?)?.toInt() ?? 0,
        });
      });
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading focus stats: $e');
    }
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(_dailyHistory));
    } catch (e) {
      debugPrint('Error saving focus stats: $e');
    }
  }

  String formatFocusMinutes(Duration duration) {
    final totalMinutes = duration.inMinutes;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h';
    if (minutes > 0) return '${minutes}m';
    if (duration.inSeconds > 0) return '<1m';
    return '0m';
  }
}