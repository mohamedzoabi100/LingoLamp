//lib/services/phrase_service.dart - FIXED DUPLICATE DETECTION AND CATEGORY CONSISTENCY
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math' as math;

class PhraseModel {
  final String id;
  final String english;
  final String spanish;
  final String category;
  final String difficulty;
  final DateTime createdAt;
  bool isFavorite;
  final bool isAiGenerated;

  PhraseModel({
    required this.id,
    required this.english,
    required this.spanish,
    required this.category,
    required this.difficulty,
    required this.createdAt,
    this.isFavorite = false,
    this.isAiGenerated = false,
  });

  // Helper method to create a copy with updated favorite status
  PhraseModel copyWith({bool? isFavorite, bool? isAiGenerated}) {
    return PhraseModel(
      id: id,
      english: english,
      spanish: spanish,
      category: category,
      difficulty: difficulty,
      createdAt: createdAt,
      isFavorite: isFavorite ?? this.isFavorite,
      isAiGenerated: isAiGenerated ?? this.isAiGenerated,
    );
  }

  // Convert to JSON for local storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'english': english,
      'spanish': spanish,
      'category': category,
      'difficulty': difficulty,
      'createdAt': createdAt.toIso8601String(),
      'isFavorite': isFavorite,
      'isAiGenerated': isAiGenerated,
    };
  }

  // Create from JSON
  factory PhraseModel.fromJson(Map<String, dynamic> json) {
    return PhraseModel(
      id: json['id'],
      english: json['english'],
      spanish: json['spanish'],
      category: json['category'],
      difficulty: json['difficulty'],
      createdAt: DateTime.parse(json['createdAt']),
      isFavorite: json['isFavorite'] ?? false,
      isAiGenerated: json['isAiGenerated'] ?? false,
    );
  }
}

class PhraseService {
  static final PhraseService _instance = PhraseService._internal();
  factory PhraseService() => _instance;
  PhraseService._internal();

  // Local storage
  static List<PhraseModel> _allPhrases = [];
  static List<PhraseModel> _aiPhrases = [];
  Set<String> _favoriteIds = {};
  bool _isInitialized = false;

  // Initialize from CSV file
  Future<void> initializeSampleData() async {
    if (_isInitialized) return;

    try {
      await _loadFavorites();
      final csvString = await rootBundle.loadString('assets/data/phrases.csv');
      final List<List<String>> csvData = csvString
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .map((line) => line.split(','))
          .toList();

      debugPrint('Found ${csvData.length - 1} phrases in CSV');

      _allPhrases.clear();

      for (int i = 1; i < csvData.length; i++) {
        final row = csvData[i];
        if (row.length >= 4) {
          final englishText = row[0].trim();
          final spanishText = row[1].trim();
          final categoryText = row[2].trim();
          final difficultyText = row[3].trim();
          
          final id = '${englishText.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}_${categoryText.toLowerCase().replaceAll(' ', '_')}_$i';
          
          final phrase = PhraseModel(
            id: id,
            english: englishText,
            spanish: spanishText,
            category: categoryText,
            difficulty: difficultyText,
            createdAt: DateTime.now(),
            isFavorite: _favoriteIds.contains(id),
            isAiGenerated: false,
          );
          
          _allPhrases.add(phrase);
        }
      }

      // Load AI phrases from storage
      await _loadAiPhrases();

      _isInitialized = true;
      debugPrint('Loaded ${_allPhrases.length} CSV phrases and ${_aiPhrases.length} AI phrases');

    } catch (e) {
      debugPrint('Error loading CSV: $e');
      await _initializeBasicPhrases();
    }
  }

  // Load AI phrases from local storage
  Future<void> _loadAiPhrases() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final aiPhrasesJson = prefs.getStringList('ai_phrases') ?? [];
      
