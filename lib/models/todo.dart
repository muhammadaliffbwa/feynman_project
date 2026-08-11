class Todo {
  String title;
  bool done;

  Todo({required this.title, this.done = false});

  // Convert a Todo into a simple Map, so it can be turned into JSON
  Map<String, dynamic> toJson() => {'title': title, 'done': done};

  // Rebuild a Todo from a Map (the reverse direction)
  factory Todo.fromJson(Map<String, dynamic> json) =>
      Todo(title: json['title'], done: json['done']);
}