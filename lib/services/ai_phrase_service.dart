import 'package:flutter/foundation.dart';
import '../models/phrase_model.dart';
import 'ai_chat_service.dart';
import 'xp_event_tracker.dart';
import 'daily_task_service.dart';
import '../models/daily_task_model.dart' as daily_task;

class AiPhraseService {
  static final AiPhraseService _instance = AiPhraseService._internal();
  factory AiPhraseService() => _instance;
  AiPhraseService._internal();

  final AiChatService _aiChatService = AiChatService();

  List<String> getPopularTopics() {
    return ['Travel', 'Dining', 'Shopping', 'Business', 'Emergency'];
  }

  Future<List<Map<String, String>>> generatePhrasesForTopic(String topic) async {
    final prompt = "Generate 5 common phrases for a tourist related to '$topic'. The response should be a list of English:Spanish pairs, one per line.";
    final response = await _aiChatService.sendMessage(prompt, useSystemPrompt: false);
    debugPrint("AI Response for '$topic':\n$response");
    return _parsePhrasesFromResponse(response);
  }
  
  Future<List<Map<String, String>>> generateMorePhrasesForTopic(String topic, List<PhraseModel> existingPhrases) async {
    final existingPhrasesString = existingPhrases.map((p) => '- ${p.english}').join('\n');
    final prompt = "Generate 5 more common phrases for a tourist related to '$topic', avoiding repetition of the following:\n$existingPhrasesString\nThe response should be a list of English:Spanish pairs, one per line.";
    final response = await _aiChatService.sendMessage(prompt, useSystemPrompt: false);
    debugPrint("AI Response for 'more $topic':\n$response");
    return _parsePhrasesFromResponse(response);
  }

  List<PhraseModel> aiPhrasesToPhraseModels({
    required List<Map<String, String>> aiPhrases, 
    required String category,
  }) {
    return aiPhrases.map((phraseMap) {
      final english = phraseMap['english']!;
      final spanish = phraseMap['spanish']!;
      return PhraseModel(
        id: 'ai_${english.hashCode}_${spanish.hashCode}',
        english: english,
        spanish: spanish,
        category: category,
        difficulty: 'beginner',
        createdAt: DateTime.now(),
        isAiGenerated: true,
      );
    }).toList();
  }

  List<Map<String, String>> _parsePhrasesFromResponse(String response) {
    final phrases = <Map<String, String>>[];
    final lines = response.split('\n');
    for (final line in lines) {
      if (line.contains(':')) {
        final parts = line.split(':');
        if (parts.length >= 2) {
          final english = parts[0].replaceAll(RegExp(r'^\d+\.\s*'), '').trim();
          final spanish = parts.sublist(1).join(':').trim();
          if (english.isNotEmpty && spanish.isNotEmpty) {
            phrases.add({'english': english, 'spanish': spanish});
          }
        }
      }
    }
    if (phrases.isEmpty && response.isNotEmpty) {
      debugPrint("Failed to parse any phrases from AI response.");
    }
    return phrases;
  }

  /// Generate a new phrase using AI
  /// Returns null if generation fails
  Future<PhraseModel?> generatePhrase({
    String? topic,
    String? difficulty = 'beginner',
    String? context,
  }) async {
    try {
      // 🆕 Improved prompt engineering
      final prompt = _buildPrompt(topic: topic, difficulty: difficulty, context: context);
      
      // 🆕 Add retry logic
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          final response = await _aiChatService.sendMessage(prompt, useSystemPrompt: false);
          
          if (response != null && response.isNotEmpty) {
            // 🆕 Improved parsing with better error handling
            final phrase = _parsePhraseResponse(response);
                      if (phrase != null) {
            print('✅ AI phrase generated successfully: ${phrase.english}');
            
            // Award XP for generating a new phrase
            final xpTracker = XPEventTracker();
            xpTracker.addXP(XPEventTracker.phraseLearned, 'New phrase generated');
            
            // Update daily task progress for learning phrases
            final dailyTaskService = DailyTaskService();
            await dailyTaskService.updateTaskProgress(daily_task.TaskType.learnPhrases, 1);
            
            return phrase;
          }
          }
          
          print('⚠️ Attempt $attempt: Invalid response format');
          if (attempt < 3) {
            await Future.delayed(Duration(seconds: attempt)); // Exponential backoff
          }
        } catch (e) {
          print('❌ Attempt $attempt failed: $e');
          if (attempt < 3) {
            await Future.delayed(Duration(seconds: attempt));
          }
        }
      }
      
