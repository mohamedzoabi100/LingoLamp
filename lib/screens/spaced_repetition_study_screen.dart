import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/flashcard_model.dart';
import '../models/spaced_repetition_model.dart';
import '../models/study_card_model.dart';
import '../services/study_service.dart';
import '../services/cloud_tts_service.dart';
import '../services/xp_service.dart';
import '../core/providers/language_provider.dart';
import '../utils/database_helper.dart';

class SpacedRepetitionStudyScreen extends StatefulWidget {
  final VoidCallback? onBackToHome;

  const SpacedRepetitionStudyScreen({
    Key? key,
    this.onBackToHome,
  }) : super(key: key);

  @override
  State<SpacedRepetitionStudyScreen> createState() => _SpacedRepetitionStudyScreenState();
}

class _SpacedRepetitionStudyScreenState extends State<SpacedRepetitionStudyScreen> with WidgetsBindingObserver {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final CloudTtsService _cloudTts = CloudTtsService()..register();
  final XPService _xpService = XPService();
  List<StudyCard> _dueCards = [];
  int _currentIndex = 0;
  bool _showAnswer = false;
  DateTime _sessionStartTime = DateTime.now();
  int _totalAnswered = 0;
  int _correctAnswers = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDueCards();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen to language changes
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    languageProvider.addListener(_onLanguageChanged);
  }

  @override
  void dispose() {
    // Remove language listener
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    languageProvider.removeListener(_onLanguageChanged);
    // Stop TTS when leaving the screen
    _cloudTts.stop();
    _cloudTts.unregister();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
        // Stop TTS when app is paused, minimized, or closed
        _cloudTts.stop();
        break;
      case AppLifecycleState.resumed:
        // App resumed - no action needed
        break;
    }
  }

  void _onLanguageChanged() {
    // Reload due cards when language changes
    _loadDueCards();
  }

  Future<void> _loadDueCards() async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final flashcards = await _dbHelper.getFlashcardsByLanguage(languageProvider.currentLanguage);
    final spacedCards = await _dbHelper.getAllSpacedRepetitionCards();
    
    final studyCards = StudyService.createStudySession(flashcards, spacedCards);
    final dueCards = studyCards.where((card) => card.isDue).toList();
    
    if (mounted) {
      setState(() {
        _dueCards = dueCards;
        _currentIndex = 0;
        _showAnswer = false;
      });
    }
  }

  void _toggleAnswer() {
    setState(() => _showAnswer = !_showAnswer);
  }

  Future<void> _speakText(String text, String language) async {
    try {
      // Map language codes to Google Cloud TTS codes
      final ttsLanguageCode = _getTtsLanguageCode(language);
      final voiceName = _getVoiceName(language);
      
      await _cloudTts.speak(
        text: text,
        languageCode: ttsLanguageCode,
        voiceName: voiceName,
        speakingRate: 0.9,
      );
    } catch (e) {
      print('[SpacedRepetition] ERROR: Failed to speak text: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to play audio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getTtsLanguageCode(String language) {
    final languageMap = {
      'en': 'en-US',
      'es': 'es-ES',
      'fr': 'fr-FR',
      'de': 'de-DE',
      'it': 'it-IT',
      'pt': 'pt-BR',
    };
    return languageMap[language] ?? 'en-US';
  }

  String _getVoiceName(String language) {
    final voiceMap = {
      'en': 'en-US-Standard-A',
      'es': 'es-ES-Standard-A',
      'fr': 'fr-FR-Standard-A',
      'de': 'de-DE-Standard-A',
      'it': 'it-IT-Standard-A',
      'pt': 'pt-BR-Standard-A',
    };
    return voiceMap[language] ?? 'en-US-Standard-A';
  }

  Future<void> _processReview(ReviewQuality quality) async {
    if (_dueCards.isEmpty) return;

    final currentCard = _dueCards[_currentIndex];
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final updatedStudyCard = await StudyService.processReview(currentCard, quality, languageCode: languageProvider.currentLanguage);

    // Award XP based on review quality
    String difficulty = '';
    switch (quality) {
      case ReviewQuality.easy:
        difficulty = 'easy';
        break;
      case ReviewQuality.good:
        difficulty = 'good';
        break;
      case ReviewQuality.hard:
        difficulty = 'hard';
        break;
      case ReviewQuality.again:
        difficulty = 'again';
        break;
    }
    await _xpService.awardFlashcardReview(difficulty);

    // Persist changes to the database
    await _dbHelper.updateFlashcard(updatedStudyCard.flashcard);
    if (updatedStudyCard.spacedRepetitionCard != null) {
      if (updatedStudyCard.spacedRepetitionCard!.id != null) {
        await _dbHelper.updateSpacedRepetitionCard(updatedStudyCard.spacedRepetitionCard!);
      } else {
        await _dbHelper.insertSpacedRepetitionCard(updatedStudyCard.spacedRepetitionCard!);
      }
    }
    
    _nextCard();
  }

  void _nextCard() {
    if (_currentIndex < _dueCards.length - 1) {
      setState(() {
        _currentIndex++;
        _showAnswer = false;
      });
    } else {
      _showSessionComplete();
    }
  }

  void _showSessionComplete() {
    // final duration = DateTime.now().difference(_sessionStartTime);
    // final accuracy = _totalAnswered > 0 ? (_correctAnswers / _totalAnswered * 100).round() : 0;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Session Complete! 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Text('Cards reviewed: $_totalAnswered'),
            // Text('Correct answers: $_correctAnswers'),
            // Text('Accuracy: $accuracy%'),
            // Text('Time: ${duration.inMinutes}m ${duration.inSeconds % 60}s'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Finish'),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: _dueCards.isEmpty ? 0 : (_currentIndex + 1) / _dueCards.length,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
          ),
          const SizedBox(height: 8),
          Text(
            '${_currentIndex + 1} of ${_dueCards.length}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard() {
    if (_dueCards.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text(
              'No cards due for review!',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'Great job keeping up with your studies!',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final card = _dueCards[_currentIndex];
    final flashcard = card.flashcard;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _toggleAnswer,
              child: Card(
                elevation: 8,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: Theme.of(context).primaryColor,
                    width: 3,
                  ),
                ),
                child: Container(
                  width: double.infinity,
                  height: 300,
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!_showAnswer) ...[
                        Text(
                          flashcard.originalText,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        IconButton(
                          icon: Icon(Icons.volume_up, size: 32, color: Theme.of(context).primaryColor),
                          onPressed: () => _speakText(
                            flashcard.originalText,
                            flashcard.sourceLanguage,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Tap card to see translation',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).primaryColor,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ] else ...[
                        Text(
                          flashcard.originalText,
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        Divider(color: Theme.of(context).primaryColor, thickness: 2),
                        const SizedBox(height: 20),
                        Text(
                          flashcard.translatedText,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        IconButton(
                          icon: Icon(Icons.volume_up, size: 32, color: Theme.of(context).primaryColor),
                          onPressed: () => _speakText(
                            flashcard.translatedText,
                            flashcard.targetLanguage,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'How well did you know this?',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).primaryColor,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (_showAnswer) ...[
              const SizedBox(height: 32),
              _buildAnswerButtons(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerButtons() {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0),
      child: Column(
        children: [
          const Text(
            'How well did you know this?',
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildReviewButton('Again', Colors.red, ReviewQuality.again),
              _buildReviewButton('Hard', Colors.orange, ReviewQuality.hard),
              _buildReviewButton('Good', Colors.green, ReviewQuality.good),
              _buildReviewButton('Easy', Colors.blue, ReviewQuality.easy),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewButton(String label, Color color, ReviewQuality quality) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: ElevatedButton(
          onPressed: () => _processReview(quality),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(label, textAlign: TextAlign.center),
        ),
      ),
    );
  }

  Widget _buildStats() {
    // if (_totalAnswered == 0) return const SizedBox.shrink();
    
    // final accuracy = (_correctAnswers / _totalAnswered * 100).round();
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // _buildStatItem('Answered', _totalAnswered.toString()),
          // _buildStatItem('Correct', _correctAnswers.toString()),
          // _buildStatItem('Accuracy', '$accuracy%'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (widget.onBackToHome != null) {
              widget.onBackToHome!();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text('Spaced Repetition'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.white,
      body: _dueCards.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildProgressIndicator(),
                _buildStats(),
                Expanded(child: _buildCard()),
              ],
            ),
    );
  }
} 