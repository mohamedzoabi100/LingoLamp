import 'flashcard_model.dart';
import 'spaced_repetition_model.dart';
import '../services/spaced_repetition_service.dart';

/// A combined model representing a flashcard with its spaced repetition data
class StudyCard {
  final Flashcard flashcard;
  final SpacedRepetitionCard? spacedRepetitionCard;
  final LearningState learningState;

  StudyCard({
    required this.flashcard,
    this.spacedRepetitionCard,
  }) : learningState = spacedRepetitionCard != null 
      ? SpacedRepetitionService.getLearningState(spacedRepetitionCard!)
      : LearningState.newCard;

  /// Check if the card is due for review
  bool get isDue {
    return spacedRepetitionCard?.isDue ?? true;
  }

  /// Get the number of days until next review
  int get daysUntilReview {
    return spacedRepetitionCard?.daysUntilReview ?? 0;
  }

  /// Get the ease factor
  double get easeFactor {
    return spacedRepetitionCard?.easeFactor ?? 2.5;
  }

  /// Get the current interval
  int get interval {
    return spacedRepetitionCard?.interval ?? 0;
  }

  /// Get the number of repetitions
  int get repetitions {
    return spacedRepetitionCard?.repetitions ?? 0;
  }

  /// Get the number of lapses
  int get lapses {
    return spacedRepetitionCard?.lapses ?? 0;
  }

  /// Get the next review date
  DateTime? get nextReview {
    return spacedRepetitionCard?.nextReview;
  }

  /// Get the last review quality
  ReviewQuality? get lastReviewQuality {
    return spacedRepetitionCard?.lastReviewQuality;
  }

  /// Get a formatted string for the next review
  String get nextReviewText {
    if (nextReview == null) return 'Due now';
    
    final now = DateTime.now();
    final difference = nextReview!.difference(now);
    
    if (difference.isNegative) {
      return 'Overdue';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} days';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes';
    } else {
      return 'Due now';
    }
  }

  /// Get a formatted string for the learning state
  String get learningStateText {
    switch (learningState) {
      case LearningState.newCard:
        return 'New';
      case LearningState.learning:
        return 'Learning';
      case LearningState.reviewing:
        return 'Review';
      case LearningState.relearning:
        return 'Relearning';
    }
  }

  /// Get the color for the learning state (for UI)
  String get learningStateColor {
    switch (learningState) {
      case LearningState.newCard:
        return '#FF6B6B'; // Red
      case LearningState.learning:
        return '#4ECDC4'; // Teal
      case LearningState.reviewing:
        return '#45B7D1'; // Blue
      case LearningState.relearning:
        return '#FFA07A'; // Orange
    }
  }

  /// Create a new study card with updated spaced repetition data
  StudyCard updateSpacedRepetition(SpacedRepetitionCard newSpacedCard) {
    return StudyCard(
      flashcard: flashcard,
      spacedRepetitionCard: newSpacedCard,
    );
  }

  /// Create a new study card with updated flashcard data
  StudyCard updateFlashcard(Flashcard newFlashcard) {
    return StudyCard(
      flashcard: newFlashcard,
      spacedRepetitionCard: spacedRepetitionCard,
    );
  }

  /// Check if this card belongs to a specific category
  bool belongsToCategory(String category) {
    return flashcard.category == category;
  }

  /// Check if this card has any of the specified tags
  bool hasAnyTag(List<String> tags) {
    return tags.any((tag) => flashcard.hasTag(tag));
  }

  /// Check if this card has all of the specified tags
  bool hasAllTags(List<String> tags) {
    return tags.every((tag) => flashcard.hasTag(tag));
  }
} 