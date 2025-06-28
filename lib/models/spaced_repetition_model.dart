class SpacedRepetitionCard {
  final int? id;
  final int flashcardId;
  final double easeFactor; // Starts at 2.5, minimum 1.3
  final int interval; // Days until next review
  final int repetitions; // Number of successful reviews
  final int lapses; // Number of times card was forgotten
  final DateTime? nextReview; // When the card should be reviewed next
  final DateTime lastReviewed;
  final ReviewQuality? lastReviewQuality; // Quality of last review

  SpacedRepetitionCard({
    this.id,
    required this.flashcardId,
    this.easeFactor = 2.5,
    this.interval = 0,
    this.repetitions = 0,
    this.lapses = 0,
    this.nextReview,
    required this.lastReviewed,
    this.lastReviewQuality,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'flashcard_id': flashcardId,
      'ease_factor': easeFactor,
      'interval': interval,
      'repetitions': repetitions,
      'lapses': lapses,
      'next_review': nextReview?.toIso8601String(),
      'last_reviewed': lastReviewed.toIso8601String(),
      'last_review_quality': lastReviewQuality?.index,
    };
  }

  static SpacedRepetitionCard fromMap(Map<String, dynamic> map) {
    return SpacedRepetitionCard(
      id: map['id'],
      flashcardId: map['flashcard_id'],
      easeFactor: map['ease_factor']?.toDouble() ?? 2.5,
      interval: map['interval'] ?? 0,
      repetitions: map['repetitions'] ?? 0,
      lapses: map['lapses'] ?? 0,
      nextReview: map['next_review'] != null 
          ? DateTime.parse(map['next_review']) 
          : null,
      lastReviewed: DateTime.parse(map['last_reviewed']),
      lastReviewQuality: map['last_review_quality'] != null 
          ? ReviewQuality.values[map['last_review_quality']] 
          : null,
    );
  }

  SpacedRepetitionCard copyWith({
    int? id,
    int? flashcardId,
    double? easeFactor,
    int? interval,
    int? repetitions,
    int? lapses,
    DateTime? nextReview,
    DateTime? lastReviewed,
    ReviewQuality? lastReviewQuality,
  }) {
    return SpacedRepetitionCard(
      id: id ?? this.id,
      flashcardId: flashcardId ?? this.flashcardId,
      easeFactor: easeFactor ?? this.easeFactor,
      interval: interval ?? this.interval,
      repetitions: repetitions ?? this.repetitions,
      lapses: lapses ?? this.lapses,
      nextReview: nextReview ?? this.nextReview,
      lastReviewed: lastReviewed ?? this.lastReviewed,
      lastReviewQuality: lastReviewQuality ?? this.lastReviewQuality,
    );
  }

  /// Check if the card is due for review
  bool get isDue {
    if (nextReview == null) return true;
    return DateTime.now().isAfter(nextReview!);
  }

  /// Get the number of days until next review
  int get daysUntilReview {
    if (nextReview == null) return 0;
    final now = DateTime.now();
    final next = nextReview!;
    return next.difference(now).inDays;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'easeFactor': easeFactor,
      'interval': interval,
      'repetitions': repetitions,
      'lapses': lapses,
      'nextReview': nextReview?.toIso8601String(),
      'lastReviewed': lastReviewed.toIso8601String(),
      'lastReviewQuality': lastReviewQuality?.index,
    };
  }

  static SpacedRepetitionCard fromFirestore(Map<String, dynamic> map, int flashcardId) {
    return SpacedRepetitionCard(
      flashcardId: flashcardId,
      easeFactor: (map['easeFactor'] ?? 2.5).toDouble(),
      interval: map['interval'] ?? 0,
      repetitions: map['repetitions'] ?? 0,
      lapses: map['lapses'] ?? 0,
      nextReview: map['nextReview'] != null ? DateTime.parse(map['nextReview']) : null,
      lastReviewed: map['lastReviewed'] != null ? DateTime.parse(map['lastReviewed']) : DateTime.now(),
      lastReviewQuality: map['lastReviewQuality'] != null ? ReviewQuality.values[map['lastReviewQuality']] : null,
    );
  }
}

/// Review quality levels based on Anki's system
enum ReviewQuality {
  again(0),    // Complete blackout
  hard(1),     // Incorrect response; correct response recalled with serious difficulty
  good(2),     // Correct response recalled with some difficulty
  easy(3);     // Correct response with no difficulty

  const ReviewQuality(this.value);
  final int value;
}

/// Learning states for cards
enum LearningState {
  newCard,     // Card hasn't been studied yet
  learning,    // Card is in learning phase (short intervals)
  reviewing,   // Card is in review phase (longer intervals)
  relearning,  // Card was forgotten and is being relearned
} 