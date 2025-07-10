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

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final RecommendationService _recommendationService = RecommendationService();
  late Stream<List<RecommendedFlashcard>> _stream;
  StreamSubscription<List<RecommendedFlashcard>>? _streamSubscription;

  @override
  void initState() {
    super.initState();
    _stream = _db.recommendedStream;
    print('[RECOMMENDATIONS] Screen initialized');
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _addFlashcard(RecommendedFlashcard rec) async {
    try {
      print('[RECOMMENDATIONS] Adding flashcard for term: "${rec.term}"');
      
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Finding translation...'),
            ],
          ),
        ),
      );
      
      // Check if flashcard already exists
      if (await _db.flashcardExistsByOriginalText(rec.term)) {
        if (mounted) {
          // Close loading dialog
          Navigator.of(context).pop();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Flashcard for "${rec.term}" already exists!'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

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
      print('[RECOMMENDATIONS] PhraseService translation: $translated');

      // If not found, try simple AI translation with shorter timeout
      if (translated == null || translated.trim().isEmpty || translated.trim().toLowerCase() == rec.term.trim().toLowerCase()) {
        print('[RECOMMENDATIONS] Trying simple AI translation...');
        try {
          // Use a simpler, faster approach
          final simplePrompt = 'Translate "${rec.term}" to Spanish. Respond with only the Spanish translation.';
          final response = await _getSimpleTranslation(simplePrompt);
          if (response != null && response.isNotEmpty) {
            translated = _cleanTranslation(response);
            print('[RECOMMENDATIONS] Simple AI translation found: $translated');
          }
        } catch (e) {
          print('[RECOMMENDATIONS] Simple AI translation failed: $e');
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
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Please provide the Spanish translation for "${rec.term}"'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'Spanish translation',
                      hintText: 'Enter the Spanish translation...',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                    onSubmitted: (value) => Navigator.pop(context, value.trim()),
                  ),
                ],
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
            // Close loading dialog
            Navigator.of(context).pop();
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Flashcard not added: Spanish translation required.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      // Create the flashcard with all required fields
      final card = Flashcard(
        originalText: rec.term,
        translatedText: translated,
        sourceLanguage: 'en-US',
        targetLanguage: 'es-ES',
        createdAt: DateTime.now(),
        lastStudied: DateTime.now(),
        timesStudied: 0,
        difficulty: 2,
        isFavorite: false,
        category: 'Recommended',
        tags: ['recommended'],
      );

      print('[RECOMMENDATIONS] Created flashcard: ${card.originalText} -> ${card.translatedText}');

      // Insert the flashcard
      await _db.insertFlashcard(card);
      print('[RECOMMENDATIONS] Flashcard inserted successfully');
      
      // Remove from recommendations
      await _db.deleteRecommended(rec.id!);
      
      if (mounted) {
        // Close loading dialog
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "${rec.term}" to flashcards! 📚'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error adding flashcard: $e');
      if (mounted) {
        // Close loading dialog
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding flashcard: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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

  // Simple translation method with short timeout
  Future<String?> _getSimpleTranslation(String prompt) async {
    try {
      // Import the AI chat service
      final aiChatService = AiChatService();
      
      // Send the simple prompt with a short timeout
      final response = await aiChatService.sendMessage(prompt).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('[RECOMMENDATIONS] Simple translation timed out');
          return 'Translation timeout';
        },
      );
      
      if (response != null && response.isNotEmpty && response != 'Translation timeout') {
        // Clean up the response - remove any extra text
        final cleanResponse = response.trim();
        // Remove common prefixes/suffixes that AI might add
        final translation = cleanResponse
            .replaceAll(RegExp(r'^(Spanish|Español|Translation):\s*', caseSensitive: false), '')
            .replaceAll(RegExp(r'[.!?]+$'), '')
            .trim();
        
        return translation.isNotEmpty ? translation : null;
      }
      
      return null;
    } catch (e) {
      print('[RECOMMENDATIONS] Error in simple translation: $e');
      return null;
    }
  }

  String _cleanTranslation(String response) {
    // Remove markdown, object strings, and extra whitespace
    String cleaned = response
        .replaceAll(RegExp(r'\*\*'), '') // remove bold markdown
        .replaceAll(RegExp(r'_'), '') // remove italics markdown
        .replaceAll(RegExp(r'`'), '') // remove code markdown
        .replaceAll(RegExp(r"Instance of 'RecommendedFlashcard'\.term"), '') // remove object string
        .replaceAll(RegExp(r'\s+'), ' ') // collapse whitespace
        .trim();
    // Remove any leading/trailing non-word characters
    cleaned = cleaned.replaceAll(RegExp(r'^[^\wáéíóúüñÁÉÍÓÚÜÑ]+|[^\wáéíóúüñÁÉÍÓÚÜÑ]+ 0$'), '');
    return cleaned;
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
          print('[RECOMMENDATIONS] StreamBuilder: ${snapshot.connectionState}, hasData: ${snapshot.hasData}, error: ${snapshot.error}');
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final recs = snapshot.data!;
          print('[RECOMMENDATIONS] Found ${recs.length} recommendations');
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