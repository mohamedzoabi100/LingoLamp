import '../models/spaced_repetition_model.dart';

class SpacedRepetitionService {
  // SM2 Algorithm constants
  static const double _initialEaseFactor = 2.5;
  static const double _minimumEaseFactor = 1.3;
  static const double _easeFactorBonus = 0.1;
  static const double _easeFactorPenalty = 0.15;
  
  // Learning intervals (in minutes for learning phase)
  static const List<int> _learningIntervals = [1, 10, 1440]; // 1 min, 10 min, 1 day
  
  // Relearning intervals (in minutes)
  static const List<int> _relearningIntervals = [10, 1440]; // 10 min, 1 day

  /// Process a review and return updated card data
  static SpacedRepetitionCard processReview(
    SpacedRepetitionCard card,
    ReviewQuality quality,
  ) {
    final now = DateTime.now();
    
    switch (quality) {
      case ReviewQuality.again:
        return _processAgain(card, now);
      case ReviewQuality.hard:
        return _processHard(card, now);
      case ReviewQuality.good:
        return _processGood(card, now);
      case ReviewQuality.easy:
        return _processEasy(card, now);
    }
  }

  /// Process "Again" response (complete blackout)
  static SpacedRepetitionCard _processAgain(
    SpacedRepetitionCard card,
    DateTime now,
  ) {
    // Reset to learning phase
    final newEaseFactor = (card.easeFactor - _easeFactorPenalty).clamp(
      _minimumEaseFactor,
      double.infinity,
    );
    
    return card.copyWith(
      easeFactor: newEaseFactor,
      interval: 0,
      repetitions: 0,
      lapses: card.lapses + 1,
      nextReview: now.add(Duration(minutes: _learningIntervals[0])),
      lastReviewed: now,
      lastReviewQuality: ReviewQuality.again,
    );
  }

  /// Process "Hard" response
  static SpacedRepetitionCard _processHard(
    SpacedRepetitionCard card,
    DateTime now,
  ) {
    final newEaseFactor = (card.easeFactor - _easeFactorPenalty).clamp(
      _minimumEaseFactor,
      double.infinity,
    );
    
    int newInterval;
    int newRepetitions;
    
    if (card.repetitions == 0) {
      // Still in learning phase
      newInterval = _learningIntervals[1]; // 10 minutes
      newRepetitions = 1;
    } else if (card.repetitions == 1) {
      // Second learning step
      newInterval = _learningIntervals[2]; // 1 day
      newRepetitions = 2;
    } else {
      // In review phase, but hard response
      newInterval = (card.interval * 1.2).round(); // 20% increase
      newRepetitions = card.repetitions + 1;
    }
    
    return card.copyWith(
      easeFactor: newEaseFactor,
      interval: newInterval,
      repetitions: newRepetitions,
      nextReview: now.add(Duration(minutes: newInterval)),
      lastReviewed: now,
      lastReviewQuality: ReviewQuality.hard,
    );
  }

  /// Process "Good" response
  static SpacedRepetitionCard _processGood(
    SpacedRepetitionCard card,
    DateTime now,
  ) {
    int newInterval;
    int newRepetitions;
    
    if (card.repetitions == 0) {
      // First learning step
      newInterval = _learningIntervals[1]; // 10 minutes
      newRepetitions = 1;
    } else if (card.repetitions == 1) {
      // Second learning step
      newInterval = _learningIntervals[2]; // 1 day
      newRepetitions = 2;
    } else {
      // In review phase
      newInterval = (card.interval * card.easeFactor).round();
      newRepetitions = card.repetitions + 1;
    }
    
    return card.copyWith(
      interval: newInterval,
      repetitions: newRepetitions,
      nextReview: now.add(Duration(minutes: newInterval)),
      lastReviewed: now,
      lastReviewQuality: ReviewQuality.good,
    );
  }

  /// Process "Easy" response
  static SpacedRepetitionCard _processEasy(
    SpacedRepetitionCard card,
    DateTime now,
  ) {
    final newEaseFactor = (card.easeFactor + _easeFactorBonus).clamp(
      _minimumEaseFactor,
      double.infinity,
    );
    
    int newInterval;
    int newRepetitions;
    
    if (card.repetitions == 0) {
      // Skip learning phase, go directly to review
      newInterval = _learningIntervals[2]; // 1 day
      newRepetitions = 1;
    } else if (card.repetitions == 1) {
      // Skip to review phase
      newInterval = (card.interval * card.easeFactor * 1.3).round(); // Bonus for easy
      newRepetitions = 2;
    } else {
      // In review phase, easy response
      newInterval = (card.interval * card.easeFactor * 1.3).round(); // Bonus for easy
      newRepetitions = card.repetitions + 1;
    }
    
    return card.copyWith(
      easeFactor: newEaseFactor,
      interval: newInterval,
      repetitions: newRepetitions,
      nextReview: now.add(Duration(minutes: newInterval)),
      lastReviewed: now,
      lastReviewQuality: ReviewQuality.easy,
    );
  }

  /// Create a new spaced repetition card for a flashcard
  static SpacedRepetitionCard createNewCard(int flashcardId) {
    return SpacedRepetitionCard(
      flashcardId: flashcardId,
      easeFactor: _initialEaseFactor,
      interval: 0,
      repetitions: 0,
      lapses: 0,
      nextReview: DateTime.now().add(Duration(minutes: _learningIntervals[0])),
      lastReviewed: DateTime.now(),
    );
  }

  /// Get the learning state of a card
  static LearningState getLearningState(SpacedRepetitionCard card) {
    if (card.repetitions == 0) {
      return LearningState.newCard;
    } else if (card.repetitions <= 2) {
      return LearningState.learning;
    } else if (card.lapses > 0 && card.repetitions <= 2) {
      return LearningState.relearning;
    } else {
      return LearningState.reviewing;
    }
  }

  /// Get cards that are due for review
  static List<SpacedRepetitionCard> getDueCards(
    List<SpacedRepetitionCard> cards,
  ) {
    return cards.where((card) => card.isDue).toList();
  }

  /// Get cards that are due today
  static List<SpacedRepetitionCard> getTodayCards(
    List<SpacedRepetitionCard> cards,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    return cards.where((card) {
      if (card.nextReview == null) return true;
      final reviewDate = DateTime(
        card.nextReview!.year,
        card.nextReview!.month,
        card.nextReview!.day,
      );
      return reviewDate.isBefore(today) || reviewDate.isAtSameMomentAs(today);
    }).toList();
  }

  /// Get study statistics
  static Map<String, dynamic> getStudyStats(List<SpacedRepetitionCard> cards) {
    final now = DateTime.now();
    final dueCards = getDueCards(cards);
    final todayCards = getTodayCards(cards);
    
    int newCards = 0;
    int learningCards = 0;
    int reviewCards = 0;
    int relearningCards = 0;
    
    for (final card in cards) {
      final state = getLearningState(card);
      switch (state) {
        case LearningState.newCard:
          newCards++;
          break;
        case LearningState.learning:
          learningCards++;
          break;
        case LearningState.reviewing:
          reviewCards++;
          break;
        case LearningState.relearning:
          relearningCards++;
          break;
      }
    }
    
    return {
      'totalCards': cards.length,
      'dueCards': dueCards.length,
      'todayCards': todayCards.length,
      'newCards': newCards,
      'learningCards': learningCards,
      'reviewCards': reviewCards,
      'relearningCards': relearningCards,
    };
  }
} 