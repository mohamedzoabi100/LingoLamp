// lib/services/ai_phrase_service.dart - ENHANCED WITH TOPIC SIMILARITY HANDLING
import 'dart:convert';
import 'dart:math' as math;
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
      id: 'ai_${english.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(1000)}',
      english: english,
      spanish: spanish,
      category: category,
      difficulty: difficulty,
      createdAt: createdAt,
      isFavorite: false,
      isAiGenerated: true,
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
  
  // Track generation counts per topic
  final Map<String, int> _generationCounts = {};

  /// ENHANCED: Topic similarity mapping to handle typos and variations
  final Map<String, String> _topicSimilarityMap = {
    // Airport variations
    'airpot': 'Airport',
    'aiport': 'Airport',
    'airpport': 'Airport',
    'airport': 'Airport',
    
    // Hotel variations
    'hotell': 'Hotel',
    'hotl': 'Hotel',
    'hotel': 'Hotel',
    
    // Restaurant variations
    'resturant': 'Restaurant',
    'restraunt': 'Restaurant',
    'restaurnt': 'Restaurant',
    'restaurant': 'Restaurant',
    
    // Shopping variations
    'shoping': 'Shopping',
    'shooping': 'Shopping',
    'shopping': 'Shopping',
    
    // Taxi variations
    'taksi': 'Taxi',
    'taxie': 'Taxi',
    'taxi': 'Taxi',
    
    // Pharmacy variations
    'farmacy': 'Pharmacy',
    'pharmcy': 'Pharmacy',
    'pharmacy': 'Pharmacy',
    
    // Hospital variations
    'hospitl': 'Hospital',
    'hopital': 'Hospital',
    'hospital': 'Hospital',
    
    // Business variations
    'buisness': 'Business meeting',
    'business': 'Business meeting',
    'bussiness': 'Business meeting',
    'meeting': 'Business meeting',
    
    // Common variations
    'golf': 'Golf',
    'beach': 'Beach',
    'gym': 'Gym',
    'bank': 'Bank',
  };

  /// SHARED NORMALIZATION METHOD - Must match phrase_service.dart exactly
  String _normalizeCategory(String category) {
    if (category.isEmpty) return category;
    
    // Split by spaces to handle multi-word categories
    final words = category.toLowerCase().split(' ');
    final normalizedWords = words.map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1);
    }).toList();
    
    return normalizedWords.join(' ');
  }

  /// ENHANCED: Smart topic normalization with similarity handling
  String _smartNormalizeTopic(String topic) {
    if (topic.isEmpty) return topic;
    
    // First, clean the topic
    final cleanTopic = topic.toLowerCase().trim();
    
    debugPrint('🔍 Smart normalizing topic: "$topic" -> cleaned: "$cleanTopic"');
    
    // Check for exact matches in similarity map
    if (_topicSimilarityMap.containsKey(cleanTopic)) {
      final mappedTopic = _topicSimilarityMap[cleanTopic]!;
      debugPrint('🎯 Found exact match: "$cleanTopic" -> "$mappedTopic"');
      return mappedTopic;
    }
    
    // Check for partial matches (fuzzy matching)
    for (final entry in _topicSimilarityMap.entries) {
      final key = entry.key;
      final value = entry.value;
      
      // Check if topics are similar (allowing for 1-2 character differences)
      if (_areTopicsSimilar(cleanTopic, key)) {
        debugPrint('🎯 Found similar match: "$cleanTopic" ≈ "$key" -> "$value"');
        return value;
      }
    }
    
    // If no similarity found, use standard normalization
    final normalized = _normalizeCategory(topic);
    debugPrint('📝 No similarity match, using standard normalization: "$topic" -> "$normalized"');
    return normalized;
  }

  /// Check if two topics are similar (allowing for typos)
  bool _areTopicsSimilar(String topic1, String topic2) {
    if (topic1 == topic2) return true;
    
    // Simple Levenshtein distance check for typos
    final distance = _levenshteinDistance(topic1, topic2);
    final maxLength = math.max(topic1.length, topic2.length);
    
    // Allow 1-2 character differences for shorter words, more for longer words
    final threshold = maxLength <= 5 ? 1 : 2;
    
    return distance <= threshold;
  }

  /// Calculate Levenshtein distance (edit distance) between two strings
  int _levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<List<int>> d = List.generate(
      s1.length + 1,
      (i) => List.generate(s2.length + 1, (j) => 0),
    );

    for (int i = 0; i <= s1.length; i++) {
      d[i][0] = i;
    }
    for (int j = 0; j <= s2.length; j++) {
      d[0][j] = j;
    }

    for (int i = 1; i <= s1.length; i++) {
      for (int j = 1; j <= s2.length; j++) {
        int cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        d[i][j] = [
          d[i - 1][j] + 1,     // deletion
          d[i][j - 1] + 1,     // insertion
          d[i - 1][j - 1] + cost, // substitution
        ].reduce(math.min);
      }
    }

    return d[s1.length][s2.length];
  }

  /// ENHANCED: Check if we already have phrases for this topic (considering similar topics)
  Future<List<PhraseModel>> _checkExistingPhrases(String topic) async {
    final normalizedTopic = _smartNormalizeTopic(topic);
    
    // Get phrase service instance and check for existing phrases
    final phraseService = PhraseService();
    await phraseService.initializeSampleData();
    
    final existingPhrases = await phraseService.getPhrasesForCategory(normalizedTopic);
    final existingAiPhrases = existingPhrases.where((p) => p.isAiGenerated).toList();
    
    debugPrint('🔍 Checking existing phrases for topic: "$topic" -> normalized: "$normalizedTopic"');
    debugPrint('🔍 Found ${existingAiPhrases.length} existing AI phrases');
    
    return existingAiPhrases;
  }

  /// Generate phrases for a given topic using AI
  Future<List<AiGeneratedPhrase>> generatePhrasesForTopic(
    String topic, {
    bool forceNew = false,
    List<String>? existingPhrases,
    bool isMoreGeneration = false,
  }) async {
    // CRITICAL: Use smart normalization
    final normalizedTopic = _smartNormalizeTopic(topic);
    debugPrint('🔤 Original topic: "$topic" -> Smart normalized: "$normalizedTopic"');
    
    // Check if we already have phrases for this topic (unless forcing new)
    if (!forceNew && !isMoreGeneration) {
      final existingPhrases = await _checkExistingPhrases(topic);
      if (existingPhrases.isNotEmpty) {
        debugPrint('✅ Found ${existingPhrases.length} existing phrases for "$normalizedTopic", converting to AiGeneratedPhrase');
        
        // Convert existing PhraseModels to AiGeneratedPhrases for consistency
        final aiPhrases = existingPhrases.map((pm) => AiGeneratedPhrase(
          english: pm.english,
          spanish: pm.spanish,
          category: pm.category,
          difficulty: pm.difficulty,
          createdAt: pm.createdAt,
          isAiGenerated: true,
        )).toList();
        
        return aiPhrases;
      }
    }
    
    try {
      debugPrint('🤖 Generating AI phrases for topic: $normalizedTopic (forceNew: $forceNew, isMore: $isMoreGeneration)');
      
      // Increment generation count using normalized topic
      _generationCounts[normalizedTopic] = (_generationCounts[normalizedTopic] ?? 0) + 1;
      final generationNumber = _generationCounts[normalizedTopic]!;
      
      debugPrint('📊 This is generation #$generationNumber for topic: $normalizedTopic');
      
      // Skip cache check if forceNew is true or it's a "generate more" request
      if (!forceNew && !isMoreGeneration) {
        final cachedPhrases = _getCachedPhrases(normalizedTopic);
        if (cachedPhrases.isNotEmpty) {
          debugPrint('📱 Found ${cachedPhrases.length} cached phrases for $normalizedTopic');
          return cachedPhrases;
        }
      }

      // Skip Firebase cache check if forceNew is true or it's a "generate more" request
      if (!forceNew && !isMoreGeneration) {
        try {
          debugPrint('☁️ Checking Firebase cache for: $normalizedTopic');
          final cachedResult = await _functions
              .httpsCallable('getCachedPhrases')
              .call({'topic': normalizedTopic});

          debugPrint('📡 Firebase cache response: ${cachedResult.data}');

          if (cachedResult.data['success'] == true) {
            final phrases = _parsePhrases(cachedResult.data['phrases'], normalizedTopic);
            if (phrases.isNotEmpty) {
              _cache[normalizedTopic.toLowerCase()] = phrases;
              debugPrint('☁️ Found ${phrases.length} Firebase cached phrases for $normalizedTopic');
              return phrases;
            }
          }
        } catch (e) {
          debugPrint('⚠️ No cached phrases found: $e');
        }
      }

      // Prepare request data with enhanced context
      final requestData = {
        'topic': normalizedTopic, // Use normalized topic
        'forceNew': forceNew,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'generationNumber': generationNumber,
        'isMoreGeneration': isMoreGeneration,
      };

      // Send existing phrases to AI for context if available
      if (existingPhrases != null && existingPhrases.isNotEmpty) {
        requestData['existingPhrases'] = existingPhrases;
        requestData['requestType'] = 'generateMore';
        debugPrint('🔄 Sending ${existingPhrases.length} existing phrases to avoid duplicates');
      } else {
        requestData['requestType'] = 'initial';
      }

      // Generate new phrases
      debugPrint('🚀 Calling generatePhrases function with enhanced context');
      final result = await _functions
          .httpsCallable('generatePhrases')
          .call(requestData);

      debugPrint('📡 Generate phrases response: ${result.data}');

      if (result.data == null) {
        throw Exception('No response from server. Please check your internet connection.');
      }

      if (result.data['success'] != true) {
        final errorMsg = result.data['message'] ?? 'Unknown error occurred';
        throw Exception('Failed to generate phrases: $errorMsg');
      }

      final phrases = _parsePhrases(result.data['phrases'], normalizedTopic);
      
      if (phrases.isEmpty) {
        throw Exception('No phrases were generated for "$normalizedTopic". Please try a different topic.');
      }
      
      // Cache locally only for initial generation (not for "generate more")
      if (!forceNew && !isMoreGeneration) {
        _cache[normalizedTopic.toLowerCase()] = phrases;
      }
      
      debugPrint('✅ Generated ${phrases.length} ${isMoreGeneration ? "ADDITIONAL" : ""} AI phrases for $normalizedTopic');
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
      
      throw Exception('Failed to generate phrases for "$normalizedTopic". Please try again later.');
    }
  }

  /// Generate more phrases with better context
  Future<List<AiGeneratedPhrase>> generateMorePhrasesForTopic(
    String topic,
    List<PhraseModel> existingPhrases,
  ) async {
    // CRITICAL: Use smart normalization
    final normalizedTopic = _smartNormalizeTopic(topic);
    
    // Extract English phrases to send as context
    final existingEnglishPhrases = existingPhrases
        .map((p) => p.english)
        .toList();

    debugPrint('🔄 Generating MORE phrases for: $normalizedTopic');
    debugPrint('🔄 Avoiding duplicates of: ${existingEnglishPhrases.length} existing phrases');

    return await generatePhrasesForTopic(
      normalizedTopic,
      forceNew: true,
      existingPhrases: existingEnglishPhrases,
      isMoreGeneration: true,
    );
  }

  /// Parse phrases from Firebase response
  List<AiGeneratedPhrase> _parsePhrases(dynamic phrasesData, String normalizedTopic) {
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
        
        // CRITICAL: Ensure category is exactly the normalized topic
        phraseMap['category'] = normalizedTopic;
        
        debugPrint('🔍 Phrase map with normalized category: $phraseMap');
        
        final english = phraseMap['english']?.toString() ?? '';
        final spanish = phraseMap['spanish']?.toString() ?? '';
        
        if (english.isNotEmpty && spanish.isNotEmpty) {
          final phrase = AiGeneratedPhrase.fromJson(phraseMap);
          parsedPhrases.add(phrase);
          debugPrint('✅ Parsed phrase: ${phrase.english} -> ${phrase.spanish} (category: ${phrase.category})');
        } else {
          debugPrint('⚠️ Skipping phrase with missing fields: english="$english", spanish="$spanish"');
        }
      } catch (e) {
        debugPrint('❌ Error parsing individual phrase: $e');
        continue;
      }
    }
    
    debugPrint('✅ Successfully parsed ${parsedPhrases.length} phrases with category: $normalizedTopic');
    return parsedPhrases;
  }

  /// Get cached phrases for a topic
  List<AiGeneratedPhrase> _getCachedPhrases(String topic) {
    final normalizedTopic = _smartNormalizeTopic(topic);
    return _cache[normalizedTopic.toLowerCase()] ?? [];
  }

  /// Get generation count for a topic
  int getGenerationCount(String topic) {
    final normalizedTopic = _smartNormalizeTopic(topic);
    return _generationCounts[normalizedTopic] ?? 0;
  }

  /// Reset generation count for a topic
  void resetGenerationCount(String topic) {
    final normalizedTopic = _smartNormalizeTopic(topic);
    _generationCounts.remove(normalizedTopic);
    debugPrint('🔄 Reset generation count for topic: $normalizedTopic');
  }

  /// Clear cache for a specific topic
  void clearCacheForTopic(String topic) {
    final normalizedTopic = _smartNormalizeTopic(topic);
    _cache.remove(normalizedTopic.toLowerCase());
    _generationCounts.remove(normalizedTopic);
    debugPrint('🗑️ Cleared cache and generation count for topic: $normalizedTopic');
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
    final normalizedTopic = _smartNormalizeTopic(topic);
    return _cache.containsKey(normalizedTopic.toLowerCase()) && 
           _cache[normalizedTopic.toLowerCase()]!.isNotEmpty;
  }

  /// Convert AI phrases to PhraseModel list (for UI compatibility)
  List<PhraseModel> aiPhrasesToPhraseModels(List<AiGeneratedPhrase> aiPhrases) {
    return aiPhrases.map((aiPhrase) => aiPhrase.toPhraseModel()).toList();
  }

  /// Get suggestions for popular topics - UPDATED with correct spellings
  List<String> getPopularTopics() {
    return [
      'Airport',
      'Hotel', 
      'Restaurant',
      'Shopping',
      'Taxi',
      'Pharmacy',
      'Hospital',
      'Business meeting',
      'Golf',
      'Beach',
      'Gym',
      'Bank',
      'Post office',
      'Gas station',
      'Train station',
      'Grocery store',
    ];
  }
}