//lib/screens/flashcards_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/flashcard_model.dart';
import '../utils/database_helper.dart';

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> with SingleTickerProviderStateMixin {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<Flashcard> _flashcards = [];
  List<Flashcard> _filteredFlashcards = [];
  bool _isLoading = true;
  String _currentFilter = 'all'; // all, favorites, easy, medium, hard
  late TabController _tabController;
  late FlutterTts _tts;
  bool _isStudyMode = false;
  int _currentStudyIndex = 0;
  bool _showAnswer = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initTts();
    _loadFlashcards();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<void> _initTts() async {
    _tts = FlutterTts();
    await _tts.setSpeechRate(0.5);
  }

  Future<void> _loadFlashcards() async {
    setState(() => _isLoading = true);
    try {
      List<Flashcard> flashcards = await _dbHelper.getAllFlashcards();
      setState(() {
        _flashcards = flashcards;
        _applyFilter();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading flashcards: $e')),
        );
      }
    }
  }

  void _applyFilter() {
    switch (_currentFilter) {
      case 'favorites':
        _filteredFlashcards = _flashcards.where((f) => f.isFavorite).toList();
        break;
      case 'easy':
        _filteredFlashcards = _flashcards.where((f) => f.difficulty == 1).toList();
        break;
      case 'medium':
        _filteredFlashcards = _flashcards.where((f) => f.difficulty == 2).toList();
        break;
      case 'hard':
        _filteredFlashcards = _flashcards.where((f) => f.difficulty == 3).toList();
        break;
      default:
        _filteredFlashcards = List.from(_flashcards);
    }
  }

  Future<void> _speakText(String text, String language) async {
    await _tts.setLanguage(language);
    await _tts.speak(text);
  }

  Future<void> _toggleFavorite(Flashcard flashcard) async {
    final updatedFlashcard = flashcard.copyWith(isFavorite: !flashcard.isFavorite);
    await _dbHelper.updateFlashcard(updatedFlashcard);
    _loadFlashcards();
  }

  Future<void> _updateDifficulty(Flashcard flashcard, int newDifficulty) async {
    final updatedFlashcard = flashcard.copyWith(difficulty: newDifficulty);
    await _dbHelper.updateFlashcard(updatedFlashcard);
    _loadFlashcards();
  }

  Future<void> _deleteFlashcard(Flashcard flashcard) async {
    await _dbHelper.deleteFlashcard(flashcard.id!);
    _loadFlashcards();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Flashcard deleted')),
      );
    }
  }

  Future<void> _markAsStudied(Flashcard flashcard) async {
    final updatedFlashcard = flashcard.copyWith(
      lastStudied: DateTime.now(),
      timesStudied: flashcard.timesStudied + 1,
    );
    await _dbHelper.updateFlashcard(updatedFlashcard);
  }

  void _startStudyMode() {
    if (_filteredFlashcards.isNotEmpty) {
      setState(() {
        _isStudyMode = true;
        _currentStudyIndex = 0;
        _showAnswer = false;
      });
    }
  }

  void _exitStudyMode() {
    setState(() {
      _isStudyMode = false;
      _showAnswer = false;
    });
  }

  void _nextCard() {
    if (_currentStudyIndex < _filteredFlashcards.length - 1) {
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

  Widget _buildFilterChips() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip('All', 'all'),
          _buildFilterChip('Favorites', 'favorites'),
          _buildFilterChip('Easy', 'easy'),
          _buildFilterChip('Medium', 'medium'),
          _buildFilterChip('Hard', 'hard'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String filter) {
    final isSelected = _currentFilter == filter;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _currentFilter = filter;
            _applyFilter();
          });
        },
        selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
        checkmarkColor: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildFlashcardsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredFlashcards.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _flashcards.isEmpty 
                ? 'No flashcards yet!\nAdd some from your chat translations.'
                : 'No flashcards match this filter.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildFilterChips(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_filteredFlashcards.length} flashcards',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (_filteredFlashcards.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: _startStudyMode,
                  icon: const Icon(Icons.quiz),
                  label: const Text('Study'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _filteredFlashcards.length,
            itemBuilder: (context, index) {
              return _buildFlashcardTile(_filteredFlashcards[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFlashcardTile(Flashcard flashcard) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              flashcard.originalText,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.volume_up),
                            onPressed: () => _speakText(
                              flashcard.originalText,
                              flashcard.sourceLanguage,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              flashcard.translatedText,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.volume_up),
                            onPressed: () => _speakText(
                              flashcard.translatedText,
                              flashcard.targetLanguage,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    flashcard.isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: flashcard.isFavorite ? Colors.red : null,
                  ),
                  onPressed: () => _toggleFavorite(flashcard),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildDifficultyChips(flashcard),
                const Spacer(),
                Text(
                  'Studied: ${flashcard.timesStudied}x',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') {
                      _deleteFlashcard(flashcard);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyChips(Flashcard flashcard) {
    return Row(
      children: [
        _buildDifficultyChip('Easy', 1, flashcard),
        _buildDifficultyChip('Medium', 2, flashcard),
        _buildDifficultyChip('Hard', 3, flashcard),
      ],
    );
  }

  Widget _buildDifficultyChip(String label, int difficulty, Flashcard flashcard) {
    final isSelected = flashcard.difficulty == difficulty;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(fontSize: 10),
        ),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            _updateDifficulty(flashcard, difficulty);
          }
        },
        selectedColor: _getDifficultyColor(difficulty).withOpacity(0.2),
        labelStyle: TextStyle(
          color: isSelected ? _getDifficultyColor(difficulty) : Colors.grey[600],
        ),
      ),
    );
  }

  Color _getDifficultyColor(int difficulty) {
    switch (difficulty) {
      case 1: return Colors.green;
      case 2: return Colors.orange;
      case 3: return Colors.red;
      default: return Colors.grey;
    }
  }

  Widget _buildStudyMode() {
    if (_filteredFlashcards.isEmpty) return Container();

    final flashcard = _filteredFlashcards[_currentStudyIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text('Study Mode (${_currentStudyIndex + 1}/${_filteredFlashcards.length})'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _exitStudyMode,
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Card(
                elevation: 8,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Text(
                        flashcard.originalText,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      IconButton(
                        icon: const Icon(Icons.volume_up, size: 32),
                        onPressed: () => _speakText(
                          flashcard.originalText,
                          flashcard.sourceLanguage,
                        ),
                      ),
                      if (_showAnswer) ...[
                        const SizedBox(height: 32),
                        const Divider(),
                        const SizedBox(height: 16),
                        Text(
                          flashcard.translatedText,
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.grey[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        IconButton(
                          icon: const Icon(Icons.volume_up, size: 28),
                          onPressed: () => _speakText(
                            flashcard.translatedText,
                            flashcard.targetLanguage,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              if (!_showAnswer)
                ElevatedButton(
                  onPressed: () {
                    setState(() => _showAnswer = true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: const Text('Show Answer'),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        _markAsStudied(flashcard);
                        _nextCard();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Correct'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        _markAsStudied(flashcard);
                        _nextCard();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Incorrect'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isStudyMode) {
      return _buildStudyMode();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flashcards'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'All Cards'),
            Tab(text: 'Study'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFlashcardsList(),
          _buildStudyMode(),
        ],
      ),
    );
  }
}