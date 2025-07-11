import 'dart:convert';

class FlashcardData {
  final String front;
  final String back;
  
  FlashcardData({required this.front, required this.back});
}

class FlashcardExtractor {
  /// Extracts flashcard data from AI response text
  static FlashcardData? extractFlashcardData(String text) {
    // 1. Hidden payload (invisible characters)
    final hidden = RegExp(r'\u200B(\{.*?\})\u200C', dotAll: true).firstMatch(text);
    if (hidden != null) {
      return _parseJson(hidden.group(1)!);
    }

    // 2. Visible JSON (fallback)
    final visible = RegExp(r'\{"tool":"create_flashcard".*?\}', dotAll: true).firstMatch(text);
    if (visible != null) {
      return _parseJson(visible.group(0)!);
    }

    // 3. Fallback regex for Spanish translations
    final spanishSentence = RegExp(
      r'The Spanish (?:word|translation) for .?[""]?([^""]+?)[""]? .?\\((.+?)\\)',
      caseSensitive: false,
    ).firstMatch(text);
    if (spanishSentence != null) {
      return FlashcardData(
        front: spanishSentence.group(1)!.trim(),
        back: spanishSentence.group(2)!.trim(),
      );
    }
    
    return null;
  }

  /// Parses JSON payload from AI response
  static FlashcardData? _parseJson(String jsonStr) {
    try {
      final map = json.decode(jsonStr);
      if (map['tool'] == 'create_flashcard') {
        final args = map['args'];
        return FlashcardData(
          front: args['front'],
          back: args['back'],
        );
      }
    } catch (e) {
      // Ignore JSON parsing errors
    }
    return null;
  }

  /// Checks if a message contains flashcard data
  static bool hasFlashcardData(String text) {
    return extractFlashcardData(text) != null;
  }
} 