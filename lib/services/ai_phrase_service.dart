// lib/services/ai_phrase_service.dart - CRITICAL FIX for Generate More
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../services/phrase_service.dart';

class AiGeneratedPhrase {
  final String english;
  final String spanish;
  final String category;
  final String difficulty;
  final DateTime createdAt;
  final bool isAiGenerated;

  AiGeneratedPhrase({
    required this.english,
    required this.spanish,
    required this.category,
    required this.difficulty,
    required this.createdAt,
    this.isAiGenerated = true,
  });

  factory AiGeneratedPhrase.fromJson(Map<String, dynamic> json) {
    return AiGeneratedPhrase(
      english: json['english']?.toString() ?? '',
      spanish: json['spanish']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      difficulty: json['difficulty']?.toString() ?? 'beginner',
      createdAt: DateTime.now(),
      isAiGenerated: true,
    );
  }

  PhraseModel toPhraseModel() {
    return PhraseModel(
      id: 'ai_${english.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}_${DateTime.now().millisecondsSinceEpoch}',
      english: english,
      spanish: spanish,
      category: category,
      difficulty: difficulty,
      createdAt: createdAt,
      isFavorite: false,
    );
  }
}

class AiPhraseService {
  static final AiPhraseService _instance = AiPhraseService._internal();
  factory AiPhraseService() => _instance;
  AiPhraseService._internal();

  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  
  // Cache for generated phrases
  final Map<String, List<AiGeneratedPhrase>> _cache = {};

  /// Generate phrases for a given topic using AI
  /// FIXED: Added forceNew parameter to bypass all caches
  Future<List<AiGeneratedPhrase>> generatePhrasesForTopic(String topic, {bool forceNew = false}) async {
    try {
      debugPrint('🤖 Generating AI phrases for topic: $topic (forceNew: $forceNew)');
      
      // FIXED: Skip cache check if forceNew is true
      if (!forceNew) {
        final cachedPhrases = _getCachedPhrases(topic);
        if (cachedPhrases.isNotEmpty) {
          debugPrint('📱 Found ${cachedPhrases.length} cached phrases for $topic');
          return cachedPhrases;
        }
      }

      // FIXED: Skip Firebase cache check if forceNew is true
      if (!forceNew) {
        try {
          debugPrint('☁️ Checking Firebase cache for: $topic');
          final cachedResult = await _functions
              .httpsCallable('getCachedPhrases')
              .call({'topic': topic});

          debugPrint('📡 Firebase cache response: ${cachedResult.data}');

          if (cachedResult.data['success'] == true) {
            final phrases = _parsePhrases(cachedResult.data['phrases'], topic);
            if (phrases.isNotEmpty) {
              _cache[topic.toLowerCase()] = phrases;
              debugPrint('☁️ Found ${phrases.length} Firebase cached phrases for $topic');
              return phrases;
            }
          }
        } catch (e) {
          debugPrint('⚠️ No cached phrases found: $e');
        }
      }

      // Generate new phrases - FIXED: Added forceNew parameter
      debugPrint('🚀 Calling generatePhrases function with forceNew: $forceNew');
      final result = await _functions
          .httpsCallable('generatePhrases')
          .call({
            'topic': topic,
            'forceNew': forceNew, // CRITICAL: Tell Firebase to bypass its cache too
            'timestamp': DateTime.now().millisecondsSinceEpoch, // Ensure uniqueness
          });

      debugPrint('📡 Generate phrases response: ${result.data}');

      if (result.data == null) {
        throw Exception('No response from server. Please check your internet connection.');
      }

      if (result.data['success'] != true) {
        final errorMsg = result.data['message'] ?? 'Unknown error occurred';
        throw Exception('Failed to generate phrases: $errorMsg');
      }

      final phrases = _parsePhrases(result.data['phrases'], topic);
      
      if (phrases.isEmpty) {
        throw Exception('No phrases were generated for "$topic". Please try a different topic.');
      }
      
      // Cache locally
      _cache[topic.toLowerCase()] = phrases;
      
      debugPrint('✅ Generated ${phrases.length} ${forceNew ? "NEW" : ""} AI phrases for $topic');
      return phrases;

    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ Firebase Functions error: ${e.code} - ${e.message}');
      String errorMessage = 'Failed to generate phrases';
      
      switch (e.code) {
        case 'unauthenticated':
          errorMessage = 'Authentication required. Please log in.';
          break;
        case 'permission-denied':
          errorMessage = 'Permission denied. Please check your account.';
          break;
        case 'unavailable':
          errorMessage = 'Service temporarily unavailable. Please try again later.';
          break;
        case 'deadline-exceeded':
          errorMessage = 'Request timed out. Please try again.';
          break;
        default:
          errorMessage = 'Server error: ${e.message ?? e.code}';
      }
      
      throw Exception(errorMessage);
    } catch (e) {
      debugPrint('❌ General error generating AI phrases: $e');
      
      if (e.toString().contains('network') || e.toString().contains('connection')) {
        throw Exception('Network error. Please check your internet connection and try again.');
      }
      
      throw Exception('Failed to generate phrases for "$topic". Please try again later.');
    }
  }

