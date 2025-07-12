import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

class DailyMotivation {
  final String quote;
  final String englishTranslation;
  final String languageCode;
  final DateTime date;

  DailyMotivation({
    required this.quote,
    required this.englishTranslation,
    required this.languageCode,
    required this.date,
  });

  // Legacy getter for backward compatibility
  String get spanishQuote => quote;

  Map<String, dynamic> toJson() {
    return {
      'quote': quote,
      'englishTranslation': englishTranslation,
      'languageCode': languageCode,
      'date': date.toIso8601String(),
    };
  }

  factory DailyMotivation.fromJson(Map<String, dynamic> json) {
    return DailyMotivation(
      quote: json['quote'] ?? json['spanishQuote'] ?? '', // Backward compatibility
      englishTranslation: json['englishTranslation'],
      languageCode: json['languageCode'] ?? 'es', // Default to Spanish for backward compatibility
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

  // Pre-defined motivational quotes for different languages
  static const Map<String, List<Map<String, String>>> _languageQuotes = {
    'es': [
      {
        'quote': '¡Cada día es una nueva oportunidad para aprender!',
        'english': 'Every day is a new opportunity to learn!'
      },
      {
        'quote': '¡El éxito viene de la práctica constante!',
        'english': 'Success comes from constant practice!'
      },
      {
        'quote': '¡Cada palabra nueva te acerca a tus metas!',
        'english': 'Every new word brings you closer to your goals!'
      },
      {
        'quote': '¡La perseverancia es la clave del aprendizaje!',
        'english': 'Perseverance is the key to learning!'
      },
      {
        'quote': '¡Hoy es el día perfecto para mejorar!',
        'english': 'Today is the perfect day to improve!'
      },
    ],
    'fr': [
      {
        'quote': 'Chaque jour est une nouvelle opportunité d\'apprendre !',
        'english': 'Every day is a new opportunity to learn!'
      },
      {
        'quote': 'Le succès vient de la pratique constante !',
        'english': 'Success comes from constant practice!'
      },
      {
        'quote': 'Chaque nouveau mot te rapproche de tes objectifs !',
        'english': 'Every new word brings you closer to your goals!'
      },
      {
        'quote': 'La persévérance est la clé de l\'apprentissage !',
        'english': 'Perseverance is the key to learning!'
      },
      {
        'quote': 'Aujourd\'hui est le jour parfait pour s\'améliorer !',
        'english': 'Today is the perfect day to improve!'
      },
    ],
    'de': [
      {
        'quote': 'Jeder Tag ist eine neue Gelegenheit zu lernen!',
        'english': 'Every day is a new opportunity to learn!'
      },
      {
        'quote': 'Erfolg kommt durch ständige Übung!',
        'english': 'Success comes from constant practice!'
      },
      {
        'quote': 'Jedes neue Wort bringt dich deinen Zielen näher!',
        'english': 'Every new word brings you closer to your goals!'
      },
      {
        'quote': 'Beharrlichkeit ist der Schlüssel zum Lernen!',
        'english': 'Perseverance is the key to learning!'
      },
      {
        'quote': 'Heute ist der perfekte Tag, um sich zu verbessern!',
        'english': 'Today is the perfect day to improve!'
      },
    ],
    'it': [
      {
        'quote': 'Ogni giorno è una nuova opportunità per imparare!',
        'english': 'Every day is a new opportunity to learn!'
      },
      {
        'quote': 'Il successo viene dalla pratica costante!',
        'english': 'Success comes from constant practice!'
      },
      {
        'quote': 'Ogni nuova parola ti avvicina ai tuoi obiettivi!',
        'english': 'Every new word brings you closer to your goals!'
      },
      {
        'quote': 'La perseveranza è la chiave dell\'apprendimento!',
        'english': 'Perseverance is the key to learning!'
      },
      {
        'quote': 'Oggi è il giorno perfetto per migliorare!',
        'english': 'Today is the perfect day to improve!'
      },
    ],
    'pt': [
      {
        'quote': 'Cada dia é uma nova oportunidade para aprender!',
        'english': 'Every day is a new opportunity to learn!'
      },
      {
        'quote': 'O sucesso vem da prática constante!',
        'english': 'Success comes from constant practice!'
      },
      {
        'quote': 'Cada palavra nova te aproxima dos seus objetivos!',
        'english': 'Every new word brings you closer to your goals!'
      },
      {
        'quote': 'A perseverança é a chave do aprendizado!',
        'english': 'Perseverance is the key to learning!'
      },
      {
        'quote': 'Hoje é o dia perfeito para melhorar!',
        'english': 'Today is the perfect day to improve!'
      },
    ],
  };

  // Fallback quotes (Spanish) for backward compatibility
  static const List<Map<String, String>> _fallbackQuotes = [
    {
      'quote': '¡Cada día es una nueva oportunidad para aprender!',
      'english': 'Every day is a new opportunity to learn!'
    },
    {
      'quote': '¡El éxito viene de la práctica constante!',
      'english': 'Success comes from constant practice!'
    },
    {
      'quote': '¡Cada palabra nueva te acerca a tus metas!',
      'english': 'Every new word brings you closer to your goals!'
    },
    {
      'quote': '¡La perseverancia es la clave del aprendizaje!',
      'english': 'Perseverance is the key to learning!'
    },
    {
      'quote': '¡Hoy es el día perfecto para mejorar!',
      'english': 'Today is the perfect day to improve!'
    },
  ];

  /// Get today's motivation quote
  Future<DailyMotivation> getTodayMotivation({String? languageCode}) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayString = _formatDate(today);
    final targetLanguage = languageCode ?? 'es'; // Default to Spanish
    
    // Check if we need to generate new motivation for today and language
    final lastMotivationDate = prefs.getString('${_lastMotivationDateKey}_$targetLanguage');
    if (lastMotivationDate != todayString) {
      // Generate new motivation for today
      final motivation = await _generateDailyMotivation(languageCode: targetLanguage);
      await _saveMotivation(motivation, languageCode: targetLanguage);
      await prefs.setString('${_lastMotivationDateKey}_$targetLanguage', todayString);
      return motivation;
    }

    // Load existing motivation
    final motivationJson = prefs.getString('${_motivationKey}_$targetLanguage');
    if (motivationJson != null) {
      try {
        return DailyMotivation.fromJson(jsonDecode(motivationJson));
      } catch (e) {
        print('Error loading motivation: $e');
      }
    }

    // Fallback: generate new motivation
    final motivation = await _generateDailyMotivation(languageCode: targetLanguage);
    await _saveMotivation(motivation, languageCode: targetLanguage);
    await prefs.setString('${_lastMotivationDateKey}_$targetLanguage', todayString);
    return motivation;
  }

  /// Generate daily motivation using AI or fallback
  Future<DailyMotivation> _generateDailyMotivation({String? languageCode}) async {
    // Use language-specific quotes
    final targetLanguage = languageCode ?? 'es';
    final quotes = _languageQuotes[targetLanguage] ?? _fallbackQuotes;
    
    // Select quote based on day of year for variety
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    final quoteIndex = dayOfYear % quotes.length;
    final quote = quotes[quoteIndex];
    
    return DailyMotivation(
      quote: quote['quote']!,
      englishTranslation: quote['english']!,
      languageCode: targetLanguage,
      date: DateTime.now(),
    );
  }

  /// Save motivation to local storage
  Future<void> _saveMotivation(DailyMotivation motivation, {String? languageCode}) async {
    final prefs = await SharedPreferences.getInstance();
    final targetLanguage = languageCode ?? motivation.languageCode;
    await prefs.setString('${_motivationKey}_$targetLanguage', jsonEncode(motivation.toJson()));
  }

  /// Format date for consistent comparison
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
} 