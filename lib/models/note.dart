import 'dart:ui';

/// The three drawing tools available in Draw mode.
enum StrokeType { pen, highlighter, eraser }

/// One continuous line drawn on the canvas — a list of points plus how
/// it should be rendered.
class DrawStroke {
  final List<Offset> points;
  final Color color;
  final double width;
  final StrokeType type;

  DrawStroke({
    required this.points,
    required this.color,
    required this.width,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
        'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
        'color': color.toARGB32(),
        'width': width,
        'type': type.name,
      };

  factory DrawStroke.fromJson(Map<String, dynamic> json) {
    return DrawStroke(
      points: (json['points'] as List)
          .map((p) => Offset(
                (p['x'] as num).toDouble(),
                (p['y'] as num).toDouble(),
              ))
          .toList(),
      color: Color(json['color'] as int),
      width: (json['width'] as num).toDouble(),
      type: StrokeType.values.byName(json['type'] as String),
    );
  }
}

/// A single note. [textDelta] is the Quill "Delta" JSON representing the
/// rich text content (empty list if the user never typed anything);
/// [strokes] holds everything drawn in Draw mode. Both live in the same
/// note, matching the two-mode toggle in the editor.
class Note {
  String id;
  String title;
  List<dynamic> textDelta;
  List<DrawStroke> strokes;
  DateTime updatedAt;
  int? colorValue;

  Note({
    required this.id,
    required this.title,
    List<dynamic>? textDelta,
    List<DrawStroke>? strokes,
    DateTime? updatedAt,
    this.colorValue,
  })  : textDelta = textDelta ?? [],
        strokes = strokes ?? [],
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'textDelta': textDelta,
        'strokes': strokes.map((s) => s.toJson()).toList(),
        'updatedAt': updatedAt.toIso8601String(),
        'colorValue': colorValue,
      };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: json['id'] as String,
        title: json['title'] as String,
        textDelta: json['textDelta'] as List<dynamic>? ?? [],
        strokes: (json['strokes'] as List<dynamic>? ?? [])
            .map((s) => DrawStroke.fromJson(s as Map<String, dynamic>))
            .toList(),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        colorValue: json['colorValue'] as int?,
      );

  Note copyWith({
    String? id,
    String? title,
    List<dynamic>? textDelta,
    List<DrawStroke>? strokes,
    DateTime? updatedAt,
    int? colorValue,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      textDelta: textDelta ?? this.textDelta,
      strokes: strokes ?? this.strokes,
      updatedAt: updatedAt ?? this.updatedAt,
      colorValue: colorValue ?? this.colorValue,
    );
  }
}