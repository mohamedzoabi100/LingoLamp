import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/recommended_flashcard_model.dart';
import '../../services/cloud_recommendation_service.dart';
import '../../utils/database_helper.dart';
import '../providers/language_provider.dart';
import '../providers/auth_provider.dart';

class RecommendationProvider extends ChangeNotifier {
  final CloudRecommendationService _cloudRecommendationService = CloudRecommendationService();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  
  List<RecommendedFlashcard> _recommendations = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _currentLanguage = 'es';
  bool _isGuest = false;
  Stream<List<RecommendedFlashcard>>? _recommendationsStream;
  
  // Add debouncing to prevent excessive updates
  DateTime? _lastUpdateTime;
  static const Duration _updateDebounceTime = Duration(milliseconds: 500);

  // Getters
  List<RecommendedFlashcard> get recommendations => _recommendations;
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
    
    await _loadRecommendations();
    if (!_isGuest) {
      // Clean up invalid document IDs and duplicates on initialization
      try {
        await _cloudRecommendationService.cleanupInvalidIds(_currentLanguage);
        await _cloudRecommendationService.cleanupDuplicates(_currentLanguage);
      } catch (e) {
        print('⚠️ [RecommendationProvider] Error cleaning up invalid IDs or duplicates: $e');
      }
      _listenToRecommendationsCloud();
    }
  }

  // Load recommendations from local database (for both guest and signed-in users)
  Future<void> _loadRecommendations() async {
    try {
      _setLoading(true);
      
      if (_isGuest) {
        // For guest users, load from local database
        _recommendations = await _dbHelper.getRecommendationsByLanguage(_currentLanguage);
        print('📚 [RecommendationProvider] Loaded ${_recommendations.length} guest recommendations for $_currentLanguage');
      } else {
        // For signed-in users, load from cloud for ALL languages and ensure they have local IDs
        final allCloudRecommendations = await _cloudRecommendationService.getAllRecommendations();
        print('📚 [RecommendationProvider] Loaded ${allCloudRecommendations.length} cloud recommendations from all languages');
        
        // Save cloud recommendations to local database to ensure they have IDs
        for (final recommendation in allCloudRecommendations) {
          try {
            // Check if recommendation already exists in local database
            final existing = await _dbHelper.getRecommendationByTerm(recommendation.term);
            if (existing == null) {
              // Insert new recommendation to get an ID
              await _dbHelper.addRecommendation(recommendation);
              print('💾 [RecommendationProvider] Saved cloud recommendation to local DB: ${recommendation.term} (${recommendation.languageCode})');
            }
          } catch (e) {
            print('⚠️ [RecommendationProvider] Error saving cloud recommendation to local DB: $e');
          }
        }
        
        // Load all recommendations from local database and filter by current language
        final allRecommendations = await _dbHelper.getAllRecommendations();
        _recommendations = allRecommendations.where((r) => r.languageCode == _currentLanguage).toList();
        print('📚 [RecommendationProvider] Loaded ${_recommendations.length} recommendations for $_currentLanguage (total in DB: ${allRecommendations.length})');
      }
      
      _setLoading(false);
    } catch (e) {
      print('❌ [RecommendationProvider] Error loading recommendations: $e');
      _errorMessage = 'Failed to load recommendations: $e';
      _setLoading(false);
    }
  }

  // Listen to cloud recommendations changes (signed-in users only)
  void _listenToRecommendationsCloud() {
    _recommendationsStream?.drain();
    _recommendationsStream = _cloudRecommendationService.listenToRecommendations(_currentLanguage);
    _recommendationsStream!.listen((cloudRecommendations) async {
      print('🔄 [RecommendationProvider] Cloud stream update for $_currentLanguage: ${cloudRecommendations.length} recommendations');
      
      // Debounce updates to prevent excessive refreshes
      final now = DateTime.now();
      if (_lastUpdateTime != null && now.difference(_lastUpdateTime!) < _updateDebounceTime) {
        print('⏱️ [RecommendationProvider] Debouncing update (too soon after last update)');
        return;
      }
      _lastUpdateTime = now;
      
      // For signed-in users, we need to preserve recommendations from other languages
      // Get all recommendations from local database to preserve other languages
      final allLocalRecommendations = await _dbHelper.getAllRecommendations();
      print('📊 [RecommendationProvider] Total local recommendations: ${allLocalRecommendations.length}');
      
      // Remove recommendations for current language (they will be replaced by cloud data)
      final otherLanguageRecommendations = allLocalRecommendations.where((r) => r.languageCode != _currentLanguage).toList();
      print('📊 [RecommendationProvider] Other language recommendations: ${otherLanguageRecommendations.length}');
      
      // Save new cloud recommendations to local database
      for (final recommendation in cloudRecommendations) {
        try {
          final existing = await _dbHelper.getRecommendationByTerm(recommendation.term);
          if (existing == null) {
            await _dbHelper.addRecommendation(recommendation);
            print('💾 [RecommendationProvider] Saved new cloud recommendation to local DB: ${recommendation.term} (${recommendation.languageCode})');
          }
        } catch (e) {
          print('⚠️ [RecommendationProvider] Error saving cloud recommendation to local DB: $e');
        }
      }
      
      // Only show recommendations for the current language
      _recommendations = cloudRecommendations;
      
      print('🔄 [RecommendationProvider] Cloud recommendations updated: ${cloudRecommendations.length} recommendations for $_currentLanguage');
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _recommendationsStream = null;
    super.dispose();
  }

  // Method to handle language changes
  Future<void> onLanguageChanged(String newLanguage) async {
    if (_currentLanguage != newLanguage) {
      print('🔄 [RecommendationProvider] Language changing from $_currentLanguage to $newLanguage');
      print('📊 [RecommendationProvider] Before change: ${_recommendations.length} recommendations in memory');
      
      _currentLanguage = newLanguage;
      await _loadRecommendations();
      if (!_isGuest) {
        _listenToRecommendationsCloud();
      }
      notifyListeners();
      
      print('📊 [RecommendationProvider] After change: ${_recommendations.length} recommendations in memory for $newLanguage');
    }
  }

  // Method to force refresh all data
  Future<void> forceRefresh() async {
    await _loadRecommendations();
    notifyListeners();
  }

  // Method to force refresh all languages from cloud (for debugging)
  Future<void> forceRefreshAllLanguages() async {
    if (_isGuest) {
      await _loadRecommendations();
    } else {
      try {
        _setLoading(true);
        print('🔄 [RecommendationProvider] Force refreshing all languages from cloud');
        
        // Clean up invalid document IDs and duplicates first
        await _cloudRecommendationService.cleanupInvalidIds(_currentLanguage);
        await _cloudRecommendationService.cleanupDuplicates(_currentLanguage);
        
        // Load all recommendations from cloud
        final allCloudRecommendations = await _cloudRecommendationService.getAllRecommendations();
        print('📚 [RecommendationProvider] Loaded ${allCloudRecommendations.length} cloud recommendations from all languages');
        
        // Save all cloud recommendations to local database
        for (final recommendation in allCloudRecommendations) {
          try {
            final existing = await _dbHelper.getRecommendationByTerm(recommendation.term);
            if (existing == null) {
              await _dbHelper.addRecommendation(recommendation);
              print('💾 [RecommendationProvider] Saved cloud recommendation to local DB: ${recommendation.term} (${recommendation.languageCode})');
            }
          } catch (e) {
            print('⚠️ [RecommendationProvider] Error saving cloud recommendation to local DB: $e');
          }
        }
        
        // Load current language recommendations
        final allRecommendations = await _dbHelper.getAllRecommendations();
        _recommendations = allRecommendations.where((r) => r.languageCode == _currentLanguage).toList();
        print('📚 [RecommendationProvider] Loaded ${_recommendations.length} recommendations for $_currentLanguage (total in DB: ${allRecommendations.length})');
        
        _setLoading(false);
        notifyListeners();
      } catch (e) {
        print('❌ [RecommendationProvider] Error force refreshing all languages: $e');
        _errorMessage = 'Failed to refresh all languages: $e';
        _setLoading(false);
        notifyListeners();
      }
    }
  }

  // Method to check if provider is properly initialized
  bool get isInitialized => _recommendations.isNotEmpty || _currentLanguage.isNotEmpty;

  // Add a new recommendation
  Future<void> addRecommendation(RecommendedFlashcard recommendation) async {
    try {
      print('📝 [RecommendationProvider] Adding recommendation: "${recommendation.term}" (language: ${recommendation.languageCode})');
      
      // Check if this term already exists as a flashcard
      final existingFlashcard = await _dbHelper.getFlashcardByOriginalText(recommendation.term);
      if (existingFlashcard != null) {
        print('⚠️ [RecommendationProvider] Term "${recommendation.term}" already exists as flashcard, skipping recommendation');
        return;
      }
      
      // Check if this term already exists as a recommendation
      final existingRecommendation = await _dbHelper.getRecommendationByTerm(recommendation.term);
      if (existingRecommendation != null) {
        print('⚠️ [RecommendationProvider] Term "${recommendation.term}" already exists as recommendation, skipping');
        return;
      }
      
      if (_isGuest) {
        // For guest users, save to local database
        await _dbHelper.addRecommendation(recommendation);
        _recommendations.add(recommendation);
        print('📝 [RecommendationProvider] Added recommendation to local database: ${recommendation.term}');
      } else {
        // For signed-in users, save to both local database and cloud
        await _dbHelper.addRecommendation(recommendation);
        await _cloudRecommendationService.addRecommendation(recommendation.languageCode, recommendation);
        _recommendations.add(recommendation);
        print('📝 [RecommendationProvider] Added recommendation to local DB and cloud: ${recommendation.term} (language: ${recommendation.languageCode})');
      }
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      print('❌ [RecommendationProvider] Error adding recommendation: $e');
      _errorMessage = 'Failed to add recommendation: $e';
      notifyListeners();
    }
  }

  // Remove a recommendation
  Future<void> removeRecommendation(int recommendationId) async {
    try {
      if (_isGuest) {
        // For guest users, remove from local database
        await _dbHelper.removeRecommendation(recommendationId);
        _recommendations.removeWhere((r) => r.id == recommendationId);
        print('🗑️ [RecommendationProvider] Removed recommendation from local database: $recommendationId');
      } else {
        // For signed-in users, remove from both local database and cloud
        await _dbHelper.removeRecommendation(recommendationId);
        await _cloudRecommendationService.removeRecommendation(_currentLanguage, recommendationId);
        _recommendations.removeWhere((r) => r.id == recommendationId);
        print('🗑️ [RecommendationProvider] Removed recommendation from local DB and cloud: $recommendationId (language: $_currentLanguage)');
      }
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      print('❌ [RecommendationProvider] Error removing recommendation: $e');
      _errorMessage = 'Failed to remove recommendation: $e';
      notifyListeners();
    }
  }

  // Remove recommendation by term (used when adding to flashcards)
  Future<void> removeRecommendationByTerm(String term) async {
    try {
      print('🗑️ [RecommendationProvider] Attempting to remove recommendation by term: $term');
      
      // First try to find in local recommendations list
      final recommendation = _recommendations.firstWhere((r) => r.term == term);
      if (recommendation.id != null) {
        if (_isGuest) {
          await _dbHelper.removeRecommendation(recommendation.id!);
        } else {
          await _cloudRecommendationService.removeRecommendationByTerm(_currentLanguage, term);
        }
        _recommendations.removeWhere((r) => r.term == term);
        print('🗑️ [RecommendationProvider] Removed recommendation by term from local list: $term');
      }
    } catch (e) {
      print('⚠️ [RecommendationProvider] Recommendation not found in local list, trying database lookup: $e');
      
      // If not found in local list, try to find in database and remove
      try {
        final dbRecommendation = await _dbHelper.getRecommendationByTerm(term);
        if (dbRecommendation != null && dbRecommendation.id != null) {
          if (_isGuest) {
            await _dbHelper.removeRecommendation(dbRecommendation.id!);
          } else {
            await _cloudRecommendationService.removeRecommendationByTerm(_currentLanguage, term);
          }
          _recommendations.removeWhere((r) => r.term == term);
          print('🗑️ [RecommendationProvider] Removed recommendation by term from database: $term');
        } else {
          print('⚠️ [RecommendationProvider] Recommendation not found in database either: $term');
        }
      } catch (dbError) {
        print('❌ [RecommendationProvider] Error removing recommendation from database: $dbError');
      }
    }
    
    // Always try to remove from cloud for signed-in users, regardless of local state
    if (!_isGuest) {
      try {
        await _cloudRecommendationService.removeRecommendationByTerm(_currentLanguage, term);
        print('🗑️ [RecommendationProvider] Removed recommendation by term from cloud: $term');
      } catch (cloudError) {
        print('❌ [RecommendationProvider] Error removing recommendation from cloud: $cloudError');
      }
    }
  }

  // Dismiss a recommendation (add to dismissed list and remove from active)
  Future<void> dismissRecommendation(int recommendationId) async {
    try {
      // Get the recommendation to add its term to dismissed list
      final recommendation = _recommendations.firstWhere((r) => r.id == recommendationId);
      
      if (_isGuest) {
        // For guest users, add to dismissed and remove from active
        await _dbHelper.addDismissedRecommendation(recommendation.term);
        await _dbHelper.dismissRecommendation(recommendationId);
        _recommendations.removeWhere((r) => r.id == recommendationId);
        print('🚫 [RecommendationProvider] Dismissed recommendation in local database: ${recommendation.term}');
      } else {
        // For signed-in users, remove from cloud (will trigger stream update)
        await _cloudRecommendationService.removeRecommendation(_currentLanguage, recommendationId);
        print('🚫 [RecommendationProvider] Dismissed recommendation in cloud: ${recommendation.term}');
      }
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      print('❌ [RecommendationProvider] Error dismissing recommendation: $e');
      _errorMessage = 'Failed to dismiss recommendation: $e';
      notifyListeners();
    }
  }

  // Get recommendations by search query
  List<RecommendedFlashcard> searchRecommendations(String query) {
    if (query.isEmpty) return _recommendations;
    
    final lowercaseQuery = query.toLowerCase();
    return _recommendations.where((recommendation) =>
      recommendation.term.toLowerCase().contains(lowercaseQuery) ||
      recommendation.context.toLowerCase().contains(lowercaseQuery) ||
      (recommendation.source?.toLowerCase().contains(lowercaseQuery) ?? false)
    ).toList();
  }

  // Get recommendations by source
  List<RecommendedFlashcard> getRecommendationsBySource(String source) {
    return _recommendations.where((recommendation) => 
      recommendation.source?.toLowerCase() == source.toLowerCase()
    ).toList();
  }

  // Get all sources
  List<String> get sources {
    final sources = _recommendations.map((recommendation) => recommendation.source).where((source) => source != null).cast<String>().toSet();
    return sources.toList()..sort();
  }

  // Get recommendation count by source
  int getRecommendationCountBySource(String source) {
    return _recommendations.where((recommendation) => 
      recommendation.source?.toLowerCase() == source.toLowerCase()
    ).length;
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Clear all in-memory data when switching accounts
  void clear() {
    _recommendations.clear();
    _isLoading = false;
    _errorMessage = null;
    
    // Stop listening to cloud streams
    _recommendationsStream?.drain();
    _recommendationsStream = null;
    
    notifyListeners();
  }

  // Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Manual cleanup method for testing
  Future<void> cleanupCloudData() async {
    if (_isGuest) return;
    
    try {
      print('🧹 [RecommendationProvider] Starting manual cloud cleanup...');
      await _cloudRecommendationService.cleanupInvalidIds(_currentLanguage);
      await _cloudRecommendationService.cleanupDuplicates(_currentLanguage);
      print('✅ [RecommendationProvider] Manual cloud cleanup completed');
    } catch (e) {
      print('❌ [RecommendationProvider] Error during manual cleanup: $e');
    }
  }
} 