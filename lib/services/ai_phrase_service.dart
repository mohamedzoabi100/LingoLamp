import 'package:flutter/foundation.dart';
import '../models/phrase_model.dart';
import 'ai_chat_service.dart';

class AiPhraseService {
  final AiChatService _aiChatService = AiChatService();

  List<String> getPopularTopics() {
    return ['Travel', 'Dining', 'Shopping', 'Business', 'Emergency'];
  }

  Future<List<Map<String, String>>> generatePhrasesForTopic(String topic) async {
    final prompt = "Generate 5 common phrases for a tourist related to '$topic'. The response should be a list of English:Spanish pairs, one per line.";
    final response = await _aiChatService.sendMessage(prompt);
    debugPrint("AI Response for '$topic':\n$response");
    return _parsePhrasesFromResponse(response);
  }
  
  Future<List<Map<String, String>>> generateMorePhrasesForTopic(String topic, List<PhraseModel> existingPhrases) async {
    final existingPhrasesString = existingPhrases.map((p) => '- ${p.english}').join('\n');
    final prompt = "Generate 5 more common phrases for a tourist related to '$topic', avoiding repetition of the following:\n$existingPhrasesString\nThe response should be a list of English:Spanish pairs, one per line.";
    final response = await _aiChatService.sendMessage(prompt);
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
}