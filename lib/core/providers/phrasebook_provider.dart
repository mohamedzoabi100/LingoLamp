import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/phrase_model.dart';
import '../../services/phrase_service.dart';

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
  
  List<PhraseModel> _phrases = [];
  List<PhraseModel> _favorites = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<PhraseModel> get phrases => _phrases;
  List<PhraseModel> get favorites => _favorites;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Initialize the provider
  Future<void> init() async {
    await _phraseService.init();
    _listenToPhrases();
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
      await _phraseService.addAiPhrase(phrase);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to add AI phrase: $e';
      notifyListeners();
    }
  }

  // Toggle favorite
  Future<void> toggleFavorite(String phraseId) async {
    try {
      await _phraseService.toggleFavorite(phraseId);
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