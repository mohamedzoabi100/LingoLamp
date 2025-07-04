import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lingolampmainpage/services/recommendation_service.dart';
import 'package:lingolampmainpage/models/recommended_flashcard_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('RecommendationService Tests', () {
    late RecommendationService recommendationService;

    setUp(() async {
      // Clear SharedPreferences before each test
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      recommendationService = RecommendationService();
    });

    test('should track dismissed recommendations', () async {
      // Test dismissing a recommendation
      await recommendationService.dismissRecommendation('hello');
      await recommendationService.dismissRecommendation('world');
      
      // Verify they are tracked
      final prefs = await SharedPreferences.getInstance();
      final dismissedList = prefs.getStringList('dismissed_recommendations') ?? [];
      
      expect(dismissedList, contains('hello'));
      expect(dismissedList, contains('world'));
      expect(dismissedList.length, equals(2));
    });

    test('should clear dismissed recommendations', () async {
      // Add some dismissed recommendations
      await recommendationService.dismissRecommendation('test1');
      await recommendationService.dismissRecommendation('test2');
      
      // Clear them
      await recommendationService.clearDismissedRecommendations();
      
      // Verify they are cleared
      final prefs = await SharedPreferences.getInstance();
      final dismissedList = prefs.getStringList('dismissed_recommendations') ?? [];
      
      expect(dismissedList, isEmpty);
    });

    test('should persist dismissed recommendations across instances', () async {
      // Dismiss with first instance
      await recommendationService.dismissRecommendation('persistent');
      
      // Create new instance
      final newInstance = RecommendationService();
      
      // Verify the dismissed recommendation is still tracked
      final prefs = await SharedPreferences.getInstance();
      final dismissedList = prefs.getStringList('dismissed_recommendations') ?? [];
      
      expect(dismissedList, contains('persistent'));
    });
  });
} 