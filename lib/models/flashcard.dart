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
  final Set<int> reviewedCardIndexes;
  final Map<int, bool> cardRatings;
  final List<String> tags;

  FlashcardDeck({
    required this.id,
    required this.title,
    required this.cards,
    required this.color,
    DateTime? createdAt,
    Set<int>? reviewedCardIndexes,
    Map<int, bool>? cardRatings,
    List<String>? tags,
  })  : createdAt = createdAt ?? DateTime.now(),
        reviewedCardIndexes = reviewedCardIndexes ?? {},
        cardRatings = cardRatings ?? {},
        tags = tags ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'cards': cards.map((c) => c.toJson()).toList(),
        'color': color.toARGB32(),
        'createdAt': createdAt.toIso8601String(),
        'reviewedCardIndexes': reviewedCardIndexes.toList(),
        'cardRatings': cardRatings.map((k, v) => MapEntry(k.toString(), v)),
        'tags': tags,
      };

  factory FlashcardDeck.fromJson(Map<String, dynamic> json) => FlashcardDeck(
        id: json['id'] as String,
        title: json['title'] as String,
        cards: (json['cards'] as List)
            .map((c) => Flashcard.fromJson(c as Map<String, dynamic>))
            .toList(),
        color: Color(json['color'] as int),
        createdAt: DateTime.parse(json['createdAt'] as String),
        reviewedCardIndexes: (json['reviewedCardIndexes'] as List?)
                ?.map((e) => e as int)
                .toSet() ??
            {},
        cardRatings: (json['cardRatings'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(int.parse(k), v as bool),
            ) ??
            {},
        tags: (json['tags'] as List?)?.map((e) => e as String).toList() ?? [],
      );
  FlashcardDeck copyWith({
    String? id,
    String? title,
    List<Flashcard>? cards,
    Color? color,
    DateTime? createdAt,
    Set<int>? reviewedCardIndexes,
    Map<int, bool>? cardRatings,
    List<String>? tags,
  }) {
    return FlashcardDeck(
      id: id ?? this.id,
      title: title ?? this.title,
      cards: cards ?? this.cards,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      reviewedCardIndexes: reviewedCardIndexes ?? this.reviewedCardIndexes,
      cardRatings: cardRatings ?? this.cardRatings,
      tags: tags ?? this.tags, // Preserves tags if not updated
    );
  }
}