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

  Future<List<Map<String, String>>> generatePhrasesForTopic(String topic, {required String languageCode}) async {
    final languageName = _getLanguageName(languageCode);
    final prompt = "Generate 5 common phrases for a tourist related to '$topic'. The response should be a list of English:$languageName pairs, one per line.";
    final response = await _aiChatService.sendMessage(prompt, useSystemPrompt: false, languageCode: languageCode);
    debugPrint("AI Response for '$topic':\n$response");
    return _parsePhrasesFromResponse(response, languageCode);
  }
  
  Future<List<Map<String, String>>> generateMorePhrasesForTopic(String topic, List<PhraseModel> existingPhrases, {required String languageCode}) async {
    final languageName = _getLanguageName(languageCode);
    final existingPhrasesString = existingPhrases.map((p) => '- ${p.english}').join('\n');
    final prompt = "Generate 5 more common phrases for a tourist related to '$topic', avoiding repetition of the following:\n$existingPhrasesString\nThe response should be a list of English:$languageName pairs, one per line.";
    final response = await _aiChatService.sendMessage(prompt, useSystemPrompt: false, languageCode: languageCode);
    debugPrint("AI Response for 'more $topic':\n$response");
    return _parsePhrasesFromResponse(response, languageCode);
  }

  List<PhraseModel> aiPhrasesToPhraseModels({
    required List<Map<String, String>> aiPhrases, 
    required String category,
    required String languageCode,
  }) {
    return aiPhrases.map((phraseMap) {
      final english = phraseMap['english']!;
      final translation = phraseMap['translation']!;
      return PhraseModel(
        id: 'ai_${english.hashCode}_${translation.hashCode}_$languageCode',
        english: english,
        translation: translation,
        category: category,
        difficulty: 'beginner',
        createdAt: DateTime.now(),
        isAiGenerated: true,
        languageCode: languageCode,
      );
    }).toList();
  }

  List<Map<String, String>> _parsePhrasesFromResponse(String response, String languageCode) {
    final phrases = <Map<String, String>>[];
    final lines = response.split('\n');
    for (final line in lines) {
      if (line.contains(':')) {
        final parts = line.split(':');
        if (parts.length >= 2) {
          final english = parts[0].replaceAll(RegExp(r'^\d+\.\s*'), '').trim();
          final translation = parts.sublist(1).join(':').trim();
          if (english.isNotEmpty && translation.isNotEmpty) {
            phrases.add({'english': english, 'translation': translation});
          }
        }
      }
    }
    if (phrases.isEmpty && response.isNotEmpty) {
      debugPrint("Failed to parse any phrases from AI response.");
    }
    return phrases;
  }

  String _getLanguageName(String languageCode) {
    final languageNames = {
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
      'it': 'Italian',
      'pt': 'Portuguese',
    };
    return languageNames[languageCode] ?? 'Spanish';
  }

  /// Generate a new phrase using AI
  /// Returns null if generation fails
  Future<PhraseModel?> generatePhrase({
    String? topic,
    String? difficulty = 'beginner',
    String? context,
    required String languageCode,
  }) async {
    try {
      // 🆕 Improved prompt engineering
      final prompt = _buildPrompt(topic: topic, difficulty: difficulty, context: context, languageCode: languageCode);
      
      // 🆕 Add retry logic
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          final response = await _aiChatService.sendMessage(prompt, useSystemPrompt: false, languageCode: languageCode);
          
          if (response != null && response.isNotEmpty) {
            // 🆕 Improved parsing with better error handling
            final phrase = _parsePhraseResponse(response, languageCode, topic: topic);
                      if (phrase != null) {
            print('✅ AI phrase generated successfully: ${phrase.english}');
            
            // Award XP for generating a new phrase
            final xpTracker = XPEventTracker();
            xpTracker.addXP(XPEventTracker.phraseLearned, 'New phrase generated');
            
            // Update daily task progress for learning phrases
            final dailyTaskService = DailyTaskService();
            await dailyTaskService.updateTaskProgress(daily_task.TaskType.learnPhrases, 1, languageCode: languageCode);
            
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
    required String languageCode,
  }) {
    final languageName = _getLanguageName(languageCode);
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
$languageName: [the $languageName translation]

Example:
ENGLISH: How are you today?
$languageName: ${_getExampleTranslation(languageCode)}

Now generate your phrase:
''';
  }

  String _getExampleTranslation(String languageCode) {
    final examples = {
      'es': '¿Cómo estás hoy?',
      'fr': 'Comment allez-vous aujourd\'hui?',
      'de': 'Wie geht es dir heute?',
      'it': 'Come stai oggi?',
      'pt': 'Como você está hoje?',
    };
    return examples[languageCode] ?? '¿Cómo estás hoy?';
  }

  /// 🆕 Improved response parsing
  PhraseModel? _parsePhraseResponse(String response, String languageCode, {String? topic}) {
    try {
      // Clean up the response
      final cleanResponse = response.trim();
      final languageName = _getLanguageName(languageCode);
      
      // Look for the pattern
      final englishMatch = RegExp(r'ENGLISH:\s*(.+)', caseSensitive: false).firstMatch(cleanResponse);
      final translationMatch = RegExp(r'$languageName:\s*(.+)', caseSensitive: false).firstMatch(cleanResponse);
      
      if (englishMatch != null && translationMatch != null) {
        final english = englishMatch.group(1)?.trim() ?? '';
        final translation = translationMatch.group(1)?.trim() ?? '';
        
        // Validate the phrases
        if (english.isNotEmpty && translation.isNotEmpty && 
            english.length > 2 && translation.length > 2) {
          return PhraseModel(
            id: 'ai_${DateTime.now().millisecondsSinceEpoch}_${english.hashCode}_${translation.hashCode}_$languageCode',
            english: english,
            translation: translation,
            category: topic ?? 'AI Generated',
            difficulty: 'beginner',
            createdAt: DateTime.now(),
            isFavorite: false,
            isAiGenerated: true,
            languageCode: languageCode,
          );
        }
      }
      
      // 🆕 Fallback parsing for different formats
      final lines = cleanResponse.split('\n');
      String? english, translation;
      
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('ENGLISH:') || trimmed.startsWith('English:')) {
          english = trimmed.substring(trimmed.indexOf(':') + 1).trim();
        } else if (trimmed.startsWith('$languageName:') || trimmed.startsWith('${languageName.toLowerCase()}:')) {
          translation = trimmed.substring(trimmed.indexOf(':') + 1).trim();
        }
      }
      
      if (english != null && translation != null && 
          english.isNotEmpty && translation.isNotEmpty) {
        return PhraseModel(
          id: 'ai_${DateTime.now().millisecondsSinceEpoch}_${english.hashCode}_${translation.hashCode}_$languageCode',
          english: english,
          translation: translation,
          category: topic ?? 'AI Generated',
          difficulty: 'beginner',
          createdAt: DateTime.now(),
          isFavorite: false,
          isAiGenerated: true,
          languageCode: languageCode,
        );
      }
      
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
    required String languageCode,
  }) async {
    final phrases = <PhraseModel>[];
    
    for (int i = 0; i < count; i++) {
      final phrase = await generatePhrase(
        topic: topic,
        difficulty: difficulty,
        languageCode: languageCode,
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