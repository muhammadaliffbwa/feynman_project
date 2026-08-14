// lib/models/todo.dart

class Todo {
  final String id;
  String title;
  bool done;
  String category;
  int? colorHex; // Persists selected custom color

  Todo({
    String? id,
    required this.title,
    this.done = false,
    this.category = 'General',
    this.colorHex,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'done': done,
        'category': category,
        'colorHex': colorHex,
      };

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'] as String?,
      title: json['title'] as String? ?? '',
      done: json['done'] as bool? ?? false,
      category: json['category'] as String? ?? 'General',
      colorHex: json['colorHex'] as int?,
    );
  }
}