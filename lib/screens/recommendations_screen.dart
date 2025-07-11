import 'package:flutter/material.dart';
import 'dart:async';
import '../models/recommended_flashcard_model.dart';
import '../utils/database_helper.dart';
import '../models/flashcard_model.dart';
import '../services/phrase_service.dart';
import '../models/phrase_model.dart';
import '../services/recommendation_service.dart';
import '../services/ai_phrase_service.dart';
import '../services/ai_chat_service.dart';
import '../services/xp_service.dart';

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  final RecommendationService _recommendationService = RecommendationService();
  final XPService _xpService = XPService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recommendations'),
        foregroundColor: Colors.white,
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: StreamBuilder<List<RecommendedFlashcard>>(
        stream: DatabaseHelper.instance.recommendedStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final recs = snapshot.data!;
          if (recs.isEmpty) {
            return const Center(child: Text('No recommendations yet.')); 
          }
          return ListView.separated(
            itemCount: recs.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (context, index) {
              final rec = recs[index];
              return ListTile(
                leading: const Icon(Icons.lightbulb_outline),
                title: Text(rec.term, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(rec.context, maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    IconButton(
                      tooltip: 'Add',
                      icon: const Icon(Icons.add),
                      color: Colors.green,
                      onPressed: () async {
                        // Add as flashcard
                        final flashcard = Flashcard(
                          originalText: rec.term,
                          translatedText: rec.context,
                          sourceLanguage: 'en',
                          targetLanguage: 'es',
                          createdAt: DateTime.now(),
                          lastStudied: DateTime.now(),
                          timesStudied: 0,
                          difficulty: 2,
                          isFavorite: false,
                          category: 'Recommended',
                          tags: ['recommended'],
                        );
                        await DatabaseHelper.instance.insertFlashcard(flashcard);
                        await _recommendationService.removeRecommendation(rec.id!);
                        await _xpService.awardFlashcardCreated();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Added "${rec.term}" to flashcards! 📚 +10 XP'), backgroundColor: Colors.green),
                          );
                        }
                      },
                    ),
                    IconButton(
                      tooltip: 'Dismiss',
                      icon: const Icon(Icons.close),
                      color: Colors.red,
                      onPressed: () async {
                        await _recommendationService.dismissRecommendation(rec.id!);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Dismissed "${rec.term}"'), backgroundColor: Colors.orange),
                          );
                        }
                      },
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