      _aiPhrases.clear();
      for (final phraseJson in aiPhrasesJson) {
        try {
          final phraseMap = jsonDecode(phraseJson);
          final phrase = PhraseModel.fromJson(phraseMap);
          phrase.isFavorite = _favoriteIds.contains(phrase.id);
          _aiPhrases.add(phrase);
        } catch (e) {
          debugPrint('Error parsing AI phrase: $e');
        }
      }
      
      debugPrint('Loaded ${_aiPhrases.length} AI phrases from storage');
    } catch (e) {
      debugPrint('Error loading AI phrases: $e');
    }
  }

  // Save AI phrases to local storage
  Future<void> _saveAiPhrases() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final aiPhrasesJson = _aiPhrases.map((phrase) => jsonEncode(phrase.toJson())).toList();
      await prefs.setStringList('ai_phrases', aiPhrasesJson);
      debugPrint('Saved ${_aiPhrases.length} AI phrases to storage');
    } catch (e) {
      debugPrint('Error saving AI phrases: $e');
    }
  }

  // CRITICAL: Shared normalization method - must match ai_phrase_service.dart exactly
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

  // FIXED: Better duplicate detection with enhanced logging
  Future<void> addAiPhrases(List<PhraseModel> newAiPhrases) async {
    debugPrint('💾 === ADDING AI PHRASES START ===');
    debugPrint('💾 Received ${newAiPhrases.length} new phrases to add');
    debugPrint('💾 Current AI phrases count: ${_aiPhrases.length}');
    
    if (newAiPhrases.isEmpty) {
      debugPrint('⚠️ No phrases to add - empty list');
      return;
    }
    
    // Show what we're trying to add
    for (int i = 0; i < newAiPhrases.length; i++) {
      final phrase = newAiPhrases[i];
      debugPrint('📥 NEW[$i]: "${phrase.english}" -> "${phrase.spanish}" (cat: "${phrase.category}")');
    }
    
    final newPhrasesToAdd = <PhraseModel>[];
    
    for (final phrase in newAiPhrases) {
      // Normalize the new phrase category for comparison
      final normalizedCategory = _normalizeCategory(phrase.category);
      
      debugPrint('🔍 === CHECKING PHRASE ===');
      debugPrint('🔍 English: "${phrase.english}"');
      debugPrint('🔍 Spanish: "${phrase.spanish}"');
      debugPrint('🔍 Original category: "${phrase.category}"');
      debugPrint('🔍 Normalized category: "$normalizedCategory"');
      
      // IMPROVED: Check if phrase already exists (by content AND category)
      final existsAlready = _aiPhrases.any((existingPhrase) {
        final existingNormalizedCategory = _normalizeCategory(existingPhrase.category);
        
        final englishMatch = existingPhrase.english.toLowerCase().trim() == phrase.english.toLowerCase().trim();
        final spanishMatch = existingPhrase.spanish.toLowerCase().trim() == phrase.spanish.toLowerCase().trim();
        final categoryMatch = existingNormalizedCategory == normalizedCategory;
        
        debugPrint('🔍 Comparing with existing: "${existingPhrase.english}" -> "${existingPhrase.spanish}" (cat: "${existingPhrase.category}" -> "$existingNormalizedCategory")');
        debugPrint('🔍 English match: $englishMatch, Spanish match: $spanishMatch, Category match: $categoryMatch');
        
        return englishMatch && spanishMatch && categoryMatch;
      });
      
      if (!existsAlready) {
        // Create phrase with normalized category
        final aiPhrase = phrase.copyWith(isAiGenerated: true);
        // Update the category to be normalized
        final normalizedPhrase = PhraseModel(
          id: aiPhrase.id,
          english: aiPhrase.english,
          spanish: aiPhrase.spanish,
          category: normalizedCategory, // Use normalized category
          difficulty: aiPhrase.difficulty,
          createdAt: aiPhrase.createdAt,
          isFavorite: _favoriteIds.contains(aiPhrase.id),
          isAiGenerated: true,
        );
        
        newPhrasesToAdd.add(normalizedPhrase);
        debugPrint('➕ WILL ADD: "${normalizedPhrase.english}" (category: "${normalizedPhrase.category}", isFavorite: ${normalizedPhrase.isFavorite})');
      } else {
        debugPrint('⚠️ SKIPPED DUPLICATE: "${phrase.english}" in category "$normalizedCategory"');
      }
    }
    
    debugPrint('💾 === ADDITION SUMMARY ===');
    debugPrint('💾 Total phrases to add: ${newPhrasesToAdd.length}');
    debugPrint('💾 Duplicates skipped: ${newAiPhrases.length - newPhrasesToAdd.length}');
    
    // Insert new phrases at the beginning
    if (newPhrasesToAdd.isNotEmpty) {
      debugPrint('🔄 Adding ${newPhrasesToAdd.length} new phrases at the BEGINNING of the list');
      
      // Insert all new phrases at the beginning, maintaining their order
      for (int i = newPhrasesToAdd.length - 1; i >= 0; i--) {
        _aiPhrases.insert(0, newPhrasesToAdd[i]);
      }
      
      await _saveAiPhrases();
      debugPrint('✅ Added ${newPhrasesToAdd.length} new AI phrases at the BEGINNING. Total AI phrases: ${_aiPhrases.length}');
      debugPrint('📍 New phrases are now at positions 0-${newPhrasesToAdd.length - 1}');
      
      // Debug: Show the first few phrases to verify order
      for (int i = 0; i < math.min(5, _aiPhrases.length); i++) {
        final p = _aiPhrases[i];
        debugPrint('📍 Position $i: "${p.english}" (category: "${p.category}", AI: ${p.isAiGenerated})');
      }
    } else {
      debugPrint('⚠️ No new phrases to add (all were duplicates or list was empty)');
    }
    
    debugPrint('💾 === ADDING AI PHRASES COMPLETE ===');
  }

  // Fallback basic phrases
  Future<void> _initializeBasicPhrases() async {
    if (_allPhrases.isNotEmpty) return;

    final basicPhrases = [
      PhraseModel(
        id: 'hello_greetings',
        english: 'Hello',
        spanish: 'Hola',
        category: 'Greetings',
        difficulty: 'beginner',
        createdAt: DateTime.now(),
        isFavorite: _favoriteIds.contains('hello_greetings'),
        isAiGenerated: false,
      ),
      PhraseModel(
        id: 'thank_you_greetings',
        english: 'Thank you',
        spanish: 'Gracias',
        category: 'Greetings',
        difficulty: 'beginner',
        createdAt: DateTime.now(),
        isFavorite: _favoriteIds.contains('thank_you_greetings'),
        isAiGenerated: false,
      ),
    ];

    _allPhrases.addAll(basicPhrases);
    _isInitialized = true;
    debugPrint('Basic fallback phrases loaded');
  }

  // Load favorites from SharedPreferences
  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesList = prefs.getStringList('favorite_phrases') ?? [];
    _favoriteIds = favoritesList.toSet();
    debugPrint('Loaded ${_favoriteIds.length} favorite IDs: ${_favoriteIds.toList()}');
  }

  // Save favorites to SharedPreferences
  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorite_phrases', _favoriteIds.toList());
    debugPrint('Saved ${_favoriteIds.length} favorite IDs');
  }

  // Toggle favorite status - UPDATED to handle both CSV and AI phrases
  Future<void> toggleFavorite(String phraseId) async {
    debugPrint('🔄 === TOGGLE FAVORITE START ===');
    debugPrint('🔄 Phrase ID: $phraseId');
    debugPrint('🔄 Current favorites count: ${_favoriteIds.length}');
    debugPrint('🔄 Is currently favorite: ${_favoriteIds.contains(phraseId)}');
    
    final wasInFavorites = _favoriteIds.contains(phraseId);
    
    if (wasInFavorites) {
      _favoriteIds.remove(phraseId);
      debugPrint('💔 Removed from favorites: $phraseId');
    } else {
      _favoriteIds.add(phraseId);
      debugPrint('💚 Added to favorites: $phraseId');
    }
    
    // Update CSV phrases
    final csvPhraseIndex = _allPhrases.indexWhere((p) => p.id == phraseId);
    if (csvPhraseIndex != -1) {
      _allPhrases[csvPhraseIndex].isFavorite = _favoriteIds.contains(phraseId);
      debugPrint('📝 Updated CSV phrase favorite status: ${_allPhrases[csvPhraseIndex].english} -> ${_allPhrases[csvPhraseIndex].isFavorite}');
    }
    
    // Update AI phrases
    final aiPhraseIndex = _aiPhrases.indexWhere((p) => p.id == phraseId);
    if (aiPhraseIndex != -1) {
      _aiPhrases[aiPhraseIndex].isFavorite = _favoriteIds.contains(phraseId);
      debugPrint('🤖 Updated AI phrase favorite status: ${_aiPhrases[aiPhraseIndex].english} -> ${_aiPhrases[aiPhraseIndex].isFavorite}');
      await _saveAiPhrases(); // Save AI phrases when favorites change
    }
    
    await _saveFavorites();
    debugPrint('💾 New favorites count: ${_favoriteIds.length}');
    debugPrint('🔄 === TOGGLE FAVORITE COMPLETE ===');
  }

  // Check if phrase is favorite
  Future<bool> isFavorite(String phraseId) async {
    return _favoriteIds.contains(phraseId);
  }

  // Get all phrases (CSV + AI) by category - NEW PHRASES SHOW FIRST
  Future<List<PhraseModel>> getPhrasesForCategory(String category) async {
    await initializeSampleData();
    
    // NORMALIZE CATEGORY: Make case-insensitive search
    final normalizedCategory = _normalizeCategory(category);
    debugPrint('📊 === GET PHRASES FOR CATEGORY ===');
    debugPrint('📊 Original category: "$category"');
    debugPrint('📊 Normalized category: "$normalizedCategory"');
    
    final csvPhrases = _allPhrases.where((phrase) => 
      _normalizeCategory(phrase.category) == normalizedCategory).toList();
    final aiPhrases = _aiPhrases.where((phrase) => 
      _normalizeCategory(phrase.category) == normalizedCategory).toList();
    
    debugPrint('📊 CSV phrases found: ${csvPhrases.length}');
    debugPrint('📊 AI phrases found: ${aiPhrases.length}');
    debugPrint('📊 AI favorites: ${aiPhrases.where((p) => p.isFavorite).length}');
    
    // Show first few AI phrases for debugging
    for (int i = 0; i < math.min(3, aiPhrases.length); i++) {
      final p = aiPhrases[i];
      debugPrint('📊 AI[$i]: "${p.english}" (cat: "${p.category}", fav: ${p.isFavorite})');
    }
    
    // IMPORTANT: Put AI phrases FIRST (they're already sorted with newest first)
    // Then add CSV phrases after AI phrases
    final allPhrases = [...aiPhrases, ...csvPhrases];
    
    // Sort CSV phrases alphabetically, but keep AI phrases at the top in their order
    final aiPhrasesCount = aiPhrases.length;
    if (csvPhrases.isNotEmpty) {
      // Sort only the CSV phrases part (after AI phrases)
      final sortedCsvPhrases = csvPhrases..sort((a, b) => a.english.compareTo(b.english));
      // Replace the CSV portion with sorted CSV phrases
      allPhrases.replaceRange(aiPhrasesCount, allPhrases.length, sortedCsvPhrases);
    }
    
    debugPrint('📋 Final result: ${aiPhrases.length} AI phrases first, then ${csvPhrases.length} sorted CSV phrases');
    debugPrint('📊 === GET PHRASES COMPLETE ===');
    
    return allPhrases;
  }

  // Get all phrases (CSV + AI)
  Future<List<PhraseModel>> getAllPhrases() async {
    await initializeSampleData();
    
    // AI phrases first (newest first), then CSV phrases
    final allPhrases = [..._aiPhrases, ..._allPhrases];
    
    // Sort only the CSV portion
    final aiPhrasesCount = _aiPhrases.length;
    if (_allPhrases.isNotEmpty) {
      final sortedCsvPhrases = _allPhrases..sort((a, b) => a.category.compareTo(b.category));
      allPhrases.replaceRange(aiPhrasesCount, allPhrases.length, sortedCsvPhrases);
    }
    
    return allPhrases;
  }

  // Get favorite phrases (CSV + AI) - ordered by recently added
  Future<List<PhraseModel>> getFavoritePhrases() async {
    await initializeSampleData();
    
    final csvFavorites = _allPhrases.where((phrase) => phrase.isFavorite).toList();
    final aiFavorites = _aiPhrases.where((phrase) => phrase.isFavorite).toList();
    
    debugPrint('📋 === GET FAVORITE PHRASES ===');
    debugPrint('📋 CSV favorites: ${csvFavorites.length}');
    debugPrint('📋 AI favorites: ${aiFavorites.length}');
    
    // Show AI favorites for debugging
    for (int i = 0; i < aiFavorites.length; i++) {
      final fav = aiFavorites[i];
      debugPrint('📋 AI Favorite[$i]: "${fav.english}" -> category: "${fav.category}" (isFavorite: ${fav.isFavorite})');
    }
    
    final allFavorites = [...csvFavorites, ...aiFavorites];
    
    // Sort by the order they appear in _favoriteIds (recently added first)
    final favoriteIdsList = _favoriteIds.toList().reversed.toList();
    
    allFavorites.sort((a, b) {
      final indexA = favoriteIdsList.indexOf(a.id);
      final indexB = favoriteIdsList.indexOf(b.id);
      
      if (indexA != -1 && indexB != -1) {
        return indexA.compareTo(indexB);
      }
      
      if (indexA != -1) return -1;
      if (indexB != -1) return 1;
      
      return a.english.compareTo(b.english);
    });
    
    debugPrint('📋 Returning ${allFavorites.length} total favorites');
    debugPrint('📋 === GET FAVORITE PHRASES COMPLETE ===');
    
    return allFavorites;
  }

  // Search phrases (CSV + AI)
  Future<List<PhraseModel>> searchPhrases(String query) async {
    if (query.isEmpty) return [];
    
    await initializeSampleData();
    
    final csvResults = _allPhrases.where((phrase) =>
        phrase.english.toLowerCase().contains(query.toLowerCase()) ||
        phrase.spanish.toLowerCase().contains(query.toLowerCase())).toList();
        
    final aiResults = _aiPhrases.where((phrase) =>
        phrase.english.toLowerCase().contains(query.toLowerCase()) ||
        phrase.spanish.toLowerCase().contains(query.toLowerCase())).toList();
    
    // AI results first, then CSV results
    final allResults = [...aiResults, ...csvResults];
    
    // Sort each section alphabetically
    final aiResultsCount = aiResults.length;
    if (csvResults.isNotEmpty) {
      final sortedCsvResults = csvResults..sort((a, b) => a.english.compareTo(b.english));
      allResults.replaceRange(aiResultsCount, allResults.length, sortedCsvResults);
    }
    
    return allResults;
  }

  // Get unique categories (CSV + AI)
  Future<List<String>> getCategories() async {
    await initializeSampleData();
    
    final csvCategories = _allPhrases.map((phrase) => phrase.category).toSet();
    final aiCategories = _aiPhrases.map((phrase) => phrase.category).toSet();
    
    final allCategories = {...csvCategories, ...aiCategories}.toList();
    allCategories.sort();
    
    return allCategories;
  }

  // Get unique difficulties
  Future<List<String>> getDifficulties() async {
    await initializeSampleData();
    
    final csvDifficulties = _allPhrases.map((phrase) => phrase.difficulty).toSet();
    final aiDifficulties = _aiPhrases.map((phrase) => phrase.difficulty).toSet();
    
    final allDifficulties = {...csvDifficulties, ...aiDifficulties}.toList();
    allDifficulties.sort();
    
    return allDifficulties;
  }

  // MODIFY the refreshData method to also refresh favorites
  Future<void> refreshData() async {
    _isInitialized = false;
    _allPhrases.clear();
    _aiPhrases.clear();
    await initializeSampleData();
    await forceRefreshFavorites(); // ADD THIS LINE
  }

  // Get phrase count for a category (CSV + AI)
  Future<int> getPhraseCountForCategory(String category) async {
    await initializeSampleData();
    
    final normalizedCategory = _normalizeCategory(category);
    final csvCount = _allPhrases.where((phrase) => _normalizeCategory(phrase.category) == normalizedCategory).length;
    final aiCount = _aiPhrases.where((phrase) => _normalizeCategory(phrase.category) == normalizedCategory).length;
    
    return csvCount + aiCount;
  }

  // Get AI phrases count for a category
  Future<int> getAiPhraseCountForCategory(String category) async {
    await initializeSampleData();
    final normalizedCategory = _normalizeCategory(category);
    return _aiPhrases.where((phrase) => _normalizeCategory(phrase.category) == normalizedCategory).length;
  }

  // Clear AI phrases for a category BUT preserve favorited ones
  Future<void> clearAiPhrasesForCategory(String category) async {
    final normalizedCategory = _normalizeCategory(category);
    debugPrint('🧹 === CLEAR AI PHRASES FOR CATEGORY ===');
    debugPrint('🧹 Original category: "$category"');
    debugPrint('🧹 Normalized category: "$normalizedCategory"');
    debugPrint('🧹 BEFORE clearing:');
    debugPrint('🧹 Total AI phrases: ${_aiPhrases.length}');
    
    final categoryPhrases = _aiPhrases.where((p) => _normalizeCategory(p.category) == normalizedCategory).toList();
    debugPrint('🧹 AI phrases in category "$normalizedCategory": ${categoryPhrases.length}');
    
    final categoryFavorites = categoryPhrases.where((p) => p.isFavorite).toList();
    debugPrint('💚 Favorites in category "$normalizedCategory": ${categoryFavorites.length}');
    for (final fav in categoryFavorites) {
      debugPrint('💚 Favorite phrase: "${fav.english}" (ID: ${fav.id}, isFavorite: ${fav.isFavorite})');
    }
    
    // Count before removal
    final beforeCount = _aiPhrases.length;
    
    // Remove only NON-FAVORITED AI phrases for this category
    _aiPhrases.removeWhere((phrase) => 
        _normalizeCategory(phrase.category) == normalizedCategory && !phrase.isFavorite);
    
    // Count after removal
    final afterCount = _aiPhrases.length;
    final removedCount = beforeCount - afterCount;
    
    debugPrint('🧹 AFTER clearing:');
    debugPrint('🧹 Removed $removedCount non-favorited phrases');
    debugPrint('🧹 Total AI phrases: ${_aiPhrases.length}');
    
    final remainingCategoryPhrases = _aiPhrases.where((p) => _normalizeCategory(p.category) == normalizedCategory).toList();
    debugPrint('🧹 Remaining AI phrases in category "$normalizedCategory": ${remainingCategoryPhrases.length}');
    final remainingFavorites = remainingCategoryPhrases.where((p) => p.isFavorite).toList();
    debugPrint('💚 Remaining favorites in category "$normalizedCategory": ${remainingFavorites.length}');
    for (final fav in remainingFavorites) {
      debugPrint('💚 Preserved favorite: "${fav.english}" (ID: ${fav.id}, isFavorite: ${fav.isFavorite})');
    }
    
    await _saveAiPhrases();
    debugPrint('🧹 === CLEAR AI PHRASES COMPLETE ===');
  }

  // Clear ALL AI phrases for a category (including favorites) - for complete reset
  Future<void> clearAllAiPhrasesForCategory(String category) async {
    // NORMALIZE CATEGORY for case-insensitive clearing
    final normalizedCategory = _normalizeCategory(category);
    debugPrint('🧹 === CLEARING ALL AI PHRASES FOR CATEGORY: "$category" -> "$normalizedCategory" ===');
    debugPrint('🧹 BEFORE clearing:');
    debugPrint('🧹 Total AI phrases: ${_aiPhrases.length}');
    
    final categoryPhrases = _aiPhrases.where((p) => 
      _normalizeCategory(p.category) == normalizedCategory).toList();
    debugPrint('🧹 AI phrases in category "$normalizedCategory": ${categoryPhrases.length}');
    
    final categoryFavorites = categoryPhrases.where((p) => p.isFavorite).toList();
    debugPrint('💚 Favorites in category "$normalizedCategory": ${categoryFavorites.length}');
    
    // Count before removal
    final beforeCount = _aiPhrases.length;
    
    // Remove ALL AI phrases for this category (including favorites) - using normalized comparison
    _aiPhrases.removeWhere((phrase) => 
      _normalizeCategory(phrase.category) == normalizedCategory);
    
    // Remove from favorites set if they were favorited
    for (final phrase in categoryPhrases) {
      if (phrase.isFavorite) {
        _favoriteIds.remove(phrase.id);
        debugPrint('💔 Removed from favorites: ${phrase.english} (ID: ${phrase.id})');
      }
    }
    
    // Count after removal
    final afterCount = _aiPhrases.length;
    final removedCount = beforeCount - afterCount;
    
    debugPrint('🧹 AFTER clearing:');
    debugPrint('🧹 Removed $removedCount phrases (including favorites)');
    debugPrint('🧹 Total AI phrases remaining: ${_aiPhrases.length}');
    
    // Save changes
    await _saveAiPhrases();
    await _saveFavorites();
    
    debugPrint('✅ === CLEARING COMPLETE FOR CATEGORY: "$normalizedCategory" ===');
  }

  // Compatibility methods for existing code
  Stream<List<PhraseModel>> getPhrasesForCategoryStream(String category) async* {
    yield await getPhrasesForCategory(category);
  }

  Stream<List<PhraseModel>> getAllPhrasesStream() async* {
    yield await getAllPhrases();
  }

  Stream<List<PhraseModel>> getFavoritePhrasesStream() async* {
    yield await getFavoritePhrases();
  }

  Stream<List<PhraseModel>> searchPhrasesStream(String query) async* {
    yield await searchPhrases(query);
  }
  // ADD THIS NEW METHOD - Force refresh favorites from SharedPreferences
  Future<void> forceRefreshFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesList = prefs.getStringList('favorite_phrases') ?? [];
      _favoriteIds = favoritesList.toSet();
      
      print('🔄 === FORCE REFRESH FAVORITES ===');
      print('🔄 Loaded ${_favoriteIds.length} favorites from SharedPreferences');
      for (int i = 0; i < favoritesList.length; i++) {
        print('🔄   Favorite[$i]: ${favoritesList[i]}');
      }
      
      // Update CSV phrases favorite status
      for (var phrase in _allPhrases) {
        phrase.isFavorite = _favoriteIds.contains(phrase.id);
      }
      
      // Update AI phrases favorite status  
      for (var phrase in _aiPhrases) {
        phrase.isFavorite = _favoriteIds.contains(phrase.id);
      }
      
      print('✅ === FORCE REFRESH FAVORITES COMPLETE ===');
    } catch (e) {
      print('❌ Error force refreshing favorites: $e');
    }
  }


}