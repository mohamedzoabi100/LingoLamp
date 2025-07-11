import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class Phrase {
  final String id;
  final String english;
  final String spanish;
  final String category;
  final String? pronunciation;
  final bool isFavorite;
  final DateTime? lastPracticed;

  Phrase({
    required this.id,
    required this.english,
    required this.spanish,
    required this.category,
    this.pronunciation,
    this.isFavorite = false,
    this.lastPracticed,
  });

  Phrase copyWith({
    String? id,
    String? english,
    String? spanish,
    String? category,
    String? pronunciation,
    bool? isFavorite,
    DateTime? lastPracticed,
  }) {
    return Phrase(
      id: id ?? this.id,
      english: english ?? this.english,
      spanish: spanish ?? this.spanish,
      category: category ?? this.category,
      pronunciation: pronunciation ?? this.pronunciation,
      isFavorite: isFavorite ?? this.isFavorite,
      lastPracticed: lastPracticed ?? this.lastPracticed,
    );
  }
}

class PhraseCategory {
  final String id;
  final String title;
  final String description;
  final String icon;
  final Color color;
  final int phraseCount;

  PhraseCategory({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.phraseCount,
  });
}

class PhrasebookProvider extends ChangeNotifier {
  List<Phrase> _phrases = [];
  List<PhraseCategory> _categories = [];
  List<Phrase> _favorites = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<Phrase> get phrases => _phrases;
  List<PhraseCategory> get categories => _categories;
  List<Phrase> get favorites => _favorites;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadPhrases() async {
    try {
      _isLoading = true;
      notifyListeners();

      // TODO: Load phrases from database/CSV
      await Future.delayed(const Duration(milliseconds: 300));

      _categories = [
        PhraseCategory(
          id: 'food',
          title: 'Food & Dining',
          description: 'Essential phrases for restaurants and food shopping',
          icon: '🍽️',
          color: const Color(0xFFFF9800),
          phraseCount: 25,
        ),
        PhraseCategory(
          id: 'transport',
          title: 'Transport',
          description: 'Getting around, directions, and transportation',
          icon: '🚗',
          color: const Color(0xFF2196F3),
          phraseCount: 20,
        ),
        PhraseCategory(
          id: 'emergencies',
          title: 'Emergencies',
          description: 'Important phrases for urgent situations',
          icon: '🚨',
          color: const Color(0xFFF44336),
          phraseCount: 15,
        ),
        PhraseCategory(
          id: 'greetings',
          title: 'Greetings',
          description: 'Basic greetings and polite expressions',
          icon: '👋',
          color: const Color(0xFF4CAF50),
          phraseCount: 18,
        ),
        PhraseCategory(
          id: 'shopping',
          title: 'Shopping',
          description: 'Shopping, prices, and bargaining phrases',
          icon: '🛍️',
          color: const Color(0xFF9C27B0),
          phraseCount: 22,
        ),
        PhraseCategory(
          id: 'accommodation',
          title: 'Accommodation',
          description: 'Hotel, booking, and accommodation needs',
          icon: '🏨',
          color: const Color(0xFF795548),
          phraseCount: 16,
        ),
      ];

      _phrases = [
        Phrase(
          id: '1',
          english: 'Hello',
          spanish: 'Hola',
          category: 'greetings',
          pronunciation: 'OH-lah',
        ),
        Phrase(
          id: '2',
          english: 'Goodbye',
          spanish: 'Adiós',
          category: 'greetings',
          pronunciation: 'ah-DEE-ohs',
        ),
        Phrase(
          id: '3',
          english: 'Thank you',
          spanish: 'Gracias',
          category: 'greetings',
          pronunciation: 'GRAH-see-ahs',
        ),
        Phrase(
          id: '4',
          english: 'Please',
          spanish: 'Por favor',
          category: 'greetings',
          pronunciation: 'pohr fah-VOHR',
        ),
        Phrase(
          id: '5',
          english: 'Excuse me',
          spanish: 'Perdón',
          category: 'greetings',
          pronunciation: 'pehr-DOHN',
        ),
        Phrase(
          id: '6',
          english: 'I would like to eat',
          spanish: 'Me gustaría comer',
          category: 'food',
          pronunciation: 'meh goos-tah-REE-ah koh-MEHR',
        ),
        Phrase(
          id: '7',
          english: 'The bill, please',
          spanish: 'La cuenta, por favor',
          category: 'food',
          pronunciation: 'lah KWEHN-tah pohr fah-VOHR',
        ),
        Phrase(
          id: '8',
          english: 'Where is the bathroom?',
          spanish: '¿Dónde está el baño?',
          category: 'emergencies',
          pronunciation: 'DOHN-deh ehs-TAH ehl BAH-nyoh',
        ),
      ];

      _loadFavorites();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load phrases: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _loadFavorites() {
    _favorites = _phrases.where((phrase) => phrase.isFavorite).toList();
  }

  List<Phrase> getPhrasesByCategory(String categoryId) {
    return _phrases.where((phrase) => phrase.category == categoryId).toList();
  }

  Future<void> toggleFavorite(String phraseId) async {
    try {
      final phraseIndex = _phrases.indexWhere((phrase) => phrase.id == phraseId);
      if (phraseIndex == -1) return;

      final phrase = _phrases[phraseIndex];
      final updatedPhrase = phrase.copyWith(isFavorite: !phrase.isFavorite);

      _phrases[phraseIndex] = updatedPhrase;
      _loadFavorites();
      notifyListeners();

      // TODO: Save to database
    } catch (e) {
      _errorMessage = 'Failed to update favorite: $e';
      notifyListeners();
    }
  }

  Future<void> markAsPracticed(String phraseId) async {
    try {
      final phraseIndex = _phrases.indexWhere((phrase) => phrase.id == phraseId);
      if (phraseIndex == -1) return;

      final phrase = _phrases[phraseIndex];
      final updatedPhrase = phrase.copyWith(lastPracticed: DateTime.now());

      _phrases[phraseIndex] = updatedPhrase;
      notifyListeners();

      // TODO: Save to database
    } catch (e) {
      _errorMessage = 'Failed to update practice: $e';
      notifyListeners();
    }
  }

  List<Phrase> searchPhrases(String query) {
    if (query.isEmpty) return [];
    
    final lowercaseQuery = query.toLowerCase();
    return _phrases.where((phrase) {
      return phrase.english.toLowerCase().contains(lowercaseQuery) ||
             phrase.spanish.toLowerCase().contains(lowercaseQuery) ||
             (phrase.pronunciation?.toLowerCase().contains(lowercaseQuery) ?? false);
    }).toList();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
} 