import 'package:flutter/material.dart';
import '../models/recommended_flashcard_model.dart';
import '../utils/database_helper.dart';
import '../models/flashcard_model.dart';

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  late Stream<List<RecommendedFlashcard>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _db.recommendedStream;
  }

  Future<void> _addFlashcard(RecommendedFlashcard rec) async {
    final card = Flashcard(
      originalText: rec.term,
      translatedText: rec.context,
      sourceLanguage: 'en',
      targetLanguage: 'es',
      createdAt: DateTime.now(),
      lastStudied: DateTime.now(),
    );
    await _db.insertFlashcard(card);
    await _db.deleteRecommended(rec.id!);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added "${rec.term}" to flashcards!')),
      );
    }
  }

  Future<void> _dismiss(RecommendedFlashcard rec) async {
    await _db.deleteRecommended(rec.id!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recommendations'),
        foregroundColor: Colors.white,
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: StreamBuilder<List<RecommendedFlashcard>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final recs = snapshot.data!;
          if (recs.isEmpty) {
            return const Center(child: Text('No recommendations yet'));
          }
          return ListView.separated(
            itemCount: recs.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (context, index) {
              final rec = recs[index];
              return ListTile(
                leading: Icon(rec.source == 'chat' ? Icons.chat_bubble_outline : Icons.star_outline),
                title: Text(rec.term, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(rec.context, maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    IconButton(
                      tooltip: 'Add',
                      icon: const Icon(Icons.add),
                      color: Colors.green,
                      onPressed: () => _addFlashcard(rec),
                    ),
                    IconButton(
                      tooltip: 'Dismiss',
                      icon: const Icon(Icons.close),
                      color: Colors.red,
                      onPressed: () => _dismiss(rec),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
} 