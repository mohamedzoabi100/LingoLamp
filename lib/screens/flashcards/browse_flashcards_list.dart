import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/flashcard_model.dart';
import '../../services/user_data_service.dart';
import '../../utils/database_helper.dart';
import '../../core/providers/language_provider.dart';
import '../../core/providers/flashcard_provider.dart';

class BrowseFlashcardsList extends StatefulWidget {
  const BrowseFlashcardsList({super.key});

  @override
  State<BrowseFlashcardsList> createState() => _BrowseFlashcardsListState();
}

class _BrowseFlashcardsListState extends State<BrowseFlashcardsList> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final UserDataService _userSvc = UserDataService();

  final TextEditingController _searchCtrl = TextEditingController();

  Set<String> _allTags = {};
  String _activeTag = '';

  bool _loading = true;

  // bulk-select
  bool _selectMode = false;
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final languageProvider = context.read<LanguageProvider>();
      await context.read<FlashcardProvider>().init(languageCode: languageProvider.currentLanguage, context: context);
    });
    // _searchCtrl.addListener(_applyFilters); // No longer needed
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Flashcard> _applyFiltersToList(List<Flashcard> cards) {
    final query = _searchCtrl.text.toLowerCase();
    // Only filter by search query now, not tags
    return cards.where((card) {
      return card.originalText.toLowerCase().contains(query) ||
             card.translatedText.toLowerCase().contains(query);
    }).toList();
  }

  void _toggleSelect(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _selectMode = false;
      } else {
        _selectedIds.add(id);
        _selectMode = true;
      }
    });
  }

  Future<void> _deleteSelected(List<Flashcard> all) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete selected cards?'),
        content: Text('This will permanently delete ${_selectedIds.length} flashcards.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    final ids = _selectedIds.toList();
    for (final id in ids) {
      final card = all.firstWhere((c) => c.id == id);
      await _userSvc.deleteFlashcard(card);
    }
    setState(() {
      _selectedIds.clear();
      _selectMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return StreamBuilder<List<Flashcard>>(
          stream: _db.flashcardsStream,
          builder: (context, snapshot) {
            print('🔄 [BROWSE] StreamBuilder update - hasData: ${snapshot.hasData}, dataLength: ${snapshot.data?.length ?? 0}');
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final all = snapshot.data!;
            print('📊 [BROWSE] Received ${all.length} flashcards from stream');
            if (all.isNotEmpty) {
              print('📝 [BROWSE] First flashcard: ${all.first.toMap()}');
              print('📝 [BROWSE] Last flashcard: ${all.last.toMap()}');
            }
            
            // Filter flashcards by current language
            final currentLanguage = languageProvider.currentLanguage;
            final languageFiltered = all.where((flashcard) => 
              flashcard.languageCode == currentLanguage
            ).toList();
            
            print('🔍 [BROWSE] Filtered to ${languageFiltered.length} flashcards for language: $currentLanguage');
            
            _allTags = languageFiltered.expand((c) => c.tags).toSet();
            final visible = _applyFiltersToList(languageFiltered);
            print('👁️ [BROWSE] After filtering: ${visible.length} visible flashcards');

            return Scaffold(
              appBar: _selectMode
                  ? AppBar(
                      title: Text('${_selectedIds.length} selected'),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteSelected(all),
                        ),
                      ],
                    )
                  : null,
              floatingActionButton: _selectMode
                  ? FloatingActionButton(
                      onPressed: () => _deleteSelected(all),
                      tooltip: 'Delete selected',
                      backgroundColor: Colors.red,
                      child: const Icon(Icons.delete),
                    )
                  : null,
              body: Column(
                children: [
                  // Search box removed
                  // Removed tag filter chips here
                  const SizedBox(height: 8),
                  Expanded(
                    child: visible.isEmpty
                        ? const Center(child: Text('No cards match your filters'))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            itemCount: visible.length,
                            itemBuilder: (context, index) {
                              final card = visible[index];
                              final selected = _selectedIds.contains(card.id);
                              return GestureDetector(
                                onLongPress: () => _toggleSelect(card.id!),
                                onTap: _selectMode ? () => _toggleSelect(card.id!) : null,
                                child: Card(
                                  elevation: 2,
                                  color: selected
                                      ? Theme.of(context).colorScheme.primary.withOpacity(.15)
                                      : Colors.white,
                                  margin: const EdgeInsets.only(bottom: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          card.originalText,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Container(height: 1, color: Colors.grey[300]),
                                        const SizedBox(height: 8),
                                        Text(
                                          card.translatedText,
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Theme.of(context).colorScheme.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            if (_selectMode)
                                              Checkbox(
                                                value: selected,
                                                onChanged: (_) => _toggleSelect(card.id!),
                                              )
                                            else
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline),
                                                tooltip: 'Delete',
                                                onPressed: () async {
                                                  await _userSvc.deleteFlashcard(card);
                                                },
                                              ),
                                          ],
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
} 