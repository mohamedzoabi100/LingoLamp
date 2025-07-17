import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/flashcard_model.dart';
import '../../services/cloud_flashcard_service.dart';
import '../../utils/database_helper.dart';
import '../providers/language_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/recommendation_provider.dart'; // Added import for RecommendationProvider

class FlashcardProvider extends ChangeNotifier {
  final CloudFlashcardService _cloudFlashcardService = CloudFlashcardService();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  
  List<Flashcard> _flashcards = [];
  List<Flashcard> _dueCards = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _currentLanguage = 'es';
  bool _isGuest = false;
  Stream<List<Flashcard>>? _flashcardsStream;
  
  // Add debouncing to prevent excessive updates
  DateTime? _lastUpdateTime;
  static const Duration _updateDebounceTime = Duration(milliseconds: 500);

  // Getters
  List<Flashcard> get flashcards => _flashcards;
  List<Flashcard> get dueCards => _dueCards;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Initialize the provider
  Future<void> init({String? languageCode, BuildContext? context}) async {
    if (languageCode != null) {
      _currentLanguage = languageCode;
    }
    if (context != null) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      _isGuest = authProvider.isGuest;
    }
    
    await _loadFlashcards();
    if (!_isGuest) {
      _listenToFlashcardsCloud();
    }
  }

  // Load flashcards from local database (for both guest and signed-in users)
  Future<void> _loadFlashcards() async {
    try {
      _setLoading(true);
      
      if (_isGuest) {
        // For guest users, load from local database
        final allFlashcards = await _dbHelper.getAllFlashcards();
        _flashcards = allFlashcards.where((f) => f.languageCode == _currentLanguage).toList();
        print('📚 [FlashcardProvider] Loaded ${_flashcards.length} guest flashcards for $_currentLanguage');
      } else {
        // For signed-in users, load from cloud for ALL languages and ensure they have local IDs
        final allCloudFlashcards = await _cloudFlashcardService.getAllFlashcards();
        print('📚 [FlashcardProvider] Loaded ${allCloudFlashcards.length} cloud flashcards from all languages');
        
        // Save cloud flashcards to local database to ensure they have IDs for spaced repetition
        for (final flashcard in allCloudFlashcards) {
          try {
            // Check if flashcard already exists in local database
            final existing = await _dbHelper.getFlashcardByUuid(flashcard.uuid);
            if (existing == null) {
              // Insert new flashcard to get an ID
              await _dbHelper.insertFlashcard(flashcard);
              print('💾 [FlashcardProvider] Saved cloud flashcard to local DB: ${flashcard.originalText} (${flashcard.languageCode})');
            }
          } catch (e) {
            print('⚠️ [FlashcardProvider] Error saving cloud flashcard to local DB: $e');
          }
        }
        
        // Load all flashcards from local database and filter by current language
        final allFlashcards = await _dbHelper.getAllFlashcards();
        _flashcards = allFlashcards.where((f) => f.languageCode == _currentLanguage).toList();
        print('📚 [FlashcardProvider] Loaded ${_flashcards.length} flashcards for $_currentLanguage (total in DB: ${allFlashcards.length})');
      }
      
      _updateDueCards();
      _setLoading(false);
    } catch (e) {
      print('❌ [FlashcardProvider] Error loading flashcards: $e');
      _errorMessage = 'Failed to load flashcards: $e';
      _setLoading(false);
    }
  } 

  // Listen to cloud flashcards changes (signed-in users only)
  void _listenToFlashcardsCloud() {
    _flashcardsStream?.drain();
    _flashcardsStream = _cloudFlashcardService.listenToFlashcards(_currentLanguage);
    _flashcardsStream!.listen((cloudFlashcards) async {
      print('🔄 [FlashcardProvider] Cloud stream update for $_currentLanguage: ${cloudFlashcards.length} cards');
      
      // Debounce updates to prevent excessive refreshes
      final now = DateTime.now();
      if (_lastUpdateTime != null && now.difference(_lastUpdateTime!) < _updateDebounceTime) {
        print('⏱️ [FlashcardProvider] Debouncing update (too soon after last update)');
        return;
      }
      _lastUpdateTime = now;
      
      // For signed-in users, we need to preserve flashcards from other languages
      // Get all flashcards from local database to preserve other languages
      final allLocalFlashcards = await _dbHelper.getAllFlashcards();
      print('📊 [FlashcardProvider] Total local flashcards: ${allLocalFlashcards.length}');
      
      // Remove flashcards for current language (they will be replaced by cloud data)
      final otherLanguageFlashcards = allLocalFlashcards.where((f) => f.languageCode != _currentLanguage).toList();
      print('📊 [FlashcardProvider] Other language flashcards: ${otherLanguageFlashcards.length}');
      
      // Save new cloud flashcards to local database
      for (final flashcard in cloudFlashcards) {
        try {
          final existing = await _dbHelper.getFlashcardByUuid(flashcard.uuid);
          if (existing == null) {
            await _dbHelper.insertFlashcard(flashcard);
            print('💾 [FlashcardProvider] Saved new cloud flashcard to local DB: ${flashcard.originalText} (${flashcard.languageCode})');
          }
        } catch (e) {
          print('⚠️ [FlashcardProvider] Error saving cloud flashcard to local DB: $e');
        }
      }
      
      // Combine other language flashcards with cloud flashcards for current language
      _flashcards = [...otherLanguageFlashcards, ...cloudFlashcards];
      
      _updateDueCards();
      print('🔄 [FlashcardProvider] Cloud flashcards updated: ${cloudFlashcards.length} cloud cards + ${otherLanguageFlashcards.length} other language cards = ${_flashcards.length} total');
      notifyListeners();
    });
  }

  // Update due cards based on spaced repetition
  void _updateDueCards() {
    _dueCards = _flashcards.where((card) => 
      card.nextReview?.isBefore(DateTime.now()) ?? true
    ).toList();
    print('📅 [FlashcardProvider] Due cards: ${_dueCards.length}/${_flashcards.length}');
  }

  @override
  void dispose() {
    _flashcardsStream = null;
    super.dispose();
  }

  // Method to handle language changes
  Future<void> onLanguageChanged(String newLanguage) async {
    if (_currentLanguage != newLanguage) {
      print('🔄 [FlashcardProvider] Language changing from $_currentLanguage to $newLanguage');
      print('📊 [FlashcardProvider] Before change: ${_flashcards.length} flashcards in memory');
      
      _currentLanguage = newLanguage;
      await _loadFlashcards();
      if (!_isGuest) {
        _listenToFlashcardsCloud();
      }
      notifyListeners();
      
      print('📊 [FlashcardProvider] After change: ${_flashcards.length} flashcards in memory for $newLanguage');
    }
  }

  // Method to force refresh all data
  Future<void> forceRefresh() async {
    await _loadFlashcards();
    notifyListeners();
  }

  // Method to force refresh all languages from cloud (for debugging)
  Future<void> forceRefreshAllLanguages() async {
    if (_isGuest) {
      await _loadFlashcards();
    } else {
      try {
        _setLoading(true);
        print('🔄 [FlashcardProvider] Force refreshing all languages from cloud');
        
        // Load all flashcards from cloud
        final allCloudFlashcards = await _cloudFlashcardService.getAllFlashcards();
        print('📚 [FlashcardProvider] Loaded ${allCloudFlashcards.length} cloud flashcards from all languages');
        
        // Save all cloud flashcards to local database
        for (final flashcard in allCloudFlashcards) {
          try {
            final existing = await _dbHelper.getFlashcardByUuid(flashcard.uuid);
            if (existing == null) {
              await _dbHelper.insertFlashcard(flashcard);
              print('💾 [FlashcardProvider] Saved cloud flashcard to local DB: ${flashcard.originalText} (${flashcard.languageCode})');
            }
          } catch (e) {
            print('⚠️ [FlashcardProvider] Error saving cloud flashcard to local DB: $e');
          }
        }
        
        // Load current language flashcards
        final allFlashcards = await _dbHelper.getAllFlashcards();
        _flashcards = allFlashcards.where((f) => f.languageCode == _currentLanguage).toList();
        print('📚 [FlashcardProvider] Loaded ${_flashcards.length} flashcards for $_currentLanguage (total in DB: ${allFlashcards.length})');
        
        _updateDueCards();
        _setLoading(false);
        notifyListeners();
      } catch (e) {
        print('❌ [FlashcardProvider] Error force refreshing all languages: $e');
        _errorMessage = 'Failed to refresh all languages: $e';
        _setLoading(false);
        notifyListeners();
      }
    }
  }

  // Method to check if provider is properly initialized
  bool get isInitialized => _flashcards.isNotEmpty || _currentLanguage.isNotEmpty;

  // Add a new flashcard
  Future<void> addFlashcard(Flashcard flashcard) async {
    try {
      print('📝 [FlashcardProvider] Adding flashcard: "${flashcard.originalText}" -> "${flashcard.translatedText}" (language: ${flashcard.languageCode})');
      
      // Check for duplicates before adding
      final existingDuplicate = _flashcards.any((f) => 
        f.originalText == flashcard.originalText && 
        f.translatedText == flashcard.translatedText &&
        f.languageCode == flashcard.languageCode
      );
      
      if (existingDuplicate) {
        print('⚠️ [FlashcardProvider] Duplicate flashcard detected, skipping: ${flashcard.originalText}');
        return;
      }
      
      if (_isGuest) {
        // For guest users, save to local database
        await _dbHelper.insertFlashcard(flashcard);
        _flashcards.add(flashcard);
        _updateDueCards();
        print('📝 [FlashcardProvider] Added flashcard to local database: ${flashcard.originalText}');
      } else {
        // For signed-in users, save to both local database and cloud
        await _dbHelper.insertFlashcard(flashcard);
        await _cloudFlashcardService.addFlashcard(flashcard.languageCode, flashcard);
        _flashcards.add(flashcard);
        _updateDueCards();
        print('📝 [FlashcardProvider] Added flashcard to local DB and cloud: ${flashcard.originalText} (language: ${flashcard.languageCode})');
      }
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      print('❌ [FlashcardProvider] Error adding flashcard: $e');
      _errorMessage = 'Failed to add flashcard: $e';
      notifyListeners();
    }
  }

  // Update an existing flashcard
  Future<void> updateFlashcard(Flashcard flashcard) async {
    try {
      if (_isGuest) {
        // For guest users, update in local database
        await _dbHelper.updateFlashcard(flashcard);
        final index = _flashcards.indexWhere((f) => f.uuid == flashcard.uuid);
        if (index != -1) {
          _flashcards[index] = flashcard;
          _updateDueCards();
        }
        print('📝 [FlashcardProvider] Updated flashcard in local database: ${flashcard.originalText}');
      } else {
        // For signed-in users, update in both local database and cloud
        await _dbHelper.updateFlashcardByUuid(flashcard);
        await _cloudFlashcardService.updateFlashcard(flashcard.languageCode, flashcard);
        final index = _flashcards.indexWhere((f) => f.uuid == flashcard.uuid);
        if (index != -1) {
          _flashcards[index] = flashcard;
          _updateDueCards();
        }
        print('📝 [FlashcardProvider] Updated flashcard in local DB and cloud: ${flashcard.originalText} (language: ${flashcard.languageCode})');
      }
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      print('❌ [FlashcardProvider] Error updating flashcard: $e');
      _errorMessage = 'Failed to update flashcard: $e';
      notifyListeners();
    }
  }

  // Remove a flashcard
  Future<void> removeFlashcard(Flashcard flashcard) async {
    try {
      if (_isGuest) {
        // For guest users, remove from local database
        await _dbHelper.deleteFlashcardByUuid(flashcard.uuid);
        _flashcards.removeWhere((f) => f.uuid == flashcard.uuid);
        _updateDueCards();
        print('🗑️ [FlashcardProvider] Removed flashcard from local database: ${flashcard.originalText}');
      } else {
        // For signed-in users, remove from both local database and cloud
        await _dbHelper.deleteFlashcardByUuid(flashcard.uuid);
        await _cloudFlashcardService.removeFlashcard(flashcard.languageCode, flashcard.uuid);
        _flashcards.removeWhere((f) => f.uuid == flashcard.uuid);
        _updateDueCards();
        print('🗑️ [FlashcardProvider] Removed flashcard from local DB and cloud: ${flashcard.originalText} (language: ${flashcard.languageCode})');
      }
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      print('❌ [FlashcardProvider] Error removing flashcard: $e');
      _errorMessage = 'Failed to remove flashcard: $e';
      notifyListeners();
    }
  }

  // Mark a flashcard as reviewed (update spaced repetition data)
  Future<void> markAsReviewed(Flashcard flashcard, bool wasCorrect) async {
    try {
      // Update flashcard with new study data
      final updatedFlashcard = flashcard.markAsStudied();
      
      if (_isGuest) {
        // For guest users, update in local database
        await _dbHelper.updateFlashcard(updatedFlashcard);
        final index = _flashcards.indexWhere((f) => f.uuid == flashcard.uuid);
        if (index != -1) {
          _flashcards[index] = updatedFlashcard;
          _updateDueCards();
        }
        print('✅ [FlashcardProvider] Marked flashcard as reviewed in local database: ${flashcard.originalText}');
      } else {
        // For signed-in users, update in both local database and cloud
        await _dbHelper.updateFlashcardByUuid(updatedFlashcard);
        await _cloudFlashcardService.updateFlashcard(updatedFlashcard.languageCode, updatedFlashcard);
        final index = _flashcards.indexWhere((f) => f.uuid == flashcard.uuid);
        if (index != -1) {
          _flashcards[index] = updatedFlashcard;
          _updateDueCards();
        }
        print('✅ [FlashcardProvider] Marked flashcard as reviewed in local DB and cloud: ${flashcard.originalText} (language: ${updatedFlashcard.languageCode})');
      }
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      print('❌ [FlashcardProvider] Error marking flashcard as reviewed: $e');
      _errorMessage = 'Failed to mark flashcard as reviewed: $e';
      notifyListeners();
    }
  }

  // Get flashcards by search query
  List<Flashcard> searchFlashcards(String query) {
    if (query.isEmpty) return _flashcards;
    
    final lowercaseQuery = query.toLowerCase();
    return _flashcards.where((flashcard) =>
      flashcard.originalText.toLowerCase().contains(lowercaseQuery) ||
      flashcard.translatedText.toLowerCase().contains(lowercaseQuery) ||
      (flashcard.category?.toLowerCase().contains(lowercaseQuery) ?? false)
    ).toList();
  }

  // Get flashcards by category
  List<Flashcard> getFlashcardsByCategory(String category) {
    return _flashcards.where((flashcard) => 
      flashcard.category?.toLowerCase() == category.toLowerCase()
    ).toList();
  }

  // Get all categories
  List<String> get categories {
    final categories = _flashcards.map((flashcard) => flashcard.category).where((category) => category != null).cast<String>().toSet();
    return categories.toList()..sort();
  }

  // Get flashcard count by category
  int getFlashcardCountByCategory(String category) {
    return _flashcards.where((flashcard) => 
      flashcard.category?.toLowerCase() == category.toLowerCase()
    ).length;
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Clear all in-memory data when switching accounts
  void clear() {
    _flashcards.clear();
    _dueCards.clear();
    _isLoading = false;
    _errorMessage = null;
    
    // Stop listening to cloud streams
    _flashcardsStream?.drain();
    _flashcardsStream = null;
    
    notifyListeners();
  }

  // Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
} 