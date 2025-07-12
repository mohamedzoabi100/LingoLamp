import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

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
    {
      'spanish': '¡La confianza viene con el conocimiento!',
      'english': 'Confidence comes with knowledge!'
    },
    {
      'spanish': '¡Cada error es una lección valiosa!',
      'english': 'Every mistake is a valuable lesson!'
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
    // Use fixed quotes instead of AI - select based on day of year for variety
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    final quoteIndex = dayOfYear % _fallbackQuotes.length;
    final quote = _fallbackQuotes[quoteIndex];
    
    return DailyMotivation(
      spanishQuote: quote['spanish']!,
      englishTranslation: quote['english']!,
      date: DateTime.now(),
    );
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