      print('❌ All attempts failed to generate phrase');
      return null;
    } catch (e) {
      print('❌ Error in generatePhrase: $e');
      return null;
    }
  }

  /// 🆕 Improved prompt building
  String _buildPrompt({
    String? topic,
    String? difficulty,
    String? context,
  }) {
    final topicText = topic?.isNotEmpty == true ? ' about $topic' : '';
    final contextText = context?.isNotEmpty == true ? ' in the context of: $context' : '';
    final difficultyText = difficulty?.isNotEmpty == true ? ' at $difficulty level' : '';
    
    return '''
Generate a useful English phrase$topicText$difficultyText$contextText.

Requirements:
- The phrase should be practical and commonly used
- Keep it simple and natural
- Make sure it's appropriate for language learning

Please respond with ONLY the phrase in this exact format:
ENGLISH: [the English phrase]
SPANISH: [the Spanish translation]

Example:
ENGLISH: How are you today?
SPANISH: ¿Cómo estás hoy?

Now generate your phrase:
''';
  }

  /// 🆕 Improved response parsing
  PhraseModel? _parsePhraseResponse(String response) {
    try {
      // Clean up the response
      final cleanResponse = response.trim();
      
      // Look for the pattern
      final englishMatch = RegExp(r'ENGLISH:\s*(.+)', caseSensitive: false).firstMatch(cleanResponse);
      final spanishMatch = RegExp(r'SPANISH:\s*(.+)', caseSensitive: false).firstMatch(cleanResponse);
      
      if (englishMatch != null && spanishMatch != null) {
        final english = englishMatch.group(1)?.trim() ?? '';
        final spanish = spanishMatch.group(1)?.trim() ?? '';
        
        // Validate the phrases
        if (english.isNotEmpty && spanish.isNotEmpty && 
            english.length > 2 && spanish.length > 2) {
          return PhraseModel(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            english: english,
            spanish: spanish,
            category: 'AI Generated',
            difficulty: 'beginner',
            createdAt: DateTime.now(),
            isFavorite: false,
            isAiGenerated: true,
          );
        }
      }
      
      // 🆕 Fallback parsing for different formats
      final lines = cleanResponse.split('\n');
      String? english, spanish;
      
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('ENGLISH:') || trimmed.startsWith('English:')) {
          english = trimmed.substring(trimmed.indexOf(':') + 1).trim();
        } else if (trimmed.startsWith('SPANISH:') || trimmed.startsWith('Spanish:')) {
          spanish = trimmed.substring(trimmed.indexOf(':') + 1).trim();
        }
      }
      
      if (english != null && spanish != null && 
          english.isNotEmpty && spanish.isNotEmpty) {
        return PhraseModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          english: english,
          spanish: spanish,
          category: 'AI Generated',
          difficulty: 'beginner',
          createdAt: DateTime.now(),
          isFavorite: false,
          isAiGenerated: true,
        );
      }
      
      print('⚠️ Could not parse response: $cleanResponse');
      return null;
    } catch (e) {
      print('❌ Error parsing phrase response: $e');
      return null;
    }
  }

  /// 🆕 Generate multiple phrases at once
  Future<List<PhraseModel>> generateMultiplePhrases({
    int count = 5,
    String? topic,
    String? difficulty = 'beginner',
  }) async {
    final phrases = <PhraseModel>[];
    
    for (int i = 0; i < count; i++) {
      final phrase = await generatePhrase(
        topic: topic,
        difficulty: difficulty,
      );
      
      if (phrase != null) {
        phrases.add(phrase);
      }
      
      // Add delay between requests to avoid rate limiting
      if (i < count - 1) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    
    return phrases;
  }

  /// 🆕 Translate text to Spanish with fallback handling
  Future<String> translateToSpanish(String text) async {
    try {
      final response = await _aiChatService.sendMessage(
        'Translate "$text" to Spanish. Respond with only the Spanish translation.'
      );
      
      if (response != null && response.trim().isNotEmpty) {
        return response.trim();
      }
      
      // Fallback: try simpler prompt
      final fallbackResponse = await _aiChatService.sendMessage(
        'Translate to Spanish: $text'
      );
      
      if (fallbackResponse != null && fallbackResponse.trim().isNotEmpty) {
        return fallbackResponse.trim();
      }
      
      return text; // Return original if translation fails
    } catch (e) {
      print('❌ Translation error: $e');
      return text; // Return original text if translation fails
    }
  }
}