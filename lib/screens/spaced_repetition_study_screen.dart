import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/flashcard_model.dart';
import '../models/spaced_repetition_model.dart';
import '../models/study_card_model.dart';
import '../services/study_service.dart';
import '../utils/database_helper.dart';

class SpacedRepetitionStudyScreen extends StatefulWidget {
  final VoidCallback? onBackToHome;
  const SpacedRepetitionStudyScreen({super.key, this.onBackToHome});

  @override
  State<SpacedRepetitionStudyScreen> createState() => _SpacedRepetitionStudyScreenState();
}

class _SpacedRepetitionStudyScreenState extends State<SpacedRepetitionStudyScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  
  List<StudyCard> _studyCards = [];
  List<StudyCard> _dueCards = [];
  int _currentIndex = 0;
  bool _showAnswer = false;
  bool _isLoading = true;
  late FlutterTts _tts;

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadStudyCards();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _initTts() async {
    _tts = FlutterTts();
    await _tts.setSpeechRate(0.5);
  }

  Future<void> _loadStudyCards() async {
    setState(() => _isLoading = true);
    
    try {
      List<Flashcard> flashcards = await _dbHelper.getAllFlashcards();
      List<SpacedRepetitionCard> spacedCards = await _dbHelper.getAllSpacedRepetitionCards();
      
      _studyCards = StudyService.createStudySession(flashcards, spacedCards);
      _dueCards = _studyCards.where((card) => card.isDue).toList();
      
      setState(() {
        _isLoading = false;
        _currentIndex = 0;
        _showAnswer = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading study cards: $e')),
        );
      }
    }
  }

  Future<void> _speakText(String text, String language) async {
    await _tts.setLanguage(language);
    await _tts.speak(text);
  }

  void _toggleAnswer() {
    setState(() => _showAnswer = !_showAnswer);
  }

  Future<void> _processReview(ReviewQuality quality) async {
    if (_dueCards.isEmpty) return;

    final currentCard = _dueCards[_currentIndex];
    final updatedStudyCard = StudyService.processReview(currentCard, quality);

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
      body: _isLoading
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