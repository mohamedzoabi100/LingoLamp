import 'package:flutter_test/flutter_test.dart';
import 'package:lingolampmainpage/models/spaced_repetition_model.dart';
import 'package:lingolampmainpage/services/spaced_repetition_service.dart';

void main() {
  group('SpacedRepetitionService – SM-2 scheduling', () {
    test('Good on new card schedules 10-minute learn step', () {
      final card = SpacedRepetitionCard(
        flashcardId: 1,
        easeFactor: 2.5,
        interval: 0,
        repetitions: 0,
        lapses: 0,
        nextReview: DateTime.now(),
        lastReviewed: DateTime.now(),
      );

      final updated = SpacedRepetitionService.processReview(card, ReviewQuality.good);

      expect(updated.repetitions, 1);
      // First learning step → 10-minute interval (in minutes)
      expect(updated.interval, 10);
      expect(updated.nextReview!.difference(card.lastReviewed).inMinutes, 10);
    });

    test('Good on learning step 2 graduates to 1-day interval', () {
      final card = SpacedRepetitionCard(
        flashcardId: 1,
        easeFactor: 2.5,
        interval: 10,
        repetitions: 1, // already passed first step
        lapses: 0,
        nextReview: DateTime.now(),
        lastReviewed: DateTime.now(),
      );
      final updated = SpacedRepetitionService.processReview(card, ReviewQuality.good);
      expect(updated.repetitions, 2);
      expect(updated.interval, 1440); // minutes in 1 day
    });

    test('Good on review card multiplies by ease factor', () {
      final intervalDays = 10; // store in minutes *for service*? actually service uses minutes; we convert
      final card = SpacedRepetitionCard(
        flashcardId: 1,
        easeFactor: 2.5,
        interval: intervalDays, // service interprets as minutes but for review we can set > learning limit
        repetitions: 3,
        lapses: 0,
        nextReview: DateTime.now(),
        lastReviewed: DateTime.now(),
      );
      final updated = SpacedRepetitionService.processReview(card, ReviewQuality.good);
      expect(updated.repetitions, 4);
      // Because interval * easeFactor -> 10 * 2.5 = 25 (minutes)
      expect(updated.interval, (intervalDays * 2.5).round());
    });

    test('Again resets card and increments lapses', () {
      final card = SpacedRepetitionCard(
        flashcardId: 1,
        easeFactor: 2.5,
        interval: 1440,
        repetitions: 3,
        lapses: 0,
        nextReview: DateTime.now(),
        lastReviewed: DateTime.now(),
      );
      final updated = SpacedRepetitionService.processReview(card, ReviewQuality.again);
      expect(updated.repetitions, 0);
      expect(updated.lapses, 1);
      expect(updated.interval, 0);
      expect(updated.nextReview!.isAfter(card.lastReviewed), isTrue);
    });
  });
} 