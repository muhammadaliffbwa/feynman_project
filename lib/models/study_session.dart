class StudyCheckpoint {
  final String label;
  final Duration elapsed;
  final Duration splitDuration;

  StudyCheckpoint({
    required this.label,
    required this.elapsed,
    required this.splitDuration,
  });

  factory StudyCheckpoint.fromJson(Map<String, dynamic> json) {
    return StudyCheckpoint(
      label: json['label'] as String,
      elapsed: Duration(milliseconds: json['elapsedMs'] as int),
      splitDuration: Duration(milliseconds: (json['splitMs'] as int?) ?? 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'elapsedMs': elapsed.inMilliseconds,
      'splitMs': splitDuration.inMilliseconds,
    };
  }
}

class StudySession {
  final String subject;
  final Duration duration;
  final DateTime endedAt;
  final int distractions;
  final int? colorValue;
  final List<StudyCheckpoint>? _checkpoints;

  List<StudyCheckpoint> get checkpoints => _checkpoints ?? const [];

  StudySession({
    required this.subject,
    required this.duration,
    required this.endedAt,
    this.distractions = 0,
    this.colorValue,
    List<StudyCheckpoint> checkpoints = const [],
  }) : _checkpoints = checkpoints;

  factory StudySession.fromJson(Map<String, dynamic> json) {
    final rawCheckpoints = json['checkpoints'] as List<dynamic>?;
    final parsedCheckpoints = rawCheckpoints != null
        ? rawCheckpoints
            .map((item) =>
                StudyCheckpoint.fromJson(item as Map<String, dynamic>))
            .toList()
        : <StudyCheckpoint>[];

    return StudySession(
      subject: json['subject'] as String,
      duration: Duration(milliseconds: json['durationMs'] as int),
      endedAt: DateTime.parse(json['endedAt'] as String),
      distractions: (json['distractions'] as int?) ?? 0,
      colorValue: json['colorValue'] as int?,
      checkpoints: parsedCheckpoints,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'subject': subject,
      'durationMs': duration.inMilliseconds,
      'endedAt': endedAt.toIso8601String(),
      'distractions': distractions,
      'colorValue': colorValue,
      'checkpoints': checkpoints.map((c) => c.toJson()).toList(),
    };
  }
}