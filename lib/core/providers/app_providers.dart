import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Auth
import 'auth_provider.dart';

// Features
import 'chat_provider.dart';
import 'flashcard_provider.dart';
import 'phrasebook_provider.dart';
import 'recommendation_provider.dart';
import 'user_provider.dart';
import 'daily_task_provider.dart';
import 'language_provider.dart';

class AppProviders {
  static List<ChangeNotifierProvider> get providers => [
    // Auth provider
    ChangeNotifierProvider<AuthProvider>(
      create: (context) => AuthProvider(),
    ),
    
    // User provider
    ChangeNotifierProvider<UserProvider>(
      create: (context) => UserProvider(),
    ),
    
    // Chat provider
    ChangeNotifierProvider<ChatProvider>(
      create: (context) => ChatProvider(),
    ),
    
    // Flashcard provider
    ChangeNotifierProvider<FlashcardProvider>(
      create: (context) => FlashcardProvider(),
    ),
    
    // Recommendation provider
    ChangeNotifierProvider<RecommendationProvider>(
      create: (context) => RecommendationProvider(),
    ),
    
    // Phrasebook provider
    ChangeNotifierProvider<PhrasebookProvider>(
      create: (context) => PhrasebookProvider(),
    ),
    
    // Daily Task provider
    ChangeNotifierProvider<DailyTaskProvider>(
      create: (context) => DailyTaskProvider(),
    ),
    
    // Language provider
    ChangeNotifierProvider<LanguageProvider>(
      create: (context) => LanguageProvider(),
    ),
  ];

  // Method to clear all provider states when switching accounts
  static void clearAllProviderStates(BuildContext context) {
    try {
      print('[AppProviders] Clearing all provider states...');
      
      // Clear chat provider
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      chatProvider.clear();
      
      // Clear flashcard provider
      final flashcardProvider = Provider.of<FlashcardProvider>(context, listen: false);
      flashcardProvider.clear();
      
      // Clear recommendation provider
      final recommendationProvider = Provider.of<RecommendationProvider>(context, listen: false);
      recommendationProvider.clear();
      
      // Clear phrasebook provider
      final phrasebookProvider = Provider.of<PhrasebookProvider>(context, listen: false);
      phrasebookProvider.clear();
      
      // Clear daily task provider
      final dailyTaskProvider = Provider.of<DailyTaskProvider>(context, listen: false);
      dailyTaskProvider.clear();
      
      // Reset user provider
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      userProvider.setUser(null);
      
      print('[AppProviders] All provider states cleared successfully');
    } catch (e) {
      print('[AppProviders] Error clearing provider states: $e');
    }
  }
} 