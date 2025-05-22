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

  PhraseModel({
    required this.id,
    required this.english,
    required this.spanish,
    required this.category,
    required this.difficulty,
    required this.createdAt,
    this.isFavorite = false,
  });

  // Helper method to create a copy with updated favorite status
  PhraseModel copyWith({bool? isFavorite}) {
    return PhraseModel(
      id: id,
      english: english,
      spanish: spanish,
      category: category,
      difficulty: difficulty,
      createdAt: createdAt,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  // Convert to JSON for local storage (if needed)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'english': english,
      'spanish': spanish,
      'category': category,
      'difficulty': difficulty,
      'createdAt': createdAt.toIso8601String(),
      'isFavorite': isFavorite,
    };
  }

  // Create from JSON (if needed)
  factory PhraseModel.fromJson(Map<String, dynamic> json) {
    return PhraseModel(
      id: json['id'],
      english: json['english'],
      spanish: json['spanish'],
      category: json['category'],
      difficulty: json['difficulty'],
      createdAt: DateTime.parse(json['createdAt']),
      isFavorite: json['isFavorite'] ?? false,
    );
  }
}

class PhraseService {
  static final PhraseService _instance = PhraseService._internal();
  factory PhraseService() => _instance;
  PhraseService._internal();

  // Local storage
  static List<PhraseModel> _allPhrases = [];
  Set<String> _favoriteIds = {};
  bool _isInitialized = false;

