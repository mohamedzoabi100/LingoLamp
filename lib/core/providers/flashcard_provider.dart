import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import '../../models/flashcard_model.dart';
import '../../utils/database_helper.dart';
import '../../services/sync_service.dart';
import '../../services/xp_service.dart';
import '../../services/xp_event_tracker.dart';

class FlashcardProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final SyncService _syncService = SyncService();
  final XPService _xpService = XPService();

  List<Flashcard> _flashcards = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<Flashcard> get flashcards => _flashcards;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Stream<List<Flashcard>> get flashcardsStream => _dbHelper.flashcardsStream;

  FlashcardProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    await loadFlashcards();
    _listenToDatabaseChanges();
  }

  void _listenToDatabaseChanges() {
    _dbHelper.flashcardsStream.listen((flashcards) {
      _flashcards = flashcards;
      notifyListeners();
    });
  }

  Future<void> loadFlashcards() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _flashcards = await _dbHelper.getAllFlashcards();
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addFlashcard(String originalText, String translatedText, String category) async {
    try {
      final newCard = Flashcard(
        originalText: originalText,
        translatedText: translatedText,
        sourceLanguage: 'en',
        targetLanguage: 'es',
        createdAt: DateTime.now(),
        lastStudied: DateTime.now(),
        category: category,
      );

      // Insert into the database
      await _dbHelper.insertFlashcard(newCard);

      // Sync to cloud if user is authenticated
      if (_syncService.isAuthenticated) {
        await _syncService.syncFlashcards();
      }

      // Award XP for creating a flashcard
      final xpTracker = XPEventTracker();
      xpTracker.addXP(XPEventTracker.flashcardCreatedFromChat, 'Flashcard created');

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateFlashcard(Flashcard flashcard) async {
    try {
      await _dbHelper.updateFlashcard(flashcard);

      // Sync to cloud if user is authenticated
      if (_syncService.isAuthenticated) {
        await _syncService.syncFlashcards();
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteFlashcard(String uuid) async {
    try {
      await _dbHelper.deleteFlashcardByUuid(uuid);

      // Sync to cloud if user is authenticated
      if (_syncService.isAuthenticated) {
        await _syncService.syncFlashcards();
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> markFlashcardAsStudied(Flashcard flashcard) async {
    try {
      final updatedCard = flashcard.markAsStudied();
      await _dbHelper.updateFlashcard(updatedCard);

      // Sync to cloud if user is authenticated
      if (_syncService.isAuthenticated) {
        await _syncService.syncFlashcards();
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> toggleFavorite(Flashcard flashcard) async {
    try {
      final updatedCard = flashcard.copyWith(isFavorite: !flashcard.isFavorite);
      await _dbHelper.updateFlashcard(updatedCard);

      // Sync to cloud if user is authenticated
      if (_syncService.isAuthenticated) {
        await _syncService.syncFlashcards();
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  List<Flashcard> getFlashcardsByCategory(String category) {
    return _flashcards.where((card) => card.category == category).toList();
  }

  List<Flashcard> getFavoriteFlashcards() {
    return _flashcards.where((card) => card.isFavorite).toList();
  }

  List<Flashcard> getFlashcardsByLanguage(String languageCode) {
    return _flashcards.where((card) => card.languageCode == languageCode).toList();
  }

  // Sync methods
  Future<void> syncWithCloud() async {
    if (_syncService.isAuthenticated) {
      await _syncService.syncFlashcards();
    }
  }

  Future<void> pullFromCloud() async {
    if (_syncService.isAuthenticated) {
      await _syncService.pullFromCloud();
      await loadFlashcards(); // Reload after pulling
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
} 