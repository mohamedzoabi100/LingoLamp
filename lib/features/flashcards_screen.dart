import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../core/providers/flashcard_provider.dart';

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _showBack = false;
  late TabController _tabController;
  int _reviewIndex = 0;
  bool _reviewShowBack = false;
  List<int> _reviewOrder = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flashcards'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Review'),
            Tab(text: 'Browse'),
          ],
        ),
      ),
      body: Consumer<FlashcardProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final allCards = provider.flashcards;
          if (allCards.isEmpty) {
            return _buildEmptyState();
          }
          final now = DateTime.now();
          final dueCards = allCards.where((c) => c.nextReview == null || c.nextReview!.isBefore(now)).toList();
          // REVIEW TAB
          Widget reviewTab;
          if (dueCards.isEmpty) {
            reviewTab = Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.celebration, size: 64, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 16),
                  Text('No cards due for review!', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text('Come back later or add more cards.', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            );
          } else {
            // Clamp reviewIndex to available due cards
            _reviewIndex = _reviewIndex.clamp(0, dueCards.length - 1);
            final card = dueCards[_reviewIndex];
            reviewTab = Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Center(
                    child: GestureDetector(
                      onTap: () => setState(() => _reviewShowBack = !_reviewShowBack),
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: MediaQuery.of(context).size.width * 0.85,
                          height: 260,
                          padding: const EdgeInsets.all(24),
                          child: _reviewShowBack
                              ? MarkdownBody(
                                  data: card.translatedText,
                                  styleSheet: MarkdownStyleSheet(
                                    p: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface,
                                      fontSize: 20,
                                      height: 1.4,
                                    ),
                                    strong: const TextStyle(fontWeight: FontWeight.bold),
                                    em: const TextStyle(fontStyle: FontStyle.italic),
                                  ),
                                )
                              : MarkdownBody(
                                  data: card.originalText,
                                  styleSheet: MarkdownStyleSheet(
                                    p: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      height: 1.4,
                                    ),
                                    strong: const TextStyle(fontWeight: FontWeight.bold),
                                    em: const TextStyle(fontStyle: FontStyle.italic),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Card ${_reviewIndex + 1} of ${dueCards.length} due', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 16),
                if (!_reviewShowBack)
                  ElevatedButton(
                    onPressed: () => setState(() => _reviewShowBack = true),
                    child: const Text('Show Answer'),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _reviewButton(context, 'Again', Colors.red, () => _rateCard(context, provider, card, 0)),
                      _reviewButton(context, 'Hard', Colors.orange, () => _rateCard(context, provider, card, 3)),
                      _reviewButton(context, 'Good', Colors.blue, () => _rateCard(context, provider, card, 4)),
                      _reviewButton(context, 'Easy', Colors.green, () => _rateCard(context, provider, card, 5)),
                    ],
                  ),
                const SizedBox(height: 24),
              ],
            );
          }
          // BROWSE TAB (existing UI)
          final card = allCards[_currentIndex];
          Widget browseTab = Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: GestureDetector(
                    onTap: () => setState(() => _showBack = !_showBack),
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: MediaQuery.of(context).size.width * 0.85,
                        height: 260,
                        padding: const EdgeInsets.all(24),
                        child: _showBack
                            ? MarkdownBody(
                                data: card.translatedText,
                                styleSheet: MarkdownStyleSheet(
                                  p: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontSize: 20,
                                    height: 1.4,
                                  ),
                                  strong: const TextStyle(fontWeight: FontWeight.bold),
                                  em: const TextStyle(fontStyle: FontStyle.italic),
                                ),
                              )
                                                          : MarkdownBody(
                                  data: card.originalText,
                                styleSheet: MarkdownStyleSheet(
                                  p: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    height: 1.4,
                                  ),
                                  strong: const TextStyle(fontWeight: FontWeight.bold),
                                  em: const TextStyle(fontStyle: FontStyle.italic),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Card ${_currentIndex + 1} of ${allCards.length}', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _currentIndex > 0
                        ? () => setState(() {
                              _currentIndex--;
                              _showBack = false;
                            })
                        : null,
                  ),
                  const SizedBox(width: 24),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _currentIndex < allCards.length - 1
                        ? () => setState(() {
                              _currentIndex++;
                              _showBack = false;
                            })
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          );
          return TabBarView(
            controller: _tabController,
            children: [
              reviewTab,
              browseTab,
            ],
          );
        },
      ),
    );
  }

  Widget _reviewButton(BuildContext context, String label, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 40),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }

  void _rateCard(BuildContext context, FlashcardProvider provider, card, int quality) {
    // SM-2 algorithm (simplified)
    final now = DateTime.now();
    int repetitions = card.repetitions ?? 0;
    double ease = card.easeFactor ?? 2.5;
    int interval = card.interval ?? 1;
    if (quality < 3) {
      repetitions = 0;
      interval = 1;
    } else {
      repetitions += 1;
      if (repetitions == 1) {
        interval = 1;
      } else if (repetitions == 2) {
        interval = 6;
      } else {
        interval = (interval * ease).round();
      }
      ease = (ease + 0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02)).clamp(1.3, 2.5);
    }
    final nextReview = now.add(Duration(days: interval));
    final updated = card.copyWith(
      nextReview: nextReview,
      interval: interval,
      easeFactor: ease,
      repetitions: repetitions,
    );
    provider.updateFlashcard(updated);
    setState(() {
      _reviewShowBack = false;
      if (_reviewIndex < provider.flashcards.where((c) => c.nextReview == null || c.nextReview!.isBefore(now)).length - 1) {
        _reviewIndex++;
      } else {
        _reviewIndex = 0;
      }
    });
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.style_outlined, size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            'No flashcards yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Save words or phrases from chat to start reviewing!',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
} 