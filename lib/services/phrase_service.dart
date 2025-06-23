import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  PhraseModel copyWith({
    String? id,
    String? english,
    String? spanish,
    String? category,
    String? difficulty,
    DateTime? createdAt,
    bool? isFavorite,
    bool? isAiGenerated,
  }) {
    return PhraseModel(
      id: id ?? this.id,
      english: english ?? this.english,
      spanish: spanish ?? this.spanish,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      createdAt: createdAt ?? this.createdAt,
      isFavorite: isFavorite ?? this.isFavorite,
      isAiGenerated: isAiGenerated ?? this.isAiGenerated,
    );
  }

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

  // 🔑 CHECK AUTHENTICATION - without importing user_data_service
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool get _isAuthenticated => _auth.currentUser != null;

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

  // 🎯 FIXED: Save AI phrases with DUAL STORAGE + FULL OBJECTS FOR CLOUD SYNC
  Future<void> _saveAiPhrases() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final aiPhrasesJson = _aiPhrases.map((phrase) => jsonEncode(phrase.toJson())).toList();
      
      if (_isAuthenticated) {
        // 🔒 SIGNED-IN MODE: Save to both signed-in storage and active storage
        await prefs.setStringList('signed_in_ai_phrases', aiPhrasesJson);
        await prefs.setStringList('ai_phrases', aiPhrasesJson); // Make active
        
        // 🚀 TRIGGER SYNC FLAGS (user_data_service will monitor this)
        await prefs.setBool('ai_phrases_need_sync', true);
        await prefs.setInt('ai_phrases_last_modified', DateTime.now().millisecondsSinceEpoch);
        
        // 🆕 TRIGGER CLOUD POLL FLAG (check for updates from other devices)
        await prefs.setBool('need_cloud_poll', true);
        
        debugPrint('🔒 Saved ${_aiPhrases.length} AI phrases to SIGNED-IN storage + flagged for sync + poll');
      } else {
        // 👤 GUEST MODE: Save to BOTH guest storage and active storage
        await prefs.setStringList('guest_ai_phrases', aiPhrasesJson);
        await prefs.setStringList('ai_phrases', aiPhrasesJson); // Make active
        
        debugPrint('👤 Saved ${_aiPhrases.length} AI phrases to GUEST storage');
      }
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
    debugPrint('💾 Authentication status: ${_isAuthenticated ? "SIGNED-IN" : "GUEST"}');
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
      
      // 🎯 FIXED: Use new dual storage save method (triggers sync flag)
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

  // 🆕 NEW METHOD: Update AI phrases from cloud sync (called by user_data_service)
  Future<void> updateAiPhrasesFromSync(List<String> aiPhrasesJson) async {
    try {
      debugPrint('🔄 === UPDATING AI PHRASES FROM CLOUD SYNC ===');
      debugPrint('🔄 Received ${aiPhrasesJson.length} AI phrases from cloud sync');
      
      _aiPhrases.clear();
      for (final phraseJson in aiPhrasesJson) {
        try {
          final phraseMap = jsonDecode(phraseJson);
          final phrase = PhraseModel.fromJson(phraseMap);
          phrase.isFavorite = _favoriteIds.contains(phrase.id);
          _aiPhrases.add(phrase);
        } catch (e) {
          debugPrint('Error parsing synced AI phrase: $e');
        }
      }
      
      // Save the updated AI phrases locally (without triggering cloud sync again)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('ai_phrases', aiPhrasesJson); // Make active
      if (_isAuthenticated) {
        await prefs.setStringList('signed_in_ai_phrases', aiPhrasesJson);
      } else {
        await prefs.setStringList('guest_ai_phrases', aiPhrasesJson);
      }
      
      debugPrint('✅ Updated ${_aiPhrases.length} AI phrases from cloud sync');
    } catch (e) {
      debugPrint('❌ Error updating AI phrases from sync: $e');
    }
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

  // 🎯 FIXED: Load favorites with DUAL STORAGE awareness
  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesList = prefs.getStringList('favorite_phrases') ?? [];
    _favoriteIds = favoritesList.toSet();
    debugPrint('Loaded ${_favoriteIds.length} favorite IDs from ${_isAuthenticated ? "SIGNED-IN" : "GUEST"} context');
  }

  // 🎯 FIXED: Save favorites with DUAL STORAGE + SYNC TRIGGER (NO CIRCULAR DEPENDENCY)
  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesList = _favoriteIds.toList();
    
    if (_isAuthenticated) {
      // 🔒 SIGNED-IN MODE: Save to both signed-in storage and active storage
      await prefs.setStringList('signed_in_favorite_phrases', favoritesList);
      await prefs.setStringList('favorite_phrases', favoritesList); // Make active
      
      // 🚀 TRIGGER SYNC FLAGS (NO CIRCULAR DEPENDENCY - user_data_service will monitor this)
      await prefs.setBool('favorites_need_sync', true);
      await prefs.setInt('favorites_last_modified', DateTime.now().millisecondsSinceEpoch);
      
      // 🆕 TRIGGER CLOUD POLL FLAG (check for updates from other devices)
      await prefs.setBool('need_cloud_poll', true);
      
      debugPrint('🔒 Saved ${_favoriteIds.length} favorites to SIGNED-IN storage + flagged for sync + poll');
    } else {
      // 👤 GUEST MODE: Save to BOTH guest storage and active storage
      await prefs.setStringList('guest_favorite_phrases', favoritesList);
      await prefs.setStringList('favorite_phrases', favoritesList); // Make active
      debugPrint('👤 Saved ${_favoriteIds.length} favorites to GUEST storage');
    }
  }

  // Toggle favorite status - UPDATED to handle both CSV and AI phrases with dual storage
  Future<void> toggleFavorite(String phraseId) async {
    debugPrint('🔄 === TOGGLE FAVORITE START ===');
    debugPrint('🔄 Authentication status: ${_isAuthenticated ? "SIGNED-IN" : "GUEST"}');
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
      // Save AI phrases when favorites change (triggers sync flag)
      await _saveAiPhrases();
    }
    
    // Save favorites (triggers sync flag)
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
    
    // NORMALIZE category for consistent matching
    final normalizedCategory = _normalizeCategory(category);
    
    final csvPhrases = _allPhrases.where((p) => _normalizeCategory(p.category) == normalizedCategory).toList();
    final aiPhrases = _aiPhrases.where((p) => _normalizeCategory(p.category) == normalizedCategory).toList();
    
    // NEW: AI phrases first (newest at top), then CSV phrases
    final result = [...aiPhrases, ...csvPhrases];
    
    debugPrint('Found ${csvPhrases.length} CSV + ${aiPhrases.length} AI = ${result.length} total phrases for "$category" (normalized: "$normalizedCategory")');
    return result;
  }

  // Get all phrases
  Future<List<PhraseModel>> getAllPhrases() async {
    await initializeSampleData();
    return [..._aiPhrases, ..._allPhrases]; // AI phrases first
  }

  // Get favorite phrases only
  Future<List<PhraseModel>> getFavoritePhrases() async {
    await initializeSampleData();
    
    final csvFavorites = _allPhrases.where((p) => p.isFavorite).toList();
    final aiFavorites = _aiPhrases.where((p) => p.isFavorite).toList();
    
    return [...aiFavorites, ...csvFavorites]; // AI favorites first
  }

  // Search phrases
  Future<List<PhraseModel>> searchPhrases(String query) async {
    await initializeSampleData();
    
    final lowerQuery = query.toLowerCase();
    
    final csvResults = _allPhrases.where((p) => 
      p.english.toLowerCase().contains(lowerQuery) ||
      p.spanish.toLowerCase().contains(lowerQuery) ||
      p.category.toLowerCase().contains(lowerQuery)
    ).toList();
    
    final aiResults = _aiPhrases.where((p) => 
      p.english.toLowerCase().contains(lowerQuery) ||
      p.spanish.toLowerCase().contains(lowerQuery) ||
      p.category.toLowerCase().contains(lowerQuery)
    ).toList();
    
    return [...aiResults, ...csvResults]; // AI results first
  }

  // Get unique categories
  Future<List<String>> getCategories() async {
    await initializeSampleData();
    
    final csvCategories = _allPhrases.map((p) => p.category).toSet();
    final aiCategories = _aiPhrases.map((p) => p.category).toSet();
    
    final allCategories = <String>{...csvCategories, ...aiCategories};
    final sortedCategories = allCategories.toList()..sort();
    
    return sortedCategories;
  }

  // Clear AI phrases for a category (preserving favorites)
  Future<void> clearAiPhrasesForCategory(String category) async {
    // NORMALIZE CATEGORY for case-insensitive clearing
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
    
    // Save changes (triggers sync flag)
    await _saveAiPhrases();
    debugPrint('🧹 === CLEAR AI PHRASES COMPLETE ===');
  }

  // Clear ALL AI phrases for a category (including favorites) - for complete reset
  Future<void> clearAllAiPhrasesForCategory(String category) async {
    // NORMALIZE CATEGORY for case-insensitive clearing
    final normalizedCategory = _normalizeCategory(category);
    debugPrint('🧹 === CLEARING ALL AI PHRASES FOR CATEGORY ===');
    debugPrint('🧹 Original category: "$category"');
    debugPrint('🧹 Normalized category: "$normalizedCategory"');
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
    
    // Save changes with dual storage (triggers sync flags)
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
  
  // Force refresh favorites from SharedPreferences
  Future<void> forceRefreshFavorites() async {
    try {
      await _loadFavorites();
      
      // Update isFavorite status for all phrases
      for (final phrase in _allPhrases) {
        phrase.isFavorite = _favoriteIds.contains(phrase.id);
      }
      
      for (final phrase in _aiPhrases) {
        phrase.isFavorite = _favoriteIds.contains(phrase.id);
      }
      
      debugPrint('🔄 Force refreshed favorites: ${_favoriteIds.length} total');
    } catch (e) {
      debugPrint('❌ Error force refreshing favorites: $e');
    }
  }
}