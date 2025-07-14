//lib/screens/flashcards_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/flashcard_model.dart';
import '../services/user_data_service.dart';
import '../services/study_service.dart';
import '../services/cloud_tts_service.dart';
import '../core/providers/language_provider.dart';
import '../models/spaced_repetition_model.dart';
import '../models/study_card_model.dart';
import '../models/recommended_flashcard_model.dart';
import '../utils/database_helper.dart';
import 'spaced_repetition_study_screen.dart';
import 'recommendations_screen.dart';
import 'flashcards/browse_flashcards_list.dart';

class FlashcardsScreen extends StatefulWidget {
  final VoidCallback? onBackToHome;

  const FlashcardsScreen({
    Key? key,
    this.onBackToHome,
  }) : super(key: key);

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> with TickerProviderStateMixin {
  final UserDataService _userDataService = UserDataService();
  final CloudTtsService _cloudTts = CloudTtsService()..register();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  late TabController _tabController;
  late Stream<List<Flashcard>> _flashcardsStream;
  late Stream<List<RecommendedFlashcard>> _recommendedStream;
  List<StudyCard> _studyCards = [];
  List<StudyCard> _reviewQueue = [];
  int _currentIndex = 0;
  bool _showAnswer = false;
  bool _isStudyMode = false;
  int _currentStudyIndex = 0;
  bool _showStudyAnswer = false;
  LanguageProvider? _languageProvider; // Store reference

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFlashcards();
    _loadReviewQueue();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only add listener once
    _languageProvider ??= Provider.of<LanguageProvider>(context, listen: false);
    _languageProvider!.addListener(_onLanguageChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    // Remove language listener
    _languageProvider?.removeListener(_onLanguageChanged); // Use stored reference
    // Stop TTS when leaving the screen
    _cloudTts.stop();
    _cloudTts.unregister();
    super.dispose();
  }

  void _onLanguageChanged() {
    // Reload flashcards when language changes
    _loadFlashcards();
    _loadReviewQueue();
  }

  Future<void> _loadFlashcards() async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    _flashcardsStream = _dbHelper.flashcardsStream;
    _recommendedStream = _dbHelper.recommendedStream;
  }

  Future<void> _loadReviewQueue() async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final allFlashcards = await _dbHelper.getFlashcardsByLanguage(languageProvider.currentLanguage);
    final spacedCards = await _dbHelper.getAllSpacedRepetitionCards();
    
    _studyCards = StudyService.createStudySession(allFlashcards, spacedCards);
    _reviewQueue = _studyCards.where((card) => card.isDue).toList();
    
    if (mounted) {
      setState(() {});
    }
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
      print('[Flashcards] ERROR: Failed to speak text: $e');
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

  Future<void> _markAsStudied(Flashcard flashcard) async {
    final updatedFlashcard = flashcard.copyWith(
      lastStudied: DateTime.now(),
      timesStudied: flashcard.timesStudied + 1,
    );
    await _userDataService.updateFlashcard(updatedFlashcard);
  }

  void _startStudyMode(List<Flashcard> filteredFlashcards) {
    if (filteredFlashcards.isNotEmpty) {
      setState(() {
        _isStudyMode = true;
        _currentStudyIndex = 0;
        _showAnswer = false;
      });
    }
  }

