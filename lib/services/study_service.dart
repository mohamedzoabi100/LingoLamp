import '../models/flashcard_model.dart';
import '../models/spaced_repetition_model.dart';
import '../models/study_card_model.dart';
import 'spaced_repetition_service.dart';
import 'xp_event_tracker.dart';
import 'daily_task_service.dart';
import '../models/daily_task_model.dart' as daily_task;

class StudyService {
  /// Create a study session with cards that are due for review
  static List<StudyCard> createStudySession(List<Flashcard> flashcards, List<SpacedRepetitionCard> spacedCards) {
    final Map<int, SpacedRepetitionCard> spacedCardMap = {
      for (var card in spacedCards) card.flashcardId: card
    };
    
    final studyCards = <StudyCard>[];
    
    for (final flashcard in flashcards) {
      final spacedCard = spacedCardMap[flashcard.id];
      final studyCard = StudyCard(
        flashcard: flashcard,
        spacedRepetitionCard: spacedCard,
      );
      
      // Only include cards that are due for review
      if (studyCard.isDue) {
        studyCards.add(studyCard);
      }
    }
    
    // Sort by priority: new cards first, then by next review time
    studyCards.sort((a, b) {
      // New cards first
      if (a.learningState == LearningState.newCard && b.learningState != LearningState.newCard) {
        return -1;
      }
      if (b.learningState == LearningState.newCard && a.learningState != LearningState.newCard) {
        return 1;
      }
      
      // Then by next review time (earliest first)
      if (a.nextReview != null && b.nextReview != null) {
        return a.nextReview!.compareTo(b.nextReview!);
      }
      if (a.nextReview != null) return -1;
      if (b.nextReview != null) return 1;
      
      return 0;
    });
    
    return studyCards;
  }

  /// Process a review and return updated study card
  static Future<StudyCard> processReview(StudyCard studyCard, ReviewQuality quality) async {
    final updatedFlashcard = studyCard.flashcard.markAsStudied();
    
    SpacedRepetitionCard? updatedSpacedCard;
    
    if (studyCard.spacedRepetitionCard != null) {
      // Update existing spaced repetition card
      updatedSpacedCard = SpacedRepetitionService.processReview(
        studyCard.spacedRepetitionCard!,
        quality,
      );
    } else {
      // Create new spaced repetition card
      final newSpacedCard = SpacedRepetitionService.createNewCard(studyCard.flashcard.id!);
      updatedSpacedCard = SpacedRepetitionService.processReview(newSpacedCard, quality);
    }
    
    // Award XP based on quality response
    final xpTracker = XPEventTracker();
    switch (quality) {
      case ReviewQuality.easy:
        xpTracker.addXP(XPEventTracker.flashcardEasy, 'Flashcard review (Easy)');
        break;
      case ReviewQuality.good:
        xpTracker.addXP(XPEventTracker.flashcardGood, 'Flashcard review (Good)');
        break;
      case ReviewQuality.hard:
        xpTracker.addXP(XPEventTracker.flashcardHard, 'Flashcard review (Hard)');
        break;
      case ReviewQuality.again:
        if (XPEventTracker.flashcardAgain > 0) {
          xpTracker.addXP(XPEventTracker.flashcardAgain, 'Flashcard review (Again)');
        }
        break;
    }
    
    // Update daily task progress for flashcard review
    final dailyTaskService = DailyTaskService();
    await dailyTaskService.updateTaskProgress(daily_task.TaskType.reviewFlashcards, 1);
    
    return StudyCard(
      flashcard: updatedFlashcard,
      spacedRepetitionCard: updatedSpacedCard,
    );
  }

  /// Get study statistics for a collection of study cards
  static Map<String, dynamic> getStudyStats(List<StudyCard> studyCards) {
    final spacedCards = studyCards
        .map((card) => card.spacedRepetitionCard)
        .where((card) => card != null)
        .cast<SpacedRepetitionCard>()
        .toList();
    
    return SpacedRepetitionService.getStudyStats(spacedCards);
  }

  /// Get cards due today
  static List<StudyCard> getTodayCards(List<StudyCard> studyCards) {
    final spacedCards = studyCards
        .map((card) => card.spacedRepetitionCard)
        .where((card) => card != null)
        .cast<SpacedRepetitionCard>()
        .toList();
    
    final todaySpacedCards = SpacedRepetitionService.getTodayCards(spacedCards);
    final todaySpacedCardIds = todaySpacedCards.map((card) => card.flashcardId).toSet();
    
    return studyCards.where((card) => 
      card.spacedRepetitionCard == null || 
      todaySpacedCardIds.contains(card.flashcard.id)
    ).toList();
  }

  /// Get cards by category
  static List<StudyCard> getCardsByCategory(List<StudyCard> studyCards, String category) {
    return studyCards.where((card) => card.belongsToCategory(category)).toList();
  }

  /// Get cards by tags
  static List<StudyCard> getCardsByTags(List<StudyCard> studyCards, List<String> tags, {bool requireAll = false}) {
    if (requireAll) {
      return studyCards.where((card) => card.hasAllTags(tags)).toList();
    } else {
      return studyCards.where((card) => card.hasAnyTag(tags)).toList();
    }
  }

  /// Get new cards (cards that haven't been studied yet)
  static List<StudyCard> getNewCards(List<StudyCard> studyCards) {
    return studyCards.where((card) => card.learningState == LearningState.newCard).toList();
  }

  /// Get learning cards (cards in the learning phase)
  static List<StudyCard> getLearningCards(List<StudyCard> studyCards) {
    return studyCards.where((card) => card.learningState == LearningState.learning).toList();
  }

  /// Get review cards (cards in the review phase)
  static List<StudyCard> getReviewCards(List<StudyCard> studyCards) {
    return studyCards.where((card) => card.learningState == LearningState.reviewing).toList();
  }

  /// Get relearning cards (cards that were forgotten)
  static List<StudyCard> getRelearningCards(List<StudyCard> studyCards) {
    return studyCards.where((card) => card.learningState == LearningState.relearning).toList();
  }

  /// Get overdue cards
  static List<StudyCard> getOverdueCards(List<StudyCard> studyCards) {
    return studyCards.where((card) {
      if (card.nextReview == null) return false;
      return card.nextReview!.isBefore(DateTime.now());
    }).toList();
  }

  /// Calculate estimated time to complete a study session
  static int estimateStudyTime(List<StudyCard> studyCards) {
    // Rough estimates: 30 seconds per card
    const int secondsPerCard = 30;
    return studyCards.length * secondsPerCard;
  }

  /// Get a formatted string for estimated study time
  static String getEstimatedStudyTimeText(List<StudyCard> studyCards) {
    final seconds = estimateStudyTime(studyCards);
    if (seconds < 60) {
      return '$seconds seconds';
    } else if (seconds < 3600) {
      final minutes = (seconds / 60).round();
      return '$minutes minutes';
    } else {
      final hours = (seconds / 3600).round();
      return '$hours hours';
    }
  }

  /// Check if a study session is complete (all cards reviewed)
  static bool isStudySessionComplete(List<StudyCard> studyCards) {
    return studyCards.every((card) => !card.isDue);
  }

  /// Get progress percentage for a study session
  static double getStudyProgress(List<StudyCard> allCards, List<StudyCard> remainingCards) {
    if (allCards.isEmpty) return 0.0;
    final completed = allCards.length - remainingCards.length;
    return (completed / allCards.length) * 100;
  }
} 