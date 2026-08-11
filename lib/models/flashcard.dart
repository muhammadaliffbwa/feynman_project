import 'dart:ui';

class Flashcard {
  final String question;
  final String answer;

  Flashcard({required this.question, required this.answer});

  Map<String, dynamic> toJson() => {'question': question, 'answer': answer};

  factory Flashcard.fromJson(Map<String, dynamic> json) => Flashcard(
        question: json['question'] as String,
        answer: json['answer'] as String,
      );
}

class FlashcardDeck {
  final String id;
  final String title;
  final List<Flashcard> cards;
  final Color color;
  final DateTime createdAt;

  FlashcardDeck({
    required this.id,
    required this.title,
    required this.cards,
    required this.color,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'cards': cards.map((c) => c.toJson()).toList(),
        'color': color.toARGB32(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory FlashcardDeck.fromJson(Map<String, dynamic> json) => FlashcardDeck(
        id: json['id'] as String,
        title: json['title'] as String,
        cards: (json['cards'] as List)
            .map((c) => Flashcard.fromJson(c as Map<String, dynamic>))
            .toList(),
        color: Color(json['color'] as int),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}