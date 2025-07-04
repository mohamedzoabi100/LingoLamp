import 'package:flutter/material.dart';
import '../models/recommended_flashcard_model.dart';
import '../utils/database_helper.dart';
import '../models/flashcard_model.dart';
import '../services/phrase_service.dart';
import '../models/phrase_model.dart';
import '../services/recommendation_service.dart';
import '../services/ai_phrase_service.dart';

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final RecommendationService _recommendationService = RecommendationService();
  late Stream<List<RecommendedFlashcard>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _db.recommendedStream;
  }

  Future<void> _addFlashcard(RecommendedFlashcard rec) async {
    // Lookup translation from PhraseService
    final phraseList = await PhraseService().allPhrasesStream.first;
    PhraseModel? phrase;
    try {
      phrase = phraseList.firstWhere(
        (p) => p.english.trim().toLowerCase() == rec.term.trim().toLowerCase(),
      );
    } catch (_) {
      phrase = null;
    }
    String? translated = phrase?.spanish;

    // If not found, try AI translation
    if (translated == null || translated.trim().isEmpty || translated.trim().toLowerCase() == rec.term.trim().toLowerCase()) {
      // Try AI translation
      final aiPhrase = await AiPhraseService().generatePhrase(topic: null, difficulty: null, context: null);
      if (aiPhrase != null && aiPhrase.english.trim().toLowerCase() == rec.term.trim().toLowerCase()) {
        translated = aiPhrase.spanish;
      }
    }

    // If still not found, prompt the user for a Spanish translation
    if (translated == null || translated.trim().isEmpty || translated.trim().toLowerCase() == rec.term.trim().toLowerCase()) {
      translated = await showDialog<String>(
        context: context,
        builder: (context) {
          final controller = TextEditingController();
          return AlertDialog(
            title: const Text('Enter Spanish Translation'),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Spanish translation for "${rec.term}"',
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
      if (translated == null || translated.isEmpty) {
        // User cancelled or didn't enter anything
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Flashcard not added: Spanish translation required.')),
          );
        }
        return;
      }
    }

    final card = Flashcard(
      originalText: rec.term,
      translatedText: translated,
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
    await _recommendationService.dismissRecommendation(rec.term);
    await _db.deleteRecommended(rec.id!);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dismissed "${rec.term}"'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recommendations'),
        foregroundColor: Colors.white,
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear dismissed recommendations',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear Dismissed'),
                  content: const Text('This will allow dismissed recommendations to reappear. Continue?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );
              
              if (confirmed == true) {
                await _recommendationService.clearDismissedRecommendations();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cleared dismissed recommendations')),
                  );
                }
              }
            },
          ),
        ],
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