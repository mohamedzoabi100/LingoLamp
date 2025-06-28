import 'package:flutter_test/flutter_test.dart';
import 'package:lingolampmainpage/models/spaced_repetition_model.dart';
import 'package:lingolampmainpage/services/spaced_repetition_service.dart';

void main() {
  group('SpacedRepetitionService Tests', () {
    test('should create new card with correct initial values', () {
      final card = SpacedRepetitionService.createNewCard(1);
      
      expect(card.flashcardId, 1);
      expect(card.easeFactor, 2.5);
      expect(card.interval, 0);
      expect(card.repetitions, 0);
      expect(card.lapses, 0);
      expect(card.nextReview, isNotNull);
    });

    test('should process "Again" review correctly', () {
      final card = SpacedRepetitionService.createNewCard(1);
      final updatedCard = SpacedRepetitionService.processReview(card, ReviewQuality.again);
      
      expect(updatedCard.easeFactor, 2.35); // 2.5 - 0.15
      expect(updatedCard.interval, 0);
      expect(updatedCard.repetitions, 0);
      expect(updatedCard.lapses, 1);
      expect(updatedCard.lastReviewQuality, ReviewQuality.again);
    });

    test('should process "Good" review correctly for new card', () {
      final card = SpacedRepetitionService.createNewCard(1);
      final updatedCard = SpacedRepetitionService.processReview(card, ReviewQuality.good);
      
      expect(updatedCard.easeFactor, 2.5); // Should remain unchanged
      expect(updatedCard.interval, 10); // 10 minutes
      expect(updatedCard.repetitions, 1);
      expect(updatedCard.lapses, 0);
      expect(updatedCard.lastReviewQuality, ReviewQuality.good);
    });

    test('should process "Easy" review correctly for new card', () {
      final card = SpacedRepetitionService.createNewCard(1);
      final updatedCard = SpacedRepetitionService.processReview(card, ReviewQuality.easy);
      
      expect(updatedCard.easeFactor, 2.6); // 2.5 + 0.1
      expect(updatedCard.interval, 1440); // 1 day
      expect(updatedCard.repetitions, 1);
      expect(updatedCard.lapses, 0);
      expect(updatedCard.lastReviewQuality, ReviewQuality.easy);
    });

    test('should process "Good" review correctly for reviewing card', () {
      // Create a card that's already in review phase
      final card = SpacedRepetitionCard(
        flashcardId: 1,
        easeFactor: 2.5,
        interval: 10,
        repetitions: 3,
        lapses: 0,
        nextReview: DateTime.now(),
        lastReviewed: DateTime.now(),
      );
      
      final updatedCard = SpacedRepetitionService.processReview(card, ReviewQuality.good);
      
      expect(updatedCard.easeFactor, 2.5); // Should remain unchanged
      expect(updatedCard.interval, 25); // 10 * 2.5
      expect(updatedCard.repetitions, 4);
      expect(updatedCard.lapses, 0);
      expect(updatedCard.lastReviewQuality, ReviewQuality.good);
    });

    test('should handle ease factor minimum limit', () {
      final card = SpacedRepetitionCard(
        flashcardId: 1,
        easeFactor: 1.3, // At minimum
        interval: 10,
        repetitions: 3,
        lapses: 0,
        nextReview: DateTime.now(),
        lastReviewed: DateTime.now(),
      );
      
      final updatedCard = SpacedRepetitionService.processReview(card, ReviewQuality.again);
      
      expect(updatedCard.easeFactor, 1.3); // Should not go below minimum
      expect(updatedCard.lapses, 1);
    });

    test('should get correct learning state', () {
      final newCard = SpacedRepetitionService.createNewCard(1);
      expect(SpacedRepetitionService.getLearningState(newCard), LearningState.newCard);
      
      final learningCard = SpacedRepetitionCard(
        flashcardId: 1,
        easeFactor: 2.5,
        interval: 10,
        repetitions: 1,
        lapses: 0,
        nextReview: DateTime.now(),
        lastReviewed: DateTime.now(),
      );
      expect(SpacedRepetitionService.getLearningState(learningCard), LearningState.learning);
      
      final reviewCard = SpacedRepetitionCard(
        flashcardId: 1,
        easeFactor: 2.5,
        interval: 10,
        repetitions: 3,
        lapses: 0,
        nextReview: DateTime.now(),
        lastReviewed: DateTime.now(),
      );
      expect(SpacedRepetitionService.getLearningState(reviewCard), LearningState.reviewing);
    });

    test('should check if card is due correctly', () {
      final pastCard = SpacedRepetitionCard(
        flashcardId: 1,
        easeFactor: 2.5,
        interval: 10,
        repetitions: 1,
        lapses: 0,
        nextReview: DateTime.now().subtract(Duration(days: 1)),
        lastReviewed: DateTime.now(),
      );
      expect(pastCard.isDue, true);
      
      final futureCard = SpacedRepetitionCard(
        flashcardId: 1,
        easeFactor: 2.5,
        interval: 10,
        repetitions: 1,
        lapses: 0,
        nextReview: DateTime.now().add(Duration(days: 1)),
        lastReviewed: DateTime.now(),
      );
      expect(futureCard.isDue, false);
    });
  });
} 