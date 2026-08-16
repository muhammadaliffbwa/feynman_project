import 'dart:math';
import 'dart:ui';

enum ReviewRating { again, hard, good, easy }

class Flashcard {
  final String question;
  final String answer;

  // SRS State Fields — intervalMinutes replaces the old intervalDays.
  // Days-only granularity couldn't represent a 10-minute "try again
  // soon" gap without rounding it down to 0, which is what was
  // collapsing Again/Hard/Good into the same value. Minutes can
  // represent both a 10-minute relearning step and a 90-day mature
  // interval, so nothing else about the model needs two systems.
  int repetitions;
  int intervalMinutes;
  double easeFactor;
  DateTime nextDueDate;

  static const int _day = 1440; // minutes in a day

  Flashcard({
    required this.question,
    required this.answer,
    this.repetitions = 0,
    this.intervalMinutes = 0,
    this.easeFactor = 2.5,
    DateTime? nextDueDate,
  }) : nextDueDate = nextDueDate ?? DateTime.now();

  bool get isDue => DateTime.now().isAfter(nextDueDate);

  /// Anki / SM-2 Spaced Repetition Algorithm Logic
  void processReview(ReviewRating rating) {
    switch (rating) {
      case ReviewRating.again:
        // Always short, regardless of how mature the card was — a lapse
        // means "come back soon and try again," not "come back tomorrow."
        repetitions = 0;
        intervalMinutes = 10;
        easeFactor = max(1.3, easeFactor - 0.2);
        break;

      case ReviewRating.hard:
        if (repetitions == 0) {
          // Still in the initial learning phase — longer than Again,
          // but deliberately short of Good's full-day graduation.
          intervalMinutes = 25;
        } else {
          intervalMinutes = (intervalMinutes * 1.2).round();
          if (intervalMinutes < _day) intervalMinutes = _day;
        }
        repetitions += 1;
        easeFactor = max(1.3, easeFactor - 0.15);
        break;

      case ReviewRating.good:
        if (repetitions == 0) {
          intervalMinutes = _day; // graduates out of the learning phase
        } else if (repetitions == 1) {
          intervalMinutes = 6 * _day;
        } else {
          intervalMinutes = (intervalMinutes * easeFactor).round();
        }
        repetitions += 1;
        break;

      case ReviewRating.easy:
        if (repetitions == 0) {
          intervalMinutes = 4 * _day; // skips learning, graduates immediately
        } else if (repetitions == 1) {
          intervalMinutes = 10 * _day;
        } else {
          intervalMinutes = (intervalMinutes * easeFactor * 1.3).round();
        }
        repetitions += 1;
        easeFactor += 0.15;
        break;
    }

    nextDueDate = DateTime.now().add(Duration(minutes: intervalMinutes));
  }

  /// Predicts the interval (in minutes) that [rating] would produce,
  /// without applying it. Mirrors processReview()'s branching exactly —
  /// used to show a live preview on each rating button.
  int previewIntervalMinutes(ReviewRating rating) {
    switch (rating) {
      case ReviewRating.again:
        return 10;

      case ReviewRating.hard:
        if (repetitions == 0) return 25;
        final preview = (intervalMinutes * 1.2).round();
        return preview < _day ? _day : preview;

      case ReviewRating.good:
        if (repetitions == 0) return _day;
        if (repetitions == 1) return 6 * _day;
        return (intervalMinutes * easeFactor).round();

      case ReviewRating.easy:
        if (repetitions == 0) return 4 * _day;
        if (repetitions == 1) return 10 * _day;
        return (intervalMinutes * easeFactor * 1.3).round();
    }
  }

  Map<String, dynamic> toJson() => {
        'question': question,
        'answer': answer,
        'repetitions': repetitions,
        'intervalMinutes': intervalMinutes,
        'easeFactor': easeFactor,
        'nextDueDate': nextDueDate.toIso8601String(),
      };

  factory Flashcard.fromJson(Map<String, dynamic> json) {
    // Backward-compatible with decks saved before this change, which
    // stored whole days under the old 'intervalDays' key.
    final int minutes;
    if (json['intervalMinutes'] != null) {
      minutes = (json['intervalMinutes'] as num).toInt();
    } else if (json['intervalDays'] != null) {
      minutes = (json['intervalDays'] as num).toInt() * _day;
    } else {
      minutes = 0;
    }

    return Flashcard(
      question: json['question'] as String,
      answer: json['answer'] as String,
      repetitions: (json['repetitions'] as num?)?.toInt() ?? 0,
      intervalMinutes: minutes,
      easeFactor: (json['easeFactor'] as num?)?.toDouble() ?? 2.5,
      nextDueDate: json['nextDueDate'] != null
          ? DateTime.parse(json['nextDueDate'] as String)
          : DateTime.now(),
    );
  }

  Flashcard copyWith({
    String? question,
    String? answer,
    int? repetitions,
    int? intervalMinutes,
    double? easeFactor,
    DateTime? nextDueDate,
  }) {
    return Flashcard(
      question: question ?? this.question,
      answer: answer ?? this.answer,
      repetitions: repetitions ?? this.repetitions,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      easeFactor: easeFactor ?? this.easeFactor,
      nextDueDate: nextDueDate ?? this.nextDueDate,
    );
  }
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
      tags: tags ?? this.tags,
    );
  }
}