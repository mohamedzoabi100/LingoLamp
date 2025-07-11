import 'package:flutter/foundation.dart';
import '../../models/flashcard_model.dart';
import '../../services/xp_event_tracker.dart';

class StudySession {
  final List<Flashcard> cards;
  final int currentIndex;
  final int totalCards;
  final DateTime startTime;

  StudySession({
    required this.cards,
    this.currentIndex = 0,
    required this.totalCards,
    required this.startTime,
  });

  bool get isComplete => currentIndex >= totalCards;
  Flashcard? get currentCard => cards.isNotEmpty && currentIndex < cards.length ? cards[currentIndex] : null;
}

class FlashcardProvider extends ChangeNotifier {
  List<Flashcard> _flashcards = [];
  List<Flashcard> _studyQueue = [];
  StudySession? _currentSession;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<Flashcard> get flashcards => _flashcards;
  List<Flashcard> get studyQueue => _studyQueue;
  StudySession? get currentSession => _currentSession;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadFlashcards() async {
    try {
      _isLoading = true;
      notifyListeners();

      // TODO: Load flashcards from database
      await Future.delayed(const Duration(milliseconds: 300));

      _flashcards = [
        Flashcard(
          originalText: 'Hello',
          translatedText: 'Hola',
          sourceLanguage: 'en',
          targetLanguage: 'es',
          createdAt: DateTime.now().subtract(const Duration(days: 5)),
          lastStudied: DateTime.now().subtract(const Duration(hours: 2)),
          timesStudied: 3,
          difficulty: 2,
          category: 'Greetings',
        ),
        Flashcard(
          originalText: 'Goodbye',
          translatedText: 'Adiós',
          sourceLanguage: 'en',
          targetLanguage: 'es',
          createdAt: DateTime.now().subtract(const Duration(days: 4)),
          lastStudied: DateTime.now().subtract(const Duration(days: 1)),
          timesStudied: 2,
          difficulty: 2,
          category: 'Greetings',
        ),
        Flashcard(
          originalText: 'Thank you',
          translatedText: 'Gracias',
          sourceLanguage: 'en',
          targetLanguage: 'es',
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
          lastStudied: DateTime.now().subtract(const Duration(hours: 6)),
          timesStudied: 5,
          difficulty: 1,
          category: 'Politeness',
        ),
      ];

      _generateStudyQueue();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load flashcards: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _generateStudyQueue() {
    // Simple spaced repetition algorithm
    final now = DateTime.now();
    _studyQueue = _flashcards.where((card) {
      if (card.lastStudied == null) return true;
      
      final daysSinceLastStudy = now.difference(card.lastStudied).inDays;
      final interval = _calculateInterval(card.timesStudied, card.difficulty);
      
      return daysSinceLastStudy >= interval;
    }).toList();
    
    // Sort by priority (due cards first, then by difficulty)
    _studyQueue.sort((a, b) {
      final aDue = a.lastStudied == null || 
          now.difference(a.lastStudied).inDays >= _calculateInterval(a.timesStudied, a.difficulty);
      final bDue = b.lastStudied == null || 
          now.difference(b.lastStudied).inDays >= _calculateInterval(b.timesStudied, b.difficulty);
      
      if (aDue && !bDue) return -1;
      if (!aDue && bDue) return 1;
      
      return a.difficulty.compareTo(b.difficulty);
    });
  }

  int _calculateInterval(int timesStudied, int difficulty) {
    // Simple spaced repetition intervals
    if (timesStudied == 0) return 0; // New card
    if (timesStudied == 1) return 1; // 1 day
    if (timesStudied == 2) return 3; // 3 days
    if (timesStudied == 3) return 7; // 1 week
    if (timesStudied == 4) return 14; // 2 weeks
    return 30; // 1 month
  }

  Future<void> startStudySession() async {
    if (_studyQueue.isEmpty) return;

    _currentSession = StudySession(
      cards: List.from(_studyQueue),
      totalCards: _studyQueue.length,
      startTime: DateTime.now(),
    );
    notifyListeners();
  }

  Future<void> markCardAsStudied(String cardId, int rating) async {
    try {
      final cardIndex = _flashcards.indexWhere((card) => card.uuid == cardId);
      if (cardIndex == -1) return;

      final card = _flashcards[cardIndex];
      final updatedCard = card.copyWith(
        lastStudied: DateTime.now(),
        timesStudied: card.timesStudied + 1,
        difficulty: _adjustDifficulty(card.difficulty, rating),
      );

      _flashcards[cardIndex] = updatedCard;
      
      // Update study queue
      _generateStudyQueue();
      
      // Update current session
      if (_currentSession != null) {
        final sessionCardIndex = _currentSession!.cards.indexWhere((card) => card.uuid == cardId);
        if (sessionCardIndex != -1) {
          _currentSession!.cards[sessionCardIndex] = updatedCard;
        }
      }

      notifyListeners();
      
      // TODO: Save to database
    } catch (e) {
      _errorMessage = 'Failed to update card: $e';
      notifyListeners();
    }
  }

  int _adjustDifficulty(int currentDifficulty, int rating) {
    // Rating: 1-5 (1 = very hard, 5 = very easy)
    if (rating <= 2 && currentDifficulty < 5) {
      return currentDifficulty + 1; // Make harder
    } else if (rating >= 4 && currentDifficulty > 1) {
      return currentDifficulty - 1; // Make easier
    }
    return currentDifficulty;
  }

  void nextCard() {
    if (_currentSession == null || _currentSession!.isComplete) return;
    
    _currentSession = StudySession(
      cards: _currentSession!.cards,
      currentIndex: _currentSession!.currentIndex + 1,
      totalCards: _currentSession!.totalCards,
      startTime: _currentSession!.startTime,
    );
    notifyListeners();
  }

  void endStudySession() {
    _currentSession = null;
    notifyListeners();
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

      _flashcards.add(newCard);
      _generateStudyQueue();
      notifyListeners();
      
      // Award XP for creating a flashcard
      final xpTracker = XPEventTracker();
      xpTracker.addXP(XPEventTracker.flashcardCreatedFromChat, 'Flashcard created from chat');
      
      // TODO: Save to database
    } catch (e) {
      _errorMessage = 'Failed to add flashcard: $e';
      notifyListeners();
    }
  }

  void updateFlashcard(Flashcard updated) {
    final index = _flashcards.indexWhere((c) => c.uuid == updated.uuid);
    if (index != -1) {
      _flashcards[index] = updated;
      _generateStudyQueue();
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
} 