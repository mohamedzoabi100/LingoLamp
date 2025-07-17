import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../models/recommended_flashcard_model.dart';
import '../utils/database_helper.dart';
import '../models/flashcard_model.dart';
import '../services/phrase_service.dart';
import '../models/phrase_model.dart';
import '../services/ai_phrase_service.dart';
import '../services/ai_chat_service.dart';
import '../services/xp_service.dart';
import '../core/providers/language_provider.dart';
import '../core/providers/flashcard_provider.dart';
import '../core/providers/recommendation_provider.dart';

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  final XPService _xpService = XPService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final languageProvider = context.read<LanguageProvider>();
      await context.read<FlashcardProvider>().init(languageCode: languageProvider.currentLanguage, context: context);
      await context.read<RecommendationProvider>().init(languageCode: languageProvider.currentLanguage, context: context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Consumer<RecommendationProvider>(
          builder: (context, recommendationProvider, child) {
            // Check if provider is loading
            if (recommendationProvider.isLoading) {
              return Scaffold(
                appBar: AppBar(
                  title: const Text('Recommendations'),
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.blue,
                ),
                body: const Center(child: CircularProgressIndicator()),
              );
            }
            
            final recs = recommendationProvider.recommendations;
            if (recs.isEmpty) {
              return Scaffold(
                appBar: AppBar(
                  title: const Text('Recommendations'),
                  foregroundColor: Colors.white,
                  backgroundColor: Theme.of(context).primaryColor,
                ),
                body: const Center(child: Text('No recommendations yet.')),
              );
            }
            
            return Scaffold(
              appBar: AppBar(
                title: const Text('Recommendations'),
                foregroundColor: Colors.white,
                backgroundColor: Theme.of(context).primaryColor,
              ),
              body: ListView.separated(
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
                            final flashcardProvider = Provider.of<FlashcardProvider>(context, listen: false);
                            final languageProvider = context.read<LanguageProvider>();
                            
                            // Check if flashcard already exists
                            final existingFlashcards = flashcardProvider.flashcards;
                            final alreadyExists = existingFlashcards.any((f) => f.originalText == rec.term);
                            
                            if (alreadyExists) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Flashcard "${rec.term}" already exists!'), backgroundColor: Colors.orange),
                                );
                              }
                              // Still remove from recommendations since it already exists
                              await recommendationProvider.removeRecommendation(rec.id!);
                              return;
                            }
                            
                            final now = DateTime.now();
                            final flashcard = Flashcard(
                              originalText: rec.term,
                              translatedText: rec.context,
                              sourceLanguage: 'en',
                              targetLanguage: languageProvider.currentLanguage,
                              languageCode: languageProvider.currentLanguage,
                              createdAt: now,
                              lastStudied: now,
                              category: 'Recommended',
                              tags: ['recommended'],
                            );
                            await flashcardProvider.addFlashcard(flashcard);
                            await recommendationProvider.removeRecommendation(rec.id!);
                            await _xpService.awardFlashcardCreated();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Added "${rec.term}" to flashcards! 📚 +10 XP'), backgroundColor: Colors.green),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
} 