  void _startSpacedRepetitionMode() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SpacedRepetitionStudyScreen(
          onBackToHome: widget.onBackToHome,
        ),
      ),
    ).then((_) => _loadReviewQueue()); // Reload study cards after returning
  }

  void _exitStudyMode() {
    setState(() {
      _isStudyMode = false;
      _showAnswer = false;
    });
  }

  void _nextCard(List<Flashcard> filteredFlashcards) {
    if (_currentStudyIndex < filteredFlashcards.length - 1) {
      setState(() {
        _currentStudyIndex++;
        _showAnswer = false;
      });
    } else {
      _exitStudyMode();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Study session complete! 🎉')),
      );
    }
  }

  Widget _buildReviewStats() {
    final stats = StudyService.getStudyStats(_studyCards);
    final dueCards = stats['dueCards'] as int;
    final totalCards = stats['totalCards'] as int;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).primaryColor.withAlpha(75)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              Text(
                'Study Statistics',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem('Total Cards', totalCards.toString()),
              _buildStatItem('Due Today', dueCards.toString()),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: dueCards > 0 ? _startSpacedRepetitionMode : null,
                  icon: const Icon(Icons.schedule),
                  label: Text('Review ($dueCards)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: dueCards > 0 ? Colors.green : Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // This needs access to the filtered list from StreamBuilder
                    // We'll pass it down from the main build method.
                  }, // Logic moved to where filtered list is available
                  icon: const Icon(Icons.quiz),
                  label: const Text('Study All'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
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
            fontSize: 24,
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

  Widget _buildReviewMode() {
    if (_reviewQueue.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            const Text('No cards due for review!', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            const Text('Great job keeping up with your studies!', style: TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
      );
    }

    final studyCard = _reviewQueue[_currentIndex];
    final flashcard = studyCard.flashcard;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () {
                setState(() => _showAnswer = !_showAnswer);
              },
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
                  child: SingleChildScrollView(
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
                            onPressed: () => _speakText(flashcard.originalText, flashcard.sourceLanguage),
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
                            'Tap card to flip back',
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
            ),
            const SizedBox(height: 32),
            if (_showAnswer)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildReviewBtn('Again', Colors.red, ReviewQuality.again),
                  _buildReviewBtn('Hard', Colors.orange, ReviewQuality.hard),
                  _buildReviewBtn('Good', Colors.green, ReviewQuality.good),
                  _buildReviewBtn('Easy', Colors.blue, ReviewQuality.easy),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewBtn(String label, Color color, ReviewQuality quality) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: ElevatedButton(
          onPressed: () => _processReview(_reviewQueue[_currentIndex], quality),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: Text(label, textAlign: TextAlign.center),
        ),
      ),
    );
  }

  Future<void> _processReview(StudyCard card, ReviewQuality quality) async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final updated = await StudyService.processReview(card, quality, languageCode: languageProvider.currentLanguage);

    // Persist changes
    await _dbHelper.updateFlashcard(updated.flashcard);
    if (updated.spacedRepetitionCard != null) {
      if (updated.spacedRepetitionCard!.id != null) {
        await _dbHelper.updateSpacedRepetitionCard(updated.spacedRepetitionCard!);
      } else {
        await _dbHelper.insertSpacedRepetitionCard(updated.spacedRepetitionCard!);
      }
    }

    if (_currentIndex < _reviewQueue.length - 1) {
      setState(() {
        _currentIndex++;
        _showAnswer = false;
      });
    } else {
      _showSessionComplete();
    }
  }

  void _showSessionComplete() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Session Complete! 🎉'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _loadReviewQueue();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return StreamBuilder<List<Flashcard>>(
          stream: _flashcardsStream,
          builder: (context, snapshot) {
            print('🔄 [FLASHCARDS] StreamBuilder update - hasData: ${snapshot.hasData}, dataLength: ${snapshot.data?.length ?? 0}');
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              print('❌ [FLASHCARDS] Stream error: ${snapshot.error}');
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final allFlashcards = snapshot.data ?? [];
            print('📊 [FLASHCARDS] Received ${allFlashcards.length} flashcards from stream');
            if (allFlashcards.isNotEmpty) {
              print('📝 [FLASHCARDS] First flashcard: ${allFlashcards.first.toMap()}');
              print('📝 [FLASHCARDS] Last flashcard: ${allFlashcards.last.toMap()}');
            }
            
            // Filter flashcards by current language
            final currentLanguage = languageProvider.currentLanguage;
            final filteredFlashcards = allFlashcards.where((flashcard) => 
              flashcard.languageCode == currentLanguage
            ).toList();
            
            print('🔍 [FLASHCARDS] Filtered to ${filteredFlashcards.length} flashcards for language: $currentLanguage');

            return DefaultTabController(
              length: 2,
              child: Scaffold(
                appBar: AppBar(
                  leading: null,
                  title: const Text('Flashcards'),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  bottom: TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.white,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    tabs: const [
                      Tab(text: 'Review'),
                      Tab(text: 'Browse'),
                    ],
                  ),
                  actions: [
                    StreamBuilder<List<RecommendedFlashcard>>(
                      stream: _recommendedStream,
                      builder: (context, snap) {
                        final allRecommendations = snap.data ?? [];
                        // Filter recommendations by current language
                        final currentLanguage = languageProvider.currentLanguage;
                        final filteredRecommendations = allRecommendations.where((rec) => 
                          rec.languageCode == currentLanguage
                        ).toList();
                        final count = filteredRecommendations.length;
                        return IconButton(
                          tooltip: 'Recommendations',
                          icon: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              const Icon(Icons.lightbulb_outline),
                              if (count > 0)
                                Positioned(
                                  right: -2,
                                  top: -2,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                    child: Text(
                                      '$count',
                                      style: const TextStyle(color: Colors.white, fontSize: 10),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const RecommendationsScreen()),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildReviewMode(),
                    BrowseFlashcardsList(),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}