import 'package:flutter/material.dart';
import '../../models/flashcard_model.dart';
import '../../services/user_data_service.dart';
import '../../utils/database_helper.dart';

class BrowseFlashcardsList extends StatefulWidget {
  const BrowseFlashcardsList({super.key});

  @override
  State<BrowseFlashcardsList> createState() => _BrowseFlashcardsListState();
}

class _BrowseFlashcardsListState extends State<BrowseFlashcardsList> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final UserDataService _userSvc = UserDataService();

  final TextEditingController _searchCtrl = TextEditingController();

  List<Flashcard> _all = [];
  List<Flashcard> _visible = [];
  Set<String> _allTags = {};
  String _activeTag = '';

  bool _loading = true;

  // bulk-select
  bool _selectMode = false;
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final cards = await _db.getAllFlashcards();
    setState(() {
      _all = cards;
      _allTags = cards.expand((c) => c.tags).toSet();
      _loading = false;
    });
    _applyFilters();
  }

  void _applyFilters() {
    final query = _searchCtrl.text.toLowerCase();
    setState(() {
      _visible = _all.where((card) {
        final matchesQuery = card.originalText.toLowerCase().contains(query) ||
            card.translatedText.toLowerCase().contains(query);
        final matchesTag = _activeTag.isEmpty || card.tags.contains(_activeTag);
        return matchesQuery && matchesTag;
      }).toList();
    });
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

  Future<void> _deleteSelected() async {
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
      final card = _all.firstWhere((c) => c.id == id);
      await _userSvc.deleteFlashcard(card);
    }
    await _load();
    setState(() {
      _selectedIds.clear();
      _selectMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: _selectMode
          ? AppBar(
              title: Text('${_selectedIds.length} selected'),
              backgroundColor: Theme.of(context).colorScheme.primary,
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _deleteSelected,
                ),
              ],
            )
          : null,
      floatingActionButton: _selectMode
          ? FloatingActionButton(
              onPressed: _deleteSelected,
              tooltip: 'Delete selected',
              backgroundColor: Colors.red,
              child: const Icon(Icons.delete),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search flashcards...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          if (_allTags.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _activeTag.isEmpty,
                    onSelected: (_) {
                      setState(() {
                        _activeTag = '';
                        _applyFilters();
                      });
                    },
                  ),
                  ..._allTags.map((tag) => Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: ChoiceChip(
                          label: Text(tag),
                          selected: _activeTag == tag,
                          onSelected: (_) {
                            setState(() {
                              _activeTag = _activeTag == tag ? '' : tag;
                              _applyFilters();
                            });
                          },
                        ),
                      )),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: _visible.isEmpty
                ? const Center(child: Text('No cards match your filters'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: _visible.length,
                    itemBuilder: (context, index) {
                      final card = _visible[index];
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
                                          await _load();
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
  }
} 