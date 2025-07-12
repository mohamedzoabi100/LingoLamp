import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'ai_chat_service.dart';

class DailyMotivation {
  final String spanishQuote;
  final String englishTranslation;
  final DateTime date;

  DailyMotivation({
    required this.spanishQuote,
    required this.englishTranslation,
    required this.date,
  });

  Map<String, dynamic> toJson() {
    return {
      'spanishQuote': spanishQuote,
      'englishTranslation': englishTranslation,
      'date': date.toIso8601String(),
    };
  }

  factory DailyMotivation.fromJson(Map<String, dynamic> json) {
    return DailyMotivation(
      spanishQuote: json['spanishQuote'],
      englishTranslation: json['englishTranslation'],
      date: DateTime.parse(json['date']),
    );
  }
}

class DailyMotivationService {
  static final DailyMotivationService _instance = DailyMotivationService._internal();
  factory DailyMotivationService() => _instance;
  DailyMotivationService._internal();

  static const String _motivationKey = 'daily_motivation';
  static const String _lastMotivationDateKey = 'last_motivation_date';

  // Pre-defined motivational quotes as fallback
  static const List<Map<String, String>> _fallbackQuotes = [
    {
      'spanish': '¡Cada día es una nueva oportunidad para aprender!',
      'english': 'Every day is a new opportunity to learn!'
    },
    {
      'spanish': '¡El éxito viene de la práctica constante!',
      'english': 'Success comes from constant practice!'
    },
    {
      'spanish': '¡Cada palabra nueva te acerca a tus metas!',
      'english': 'Every new word brings you closer to your goals!'
    },
    {
      'spanish': '¡La perseverancia es la clave del aprendizaje!',
      'english': 'Perseverance is the key to learning!'
    },
    {
      'spanish': '¡Hoy es el día perfecto para mejorar!',
      'english': 'Today is the perfect day to improve!'
    },
    {
      'spanish': '¡Cada paso cuenta en tu viaje de aprendizaje!',
      'english': 'Every step counts in your learning journey!'
    },
    {
      'spanish': '¡La práctica hace al maestro!',
      'english': 'Practice makes perfect!'
    },
    {
      'spanish': '¡Tu esfuerzo de hoy construye tu futuro!',
      'english': 'Your effort today builds your future!'
    },
  ];

  /// Get today's motivation quote
  Future<DailyMotivation> getTodayMotivation() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayString = _formatDate(today);
    
    // Check if we need to generate new motivation for today
    final lastMotivationDate = prefs.getString(_lastMotivationDateKey);
    if (lastMotivationDate != todayString) {
      // Generate new motivation for today
      final motivation = await _generateDailyMotivation();
      await _saveMotivation(motivation);
      await prefs.setString(_lastMotivationDateKey, todayString);
      return motivation;
    }

    // Load existing motivation
    final motivationJson = prefs.getString(_motivationKey);
    if (motivationJson != null) {
      try {
        return DailyMotivation.fromJson(jsonDecode(motivationJson));
      } catch (e) {
        print('Error loading motivation: $e');
      }
    }

    // Fallback: generate new motivation
    final motivation = await _generateDailyMotivation();
    await _saveMotivation(motivation);
    await prefs.setString(_lastMotivationDateKey, todayString);
    return motivation;
  }

  /// Generate daily motivation using AI or fallback
  Future<DailyMotivation> _generateDailyMotivation() async {
    try {
      // Try to generate with AI - use a single instance to avoid conflicts
      final aiService = AiChatService();
      
      // Create a more diverse and random prompt
      final randomThemes = [
        'learning progress',
        'overcoming challenges', 
        'daily practice',
        'language confidence',
        'personal growth',
        'achieving goals',
        'staying motivated',
        'building skills',
        'embracing mistakes',
        'celebrating small wins'
      ];
      
      final randomEmotions = [
        'energetic',
        'calm and focused',
        'determined',
        'optimistic',
        'confident',
        'inspired',
        'resilient',
        'enthusiastic'
      ];
      
      final randomTone = [
        'encouraging',
        'inspiring',
        'motivational',
        'uplifting',
        'empowering',
        'positive'
      ];
      
      final selectedTheme = randomThemes[DateTime.now().millisecondsSinceEpoch % randomThemes.length];
      final selectedEmotion = randomEmotions[DateTime.now().millisecondsSinceEpoch % randomEmotions.length];
      final selectedTone = randomTone[DateTime.now().millisecondsSinceEpoch % randomTone.length];
      
      final prompt = '''
Generate a unique, ${selectedTone} quote in Spanish for language learners. 
Focus on the theme of ${selectedTheme} with a ${selectedEmotion} feeling.
Make it completely different from typical motivational quotes.
Keep it simple, under 60 characters, and very specific to language learning.

Format your response exactly like this:
SPANISH: [the Spanish quote]
ENGLISH: [the English translation]

Be creative and avoid generic phrases. Make it feel personal and unique.
''';

      // Use direct model call to avoid chat session conflicts
      final response = await aiService.sendMessage(prompt, useSystemPrompt: false);
      
      if (response != null && response.isNotEmpty) {
        final parsed = _parseMotivationResponse(response);
        if (parsed != null) {
          return parsed;
        }
      }
    } catch (e) {
      print('AI motivation generation failed: $e');
      // Don't rethrow - fall back to pre-defined quotes
    }

    // Enhanced fallback with more variety
    final random = DateTime.now().millisecondsSinceEpoch % _fallbackQuotes.length;
    final quote = _fallbackQuotes[random];
    
    return DailyMotivation(
      spanishQuote: quote['spanish']!,
      englishTranslation: quote['english']!,
      date: DateTime.now(),
    );
  }

  /// Parse AI response for motivation
  DailyMotivation? _parseMotivationResponse(String response) {
    try {
      final cleanResponse = response.trim();
      
      final spanishMatch = RegExp(r'SPANISH:\s*(.+)', caseSensitive: false).firstMatch(cleanResponse);
      final englishMatch = RegExp(r'ENGLISH:\s*(.+)', caseSensitive: false).firstMatch(cleanResponse);
      
      if (spanishMatch != null && englishMatch != null) {
        final spanish = spanishMatch.group(1)?.trim() ?? '';
        final english = englishMatch.group(1)?.trim() ?? '';
        
        if (spanish.isNotEmpty && english.isNotEmpty) {
          return DailyMotivation(
            spanishQuote: spanish,
            englishTranslation: english,
            date: DateTime.now(),
          );
        }
      }
      
      return null;
    } catch (e) {
      print('Error parsing motivation response: $e');
      return null;
    }
  }

  /// Save motivation to local storage
  Future<void> _saveMotivation(DailyMotivation motivation) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_motivationKey, jsonEncode(motivation.toJson()));
  }

  /// Format date for consistent comparison
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
} 