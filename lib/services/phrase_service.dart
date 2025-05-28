//lib/services/phrase_service.dart
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class PhraseModel {
  final String id;
  final String english;
  final String spanish;
  final String category;
  final String difficulty;
  final DateTime createdAt;
  bool isFavorite;
  final bool isAiGenerated; // NEW: Track if it's AI-generated

  PhraseModel({
    required this.id,
    required this.english,
    required this.spanish,
    required this.category,
    required this.difficulty,
    required this.createdAt,
    this.isFavorite = false,
    this.isAiGenerated = false, // NEW: Default to false for CSV phrases
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
      'isAiGenerated': isAiGenerated, // NEW
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
      isAiGenerated: json['isAiGenerated'] ?? false, // NEW
    );
  }
}

class PhraseService {
  static final PhraseService _instance = PhraseService._internal();
  factory PhraseService() => _instance;
  PhraseService._internal();

  // Local storage
  static List<PhraseModel> _allPhrases = [];
  static List<PhraseModel> _aiPhrases = []; // NEW: Store AI phrases separately
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

      print('Found ${csvData.length - 1} phrases in CSV');

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
            isAiGenerated: false, // CSV phrases are not AI-generated
          );
          
          _allPhrases.add(phrase);
        }
      }

      // Load AI phrases from storage
      await _loadAiPhrases();

      _isInitialized = true;
      print('Loaded ${_allPhrases.length} CSV phrases and ${_aiPhrases.length} AI phrases');

    } catch (e) {
      print('Error loading CSV: $e');
      await _initializeBasicPhrases();
    }
  }

  // NEW: Load AI phrases from local storage
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
          print('Error parsing AI phrase: $e');
        }
      }
      
      print('Loaded ${_aiPhrases.length} AI phrases from storage');
    } catch (e) {
      print('Error loading AI phrases: $e');
    }
  }

  // NEW: Save AI phrases to local storage
  Future<void> _saveAiPhrases() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final aiPhrasesJson = _aiPhrases.map((phrase) => jsonEncode(phrase.toJson())).toList();
      await prefs.setStringList('ai_phrases', aiPhrasesJson);
      print('Saved ${_aiPhrases.length} AI phrases to storage');
    } catch (e) {
      print('Error saving AI phrases: $e');
    }
  }

  // NEW: Add AI-generated phrases
  Future<void> addAiPhrases(List<PhraseModel> newAiPhrases) async {
    for (final phrase in newAiPhrases) {
      // Check if phrase already exists
      if (!_aiPhrases.any((p) => p.id == phrase.id)) {
        final aiPhrase = phrase.copyWith(isAiGenerated: true);
        aiPhrase.isFavorite = _favoriteIds.contains(aiPhrase.id);
        _aiPhrases.add(aiPhrase);
      }
    }
    
    await _saveAiPhrases();
    print('Added ${newAiPhrases.length} new AI phrases');
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
    print('Basic fallback phrases loaded');
  }

  // Load favorites from SharedPreferences
  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesList = prefs.getStringList('favorite_phrases') ?? [];
    _favoriteIds = favoritesList.toSet();
  }

  // Save favorites to SharedPreferences
  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorite_phrases', _favoriteIds.toList());
  }

  // Toggle favorite status - UPDATED to handle both CSV and AI phrases
  Future<void> toggleFavorite(String phraseId) async {
    if (_favoriteIds.contains(phraseId)) {
      _favoriteIds.remove(phraseId);
    } else {
      _favoriteIds.add(phraseId);
    }
    
    // Update CSV phrases
    final csvPhraseIndex = _allPhrases.indexWhere((p) => p.id == phraseId);
    if (csvPhraseIndex != -1) {
      _allPhrases[csvPhraseIndex].isFavorite = _favoriteIds.contains(phraseId);
    }
    
    // Update AI phrases
    final aiPhraseIndex = _aiPhrases.indexWhere((p) => p.id == phraseId);
    if (aiPhraseIndex != -1) {
      _aiPhrases[aiPhraseIndex].isFavorite = _favoriteIds.contains(phraseId);
      await _saveAiPhrases(); // Save AI phrases when favorites change
    }
    
    await _saveFavorites();
  }

  // Check if phrase is favorite
  Future<bool> isFavorite(String phraseId) async {
    return _favoriteIds.contains(phraseId);
  }

  // Get all phrases (CSV + AI) by category
  Future<List<PhraseModel>> getPhrasesForCategory(String category) async {
    await initializeSampleData();
    
    final csvPhrases = _allPhrases.where((phrase) => phrase.category == category).toList();
    final aiPhrases = _aiPhrases.where((phrase) => phrase.category == category).toList();
    
    final allPhrases = [...csvPhrases, ...aiPhrases];
    allPhrases.sort((a, b) => a.english.compareTo(b.english));
    
    return allPhrases;
  }

  // Get all phrases (CSV + AI)
  Future<List<PhraseModel>> getAllPhrases() async {
    await initializeSampleData();
    
    final allPhrases = [..._allPhrases, ..._aiPhrases];
    allPhrases.sort((a, b) => a.category.compareTo(b.category));
    
    return allPhrases;
  }

  // Get favorite phrases (CSV + AI) - ordered by recently added
  Future<List<PhraseModel>> getFavoritePhrases() async {
    await initializeSampleData();
    
    final csvFavorites = _allPhrases.where((phrase) => phrase.isFavorite).toList();
    final aiFavorites = _aiPhrases.where((phrase) => phrase.isFavorite).toList();
    
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
    
    final allResults = [...csvResults, ...aiResults];
    allResults.sort((a, b) => a.english.compareTo(b.english));
    
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

  // Refresh data
  Future<void> refreshData() async {
    _isInitialized = false;
    _allPhrases.clear();
    _aiPhrases.clear();
    await initializeSampleData();
  }

  // Get phrase count for a category (CSV + AI)
  Future<int> getPhraseCountForCategory(String category) async {
    await initializeSampleData();
    
    final csvCount = _allPhrases.where((phrase) => phrase.category == category).length;
    final aiCount = _aiPhrases.where((phrase) => phrase.category == category).length;
    
    return csvCount + aiCount;
  }

  // NEW: Get AI phrases count for a category
  Future<int> getAiPhraseCountForCategory(String category) async {
    await initializeSampleData();
    return _aiPhrases.where((phrase) => phrase.category == category).length;
  }

  // NEW: Clear AI phrases for a category (for "Generate More" functionality)
  Future<void> clearAiPhrasesForCategory(String category) async {
    _aiPhrases.removeWhere((phrase) => phrase.category == category);
    await _saveAiPhrases();
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
}