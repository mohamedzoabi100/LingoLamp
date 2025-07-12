import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/flashcard_model.dart';
import '../../services/user_data_service.dart';
import '../../utils/database_helper.dart';
import '../../core/providers/language_provider.dart';

class PaginatedFlashcardsList extends StatefulWidget {
  const PaginatedFlashcardsList({super.key});

  @override
  _PaginatedFlashcardsListState createState() => _PaginatedFlashcardsListState();
}

class _PaginatedFlashcardsListState extends State<PaginatedFlashcardsList> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final UserDataService _userDataService = UserDataService();
  final ScrollController _scrollController = ScrollController();

  List<Flashcard> _flashcards = [];
  bool _isLoading = false;
  bool _hasMore = true;
  final int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadInitialFlashcards();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialFlashcards() async {
    setState(() => _isLoading = true);
    
    // Get current language from provider
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final currentLanguage = languageProvider.currentLanguage;
    
    final flashcards = await _dbHelper.getFlashcardsPaginatedByLanguage(
      limit: _pageSize, 
      offset: 0, 
      languageCode: currentLanguage
    );
    setState(() {
      _flashcards = flashcards;
      _isLoading = false;
      _hasMore = flashcards.length == _pageSize;
    });
  }

  Future<void> _loadMoreFlashcards() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    // Get current language from provider
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final currentLanguage = languageProvider.currentLanguage;
    
    final offset = _flashcards.length;
    final newFlashcards = await _dbHelper.getFlashcardsPaginatedByLanguage(
      limit: _pageSize, 
      offset: offset, 
      languageCode: currentLanguage
    );

    setState(() {
      _flashcards.addAll(newFlashcards);
      _isLoading = false;
      _hasMore = newFlashcards.length == _pageSize;
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
      _loadMoreFlashcards();
    }
  }

  Future<void> _toggleFavorite(Flashcard flashcard) async {
    final updatedFlashcard = flashcard.copyWith(isFavorite: !flashcard.isFavorite);
    await _userDataService.updateFlashcard(updatedFlashcard);
    // The main screen's stream will update the stats, here we just update the local state
    setState(() {
      final index = _flashcards.indexWhere((f) => f.id == flashcard.id);
      if (index != -1) {
        _flashcards[index] = updatedFlashcard;
      }
    });
  }

  Future<void> _deleteFlashcard(Flashcard flashcard) async {
    await _userDataService.deleteFlashcard(flashcard);
    setState(() {
      _flashcards.removeWhere((f) => f.id == flashcard.id);
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Flashcard deleted')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_flashcards.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_flashcards.isEmpty && !_hasMore) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No flashcards yet!\nAdd some from your chat translations.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _flashcards.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _flashcards.length) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _buildFlashcardTile(_flashcards[index]);
      },
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
                      Text(
                        flashcard.originalText,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        flashcard.translatedText,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
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
} 