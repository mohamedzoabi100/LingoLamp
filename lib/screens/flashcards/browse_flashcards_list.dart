import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/flashcard_model.dart';
import '../../core/providers/language_provider.dart';
import '../../core/providers/flashcard_provider.dart';

class BrowseFlashcardsList extends StatefulWidget {
  const BrowseFlashcardsList({super.key});

  @override
  State<BrowseFlashcardsList> createState() => _BrowseFlashcardsListState();
}

class _BrowseFlashcardsListState extends State<BrowseFlashcardsList> {
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
    // Removed redundant provider initialization - main flashcards screen handles this
    // This was causing refresh loops
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

    final flashcardProvider = context.read<FlashcardProvider>();
    final ids = _selectedIds.toList();
    for (final id in ids) {
      final card = all.firstWhere((c) => c.id == id);
      await flashcardProvider.removeFlashcard(card);
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
        return Consumer<FlashcardProvider>(
          builder: (context, flashcardProvider, child) {
            final all = flashcardProvider.flashcards;
            print('📊 [BROWSE] Received ${all.length} flashcards from provider for language: ${languageProvider.currentLanguage}');
            
            // Check for duplicates in the provider's list
            final duplicates = <String, List<Flashcard>>{};
            for (final card in all) {
              final key = '${card.originalText}_${card.translatedText}';
              duplicates.putIfAbsent(key, () => []).add(card);
            }
            
            final actualDuplicates = duplicates.values.where((cards) => cards.length > 1);
            if (actualDuplicates.isNotEmpty) {
              print('⚠️ [BROWSE] Found ${actualDuplicates.length} duplicate groups in provider:');
              for (final group in actualDuplicates) {
                print('   - "${group.first.originalText}" appears ${group.length} times');
              }
            }
            
            if (all.isNotEmpty) {
              print('📝 [BROWSE] First flashcard: ${all.first.toMap()}');
              print('📝 [BROWSE] Last flashcard: ${all.last.toMap()}');
            }
            
            // The provider already filters by language, so use the flashcards directly
            _allTags = all.expand((c) => c.tags).toSet();
            final visible = _applyFiltersToList(all);
            print('👁️ [BROWSE] After search filtering: ${visible.length} visible flashcards');

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
                        : RefreshIndicator(
                            onRefresh: () async {
                              final flashcardProvider = context.read<FlashcardProvider>();
                              await flashcardProvider.forceRefresh();
                            },
                            child: ListView.builder(
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
                                                  await flashcardProvider.removeFlashcard(card);
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