  /// Parse phrases from Firebase response
  List<AiGeneratedPhrase> _parsePhrases(dynamic phrasesData, String topic) {
    if (phrasesData == null) {
      debugPrint('⚠️ No phrases data received');
      return [];
    }
    
    debugPrint('📝 Parsing phrases data: $phrasesData');
    debugPrint('📝 Data type: ${phrasesData.runtimeType}');
    
    List<dynamic> phrasesList = [];
    
    if (phrasesData is List) {
      phrasesList = phrasesData;
    } else if (phrasesData is String) {
      try {
        final decoded = jsonDecode(phrasesData);
        if (decoded is List) {
          phrasesList = decoded;
        }
      } catch (e) {
        debugPrint('❌ Failed to parse phrases string: $e');
        return [];
      }
    } else {
      debugPrint('❌ Unexpected phrases data type: ${phrasesData.runtimeType}');
      return [];
    }
    
    final parsedPhrases = <AiGeneratedPhrase>[];
    
    for (int i = 0; i < phrasesList.length; i++) {
      final phraseItem = phrasesList[i];
      debugPrint('🔍 Processing item $i: $phraseItem (type: ${phraseItem.runtimeType})');
      
      try {
        Map<String, dynamic> phraseMap = {};
        
        if (phraseItem is Map<String, dynamic>) {
          phraseMap = phraseItem;
        } else if (phraseItem is Map) {
          phraseMap = phraseItem.map((key, value) => MapEntry(key.toString(), value));
        } else {
          debugPrint('⚠️ Skipping non-map phrase item: $phraseItem');
          continue;
        }
        
        // Ensure category matches the requested topic
        phraseMap['category'] = topic;
        
        debugPrint('🔍 Phrase map: $phraseMap');
        
        final english = phraseMap['english']?.toString() ?? '';
        final spanish = phraseMap['spanish']?.toString() ?? '';
        
        if (english.isNotEmpty && spanish.isNotEmpty) {
          final phrase = AiGeneratedPhrase.fromJson(phraseMap);
          parsedPhrases.add(phrase);
          debugPrint('✅ Parsed phrase: ${phrase.english} -> ${phrase.spanish}');
        } else {
          debugPrint('⚠️ Skipping phrase with missing fields: english="$english", spanish="$spanish"');
        }
      } catch (e) {
        debugPrint('❌ Error parsing individual phrase: $e');
        continue;
      }
    }
    
    debugPrint('✅ Successfully parsed ${parsedPhrases.length} phrases');
    return parsedPhrases;
  }

  /// Get cached phrases for a topic
  List<AiGeneratedPhrase> _getCachedPhrases(String topic) {
    return _cache[topic.toLowerCase()] ?? [];
  }

  /// Clear cache for a specific topic
  void clearCacheForTopic(String topic) {
    _cache.remove(topic.toLowerCase());
    debugPrint('🗑️ Cleared cache for topic: $topic');
  }

  /// Clear all cache
  void clearAllCache() {
    _cache.clear();
    debugPrint('🗑️ Cleared all cache');
  }

  /// Get all cached topics
  List<String> getCachedTopics() {
    return _cache.keys.toList();
  }

  /// Check if topic has cached phrases
  bool hasCachedPhrases(String topic) {
    return _cache.containsKey(topic.toLowerCase()) && 
           _cache[topic.toLowerCase()]!.isNotEmpty;
  }

  /// Convert AI phrases to PhraseModel list (for UI compatibility)
  List<PhraseModel> aiPhrasesToPhraseModels(List<AiGeneratedPhrase> aiPhrases) {
    return aiPhrases.map((aiPhrase) => aiPhrase.toPhraseModel()).toList();
  }

  /// Get suggestions for popular topics
  List<String> getPopularTopics() {
    return [
      'Airport',
      'Hotel',
      'Restaurant', 
      'Shopping',
      'Taxi',
      'Medical',
      'Business',
      'Beach',
      'Nightlife',
      'Sports',
      'Weather',
      'Family'
    ];
  }
}