class StudySession {
  final String subject;
  final Duration duration;
  final DateTime endedAt;
  final int distractions;

  StudySession({
    required this.subject,
    required this.duration,
    required this.endedAt,
    this.distractions = 0,
  });

  factory StudySession.fromJson(Map<String, dynamic> json) {
    return StudySession(
      subject: json['subject'] as String,
      duration: Duration(milliseconds: json['durationMs'] as int),
      endedAt: DateTime.parse(json['endedAt'] as String),
      distractions: (json['distractions'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'subject': subject,
      'durationMs': duration.inMilliseconds,
      'endedAt': endedAt.toIso8601String(),
      'distractions': distractions,
    };
  }
}