  // Initialize from CSV file
  Future<void> initializeSampleData() async {
    if (_isInitialized) return; // Only initialize once

    try {
      // Load favorites first
      await _loadFavorites();

      // Load CSV file
      final csvString = await rootBundle.loadString('assets/data/phrases.csv');
      final List<List<String>> csvData = csvString
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .map((line) => line.split(','))
          .toList();

      print('Found ${csvData.length - 1} phrases in CSV');

      _allPhrases.clear();

      // Process CSV data (skip header row)
      for (int i = 1; i < csvData.length; i++) {
        final row = csvData[i];
        if (row.length >= 4) {
          final englishText = row[0].trim();
          final spanishText = row[1].trim();
          final categoryText = row[2].trim();
          final difficultyText = row[3].trim();
          
          // Create unique ID
          final id = '${englishText.toLowerCase().replaceAll(' ', '_')}_${categoryText.toLowerCase()}';
          
          final phrase = PhraseModel(
            id: id,
            english: englishText,
            spanish: spanishText,
            category: categoryText,
            difficulty: difficultyText,
            createdAt: DateTime.now(),
            isFavorite: _favoriteIds.contains(id),
          );
          
          _allPhrases.add(phrase);
        }
      }

      _isInitialized = true;
      print('Loaded ${_allPhrases.length} phrases from CSV');

    } catch (e) {
      print('Error loading CSV: $e');
      // Fallback to basic phrases
      await _initializeBasicPhrases();
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
      ),
      PhraseModel(
        id: 'thank_you_greetings',
        english: 'Thank you',
        spanish: 'Gracias',
        category: 'Greetings',
        difficulty: 'beginner',
        createdAt: DateTime.now(),
        isFavorite: _favoriteIds.contains('thank_you_greetings'),
      ),
      PhraseModel(
        id: 'help_emergencies',
        english: 'Help!',
        spanish: '¡Ayuda!',
        category: 'Emergencies',
        difficulty: 'beginner',
        createdAt: DateTime.now(),
        isFavorite: _favoriteIds.contains('help_emergencies'),
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

  // Toggle favorite status
  Future<void> toggleFavorite(String phraseId) async {
    if (_favoriteIds.contains(phraseId)) {
      _favoriteIds.remove(phraseId);
    } else {
      _favoriteIds.add(phraseId);
    }
    
    // Update the phrase in memory
    final phraseIndex = _allPhrases.indexWhere((p) => p.id == phraseId);
    if (phraseIndex != -1) {
      _allPhrases[phraseIndex].isFavorite = _favoriteIds.contains(phraseId);
    }
    
    await _saveFavorites();
  }

  // Check if phrase is favorite
  Future<bool> isFavorite(String phraseId) async {
    return _favoriteIds.contains(phraseId);
  }

  // Get phrases by category (returns Future instead of Stream)
  Future<List<PhraseModel>> getPhrasesForCategory(String category) async {
    await initializeSampleData(); // Ensure data is loaded
    
    return _allPhrases
        .where((phrase) => phrase.category == category)
        .toList()
        ..sort((a, b) => a.english.compareTo(b.english));
  }

  // Get phrases by category as Stream (for compatibility with existing UI)
  Stream<List<PhraseModel>> getPhrasesForCategoryStream(String category) async* {
    await initializeSampleData(); // Ensure data is loaded
    
    yield _allPhrases
        .where((phrase) => phrase.category == category)
        .toList()
        ..sort((a, b) => a.english.compareTo(b.english));
  }

  // Get all phrases
  Future<List<PhraseModel>> getAllPhrases() async {
    await initializeSampleData(); // Ensure data is loaded
    
    return List.from(_allPhrases)
      ..sort((a, b) => a.category.compareTo(b.category));
  }

  // Get all phrases as Stream (for compatibility)
  Stream<List<PhraseModel>> getAllPhrasesStream() async* {
    await initializeSampleData(); // Ensure data is loaded
    
    yield List.from(_allPhrases)
      ..sort((a, b) => a.category.compareTo(b.category));
  }

  // Get favorite phrases only - ordered by recently added (newest first)
  Future<List<PhraseModel>> getFavoritePhrases() async {
    await initializeSampleData(); // Ensure data is loaded
    
    final favorites = _allPhrases.where((phrase) => phrase.isFavorite).toList();
    
    // Sort by the order they appear in _favoriteIds (recently added first)
    final favoriteIdsList = _favoriteIds.toList().reversed.toList();
    
    favorites.sort((a, b) {
      final indexA = favoriteIdsList.indexOf(a.id);
      final indexB = favoriteIdsList.indexOf(b.id);
      
      if (indexA != -1 && indexB != -1) {
        return indexA.compareTo(indexB);
      }
      
      if (indexA != -1) return -1;
      if (indexB != -1) return 1;
      
      return a.english.compareTo(b.english);
    });
    
    return favorites;
  }

  // Get favorite phrases as Stream (for compatibility)
  Stream<List<PhraseModel>> getFavoritePhrasesStream() async* {
    yield await getFavoritePhrases();
  }

  // Search phrases
  Future<List<PhraseModel>> searchPhrases(String query) async {
    if (query.isEmpty) return [];
    
    await initializeSampleData(); // Ensure data is loaded
    
    return _allPhrases
        .where((phrase) =>
            phrase.english.toLowerCase().contains(query.toLowerCase()) ||
            phrase.spanish.toLowerCase().contains(query.toLowerCase()))
        .toList()
        ..sort((a, b) => a.english.compareTo(b.english));
  }

  // Search phrases as Stream (for compatibility)
  Stream<List<PhraseModel>> searchPhrasesStream(String query) async* {
    yield await searchPhrases(query);
  }

  // Get unique categories
  Future<List<String>> getCategories() async {
    await initializeSampleData(); // Ensure data is loaded
    
    return _allPhrases
        .map((phrase) => phrase.category)
        .toSet()
        .toList()
        ..sort();
  }

  // Get unique difficulties
  Future<List<String>> getDifficulties() async {
    await initializeSampleData(); // Ensure data is loaded
    
    return _allPhrases
        .map((phrase) => phrase.difficulty)
        .toSet()
        .toList()
        ..sort();
  }

  // Refresh data (for pull-to-refresh functionality)
  Future<void> refreshData() async {
    _isInitialized = false;
    _allPhrases.clear();
    await initializeSampleData();
  }

  // Get phrase count for a category
  Future<int> getPhraseCountForCategory(String category) async {
    await initializeSampleData();
    return _allPhrases.where((phrase) => phrase.category == category).length;
  }
}