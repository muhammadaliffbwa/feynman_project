class StudySession {
  final String subject;
  final Duration duration;
  final DateTime endedAt;

  StudySession({
    required this.subject,
    required this.duration,
    required this.endedAt,
  });

  Map<String, dynamic> toJson() => {
        'subject': subject,
        'durationSeconds': duration.inSeconds,
        'endedAt': endedAt.toIso8601String(),
      };

  factory StudySession.fromJson(Map<String, dynamic> json) => StudySession(
        subject: json['subject'] as String,
        duration: Duration(seconds: json['durationSeconds'] as int),
        endedAt: DateTime.parse(json['endedAt'] as String),
      );
}