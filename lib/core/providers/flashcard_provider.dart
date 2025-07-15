import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import '../../models/flashcard_model.dart';
import '../../utils/database_helper.dart';
import '../../services/sync_service.dart';
import '../../services/xp_service.dart';
import '../../services/xp_event_tracker.dart';
import '../../services/cloud_flashcard_service.dart';
import '../providers/auth_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

class FlashcardProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final CloudFlashcardService _cloudFlashcardService = CloudFlashcardService();
  final XPService _xpService = XPService();

  List<Flashcard> _flashcards = [];
  bool _isLoading = false;
  String? _error;
  bool _isGuest = false;
  String _currentLanguage = 'es';
  Stream<List<Map<String, dynamic>>>? _flashcardsStream;

  // Getters
  List<Flashcard> get flashcards => _flashcards;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Context-aware init
  Future<void> init({String? languageCode, required BuildContext context}) async {
    if (languageCode != null) _currentLanguage = languageCode;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _isGuest = authProvider.isGuest;
    if (_isGuest) {
      await loadFlashcardsLocal();
      _listenToDatabaseChanges();
    } else {
      _listenToFlashcardsCloud();
    }
  }

  void _listenToFlashcardsCloud() {
    _flashcardsStream?.drain();
    _flashcardsStream = _cloudFlashcardService.listenToFlashcards(_currentLanguage);
    _flashcardsStream!.listen((cloudFlashcards) {
      _flashcards = cloudFlashcards.map((f) => Flashcard.fromMap(f)).toList();
      notifyListeners();
    });
  }

  void _listenToDatabaseChanges() {
    _dbHelper.flashcardsStream.listen((flashcards) {
      _flashcards = flashcards;
      notifyListeners();
    });
  }

  Future<void> loadFlashcardsLocal() async {
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

  // CRUD methods
  Future<void> addFlashcard(Flashcard flashcard) async {
    try {
      if (_isGuest) {
        await _dbHelper.insertFlashcard(flashcard);
      } else {
        await _cloudFlashcardService.addFlashcard(_currentLanguage, flashcard.toMap());
      }
      await _xpService.awardFlashcardCreated();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateFlashcard(Flashcard flashcard) async {
    try {
      if (_isGuest) {
        await _dbHelper.updateFlashcard(flashcard);
      } else {
        if (flashcard.uuid.isEmpty) return;
        await _cloudFlashcardService.updateFlashcard(_currentLanguage, flashcard.uuid, flashcard.toMap());
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteFlashcard(String uuid) async {
    try {
      if (_isGuest) {
        await _dbHelper.deleteFlashcardByUuid(uuid);
      } else {
        await _cloudFlashcardService.removeFlashcard(_currentLanguage, uuid);
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> markFlashcardAsStudied(Flashcard flashcard) async {
    try {
      final updatedCard = flashcard.markAsStudied();
      await updateFlashcard(updatedCard);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> toggleFavorite(Flashcard flashcard) async {
    try {
      final updatedCard = flashcard.copyWith(isFavorite: !flashcard.isFavorite);
      await updateFlashcard(updatedCard);
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

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _flashcardsStream = null;
    super.dispose();
  }
} 