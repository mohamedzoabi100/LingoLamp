import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/phrase_model.dart';
import '../../services/phrase_service.dart';
import '../../services/cloud_favorites_service.dart';
import '../providers/language_provider.dart';
import '../providers/auth_provider.dart';

// Theme model for phrasebook categories
class PhrasebookTheme {
  final String title;
  final IconData icon;
  final Color color;
  final int phraseCount;
  final String description;

  PhrasebookTheme({
    required this.title,
    required this.icon,
    required this.color,
    required this.phraseCount,
    required this.description,
  });
}

class PhrasebookProvider extends ChangeNotifier {
  final PhraseService _phraseService = PhraseService();
  final CloudFavoritesService _cloudFavoritesService = CloudFavoritesService();
  
  List<PhraseModel> _phrases = [];
  List<PhraseModel> _favorites = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _currentLanguage = 'es';
  bool _isGuest = false;
  Stream<List<Map<String, dynamic>>>? _favoritesStream;

  // Getters
  List<PhraseModel> get phrases => _phrases;
  List<PhraseModel> get favorites => _favorites;
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
    await _phraseService.init(languageCode: _currentLanguage);
    _listenToPhrases();
    _listenToLanguageChanges();
    if (!_isGuest) {
      _listenToFavoritesCloud();
    }
  }

  // Listen to phrase service streams
  void _listenToPhrases() {
    _phraseService.allPhrasesStream.listen((phrases) {
      _phrases = phrases;
      _favorites = phrases.where((phrase) => phrase.isFavorite).toList();
      notifyListeners();
    });

    _phraseService.favoritePhrasesStream.listen((favorites) {
      _favorites = favorites;
      notifyListeners();
    });
  }

  void _listenToFavoritesCloud() {
    _favoritesStream?.drain();
    _favoritesStream = _cloudFavoritesService.listenToFavorites(_currentLanguage);
    _favoritesStream!.listen((cloudFavorites) {
      // Map Firestore docs to PhraseModel (assume phraseId is stored)
      final ids = cloudFavorites.map((f) => f['phraseId'] as String).toSet();
      _favorites = _phrases.where((p) => ids.contains(p.id)).toList();
      // Update isFavorite on all phrases
      _phrases = _phrases.map((p) => p.copyWith(isFavorite: ids.contains(p.id))).toList();
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _favoritesStream = null;
    super.dispose();
  }

  // Listen to language changes
  void _listenToLanguageChanges() {
    // This will be called when language changes
    // We'll handle language changes in the screens that use this provider
  }

  // Method to handle language changes
  Future<void> onLanguageChanged(String newLanguage) async {
    if (_currentLanguage != newLanguage) {
      _currentLanguage = newLanguage;
      await _phraseService.reinitializeWithLanguage(newLanguage);
      notifyListeners();
    }
  }

  // Method to force refresh all data
  Future<void> forceRefresh() async {
    await _phraseService.forceRefreshFromDisk();
    notifyListeners();
  }

  // Method to check if provider is properly initialized
  bool get isInitialized => _phrases.isNotEmpty || _currentLanguage.isNotEmpty;

  // Get phrases by category
  List<PhraseModel> getPhrasesByCategory(String category) {
    return _phrases.where((phrase) => 
      phrase.category.toLowerCase() == category.toLowerCase()
    ).toList();
  }

  // Get AI generated phrases
  List<PhraseModel> getAiGeneratedPhrases() {
    return _phrases.where((phrase) => phrase.isAiGenerated).toList();
  }

  // Get phrases by search query
  List<PhraseModel> searchPhrases(String query) {
    if (query.isEmpty) return _phrases;
    
    final lowercaseQuery = query.toLowerCase();
    return _phrases.where((phrase) =>
      phrase.english.toLowerCase().contains(lowercaseQuery) ||
      phrase.spanish.toLowerCase().contains(lowercaseQuery) ||
      phrase.category.toLowerCase().contains(lowercaseQuery)
    ).toList();
  }

  // Get all categories
  List<String> get categories {
    final categories = _phrases.map((phrase) => phrase.category).toSet();
    return categories.toList()..sort();
  }

  // Get phrase count by category
  int getPhraseCountByCategory(String category) {
    return _phrases.where((phrase) => 
      phrase.category.toLowerCase() == category.toLowerCase()
    ).length;
  }

  // Add AI generated phrase
  Future<void> addAiPhrase(PhraseModel phrase) async {
    try {
      if (_isGuest) {
        await _phraseService.addAiPhrase(phrase);
      } else {
        // Add to Firestore: treat AI-generated phrases as regular phrases in Firestore
        // You may need a CloudPhraseService, but for now, use _phraseService if it supports Firestore, otherwise implement Firestore add here
        // For now, let's assume _phraseService.addAiPhrase handles Firestore for logged-in users
        await _phraseService.addAiPhrase(phrase);
        // If not, you would add Firestore logic here
      }
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to add AI phrase: $e';
      notifyListeners();
    }
  }

  // Toggle favorite
  Future<void> toggleFavorite(String phraseId, String languageCode) async {
    try {
      if (_isGuest) {
        await _phraseService.toggleFavorite(phraseId, languageCode);
      } else {
        final isFav = _favorites.any((p) => p.id == phraseId);
        if (isFav) {
          // Remove from Firestore
          final favDoc = await _cloudFavoritesService.getFavorites(languageCode);
          final doc = favDoc.firstWhere((f) => f['phraseId'] == phraseId, orElse: () => {});
          if (doc.isNotEmpty && doc['id'] != null) {
            await _cloudFavoritesService.removeFavorite(languageCode, doc['id']);
          }
        } else {
          // Add to Firestore
          await _cloudFavoritesService.addFavorite(languageCode, {'phraseId': phraseId});
        }
      }
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to toggle favorite: $e';
      notifyListeners();
    }
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Predefined themes
  List<PhrasebookTheme> get predefinedThemes => [
    PhrasebookTheme(
      title: 'Food & Dining',
      icon: Icons.restaurant,
      color: Colors.orange,
      phraseCount: getPhraseCountByCategory('Food & Dining'),
      description: 'Essential phrases for restaurants and food shopping',
    ),
    PhrasebookTheme(
      title: 'Transport',
      icon: Icons.directions_car,
      color: Colors.blue,
      phraseCount: getPhraseCountByCategory('Transport'),
      description: 'Getting around, directions, and transportation',
    ),
    PhrasebookTheme(
      title: 'Emergencies',
      icon: Icons.local_hospital,
      color: Colors.red,
      phraseCount: getPhraseCountByCategory('Emergencies'),
      description: 'Important phrases for urgent situations',
    ),
    PhrasebookTheme(
      title: 'Greetings',
      icon: Icons.waving_hand,
      color: Colors.green,
      phraseCount: getPhraseCountByCategory('Greetings'),
      description: 'Basic greetings and polite expressions',
    ),
    PhrasebookTheme(
      title: 'Shopping',
      icon: Icons.shopping_bag,
      color: Colors.purple,
      phraseCount: getPhraseCountByCategory('Shopping'),
      description: 'Shopping, prices, and bargaining phrases',
    ),
    PhrasebookTheme(
      title: 'Accommodation',
      icon: Icons.hotel,
      color: Colors.brown,
      phraseCount: getPhraseCountByCategory('Accommodation'),
      description: 'Hotel, booking, and accommodation needs',
    ),
  ];
} 