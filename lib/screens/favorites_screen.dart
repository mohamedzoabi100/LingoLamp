//lib/screens/favorites_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/phrase_service.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late FlutterTts _tts;
  bool _ttsReady = false;
  final PhraseService _phraseService = PhraseService();
  
  // Track which categories are expanded
  final Map<String, bool> _expandedCategories = {};

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    _tts = FlutterTts();
    
    // Configure TTS settings
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    
    // Check available languages
    List<dynamic> languages = await _tts.getLanguages;
    print("Available TTS languages: $languages");
    
    // Check available voices
    List<dynamic> voices = await _tts.getVoices;
    print("Available TTS voices: $voices");
    
    // Set completion handler
    _tts.setCompletionHandler(() {
      print("TTS completed");
    });
    
    _tts.setErrorHandler((msg) {
      print("TTS Error: $msg");
    });
    
    setState(() => _ttsReady = true);
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _speakSpanish(String text) async {
    if (_ttsReady) {
      print("Attempting to speak Spanish: $text");
      try {
        // Stop any current speech
        await _tts.stop();
        
        // Try different Spanish language codes
        var result = await _tts.setLanguage('es-ES');
        print("Set language es-ES result: $result");
        
        if (result == 1) {
          await _tts.speak(text);
        } else {
          // Try alternative Spanish codes
          result = await _tts.setLanguage('es-MX');
          print("Set language es-MX result: $result");
          
          if (result == 1) {
            await _tts.speak(text);
          } else {
            result = await _tts.setLanguage('es-US');
            print("Set language es-US result: $result");
            
            if (result == 1) {
              await _tts.speak(text);
            } else {
              print("No Spanish language available, using default");
              await _tts.speak(text);
            }
          }
        }
      } catch (e) {
        print("Spanish TTS Error: $e");
        // Fallback to default
        await _tts.speak(text);
      }
    }
  }

  Future<void> _speakEnglish(String text) async {
    if (_ttsReady) {
      print("Attempting to speak English: $text");
      try {
        // Stop any current speech
        await _tts.stop();
        
        var result = await _tts.setLanguage('en-US');
        print("Set language en-US result: $result");
        
        if (result == 1) {
          await _tts.speak(text);
        } else {
          // Try alternative English codes
          result = await _tts.setLanguage('en-GB');
          if (result == 1) {
            await _tts.speak(text);
          } else {
            print("Using default language");
            await _tts.speak(text);
          }
        }
      } catch (e) {
        print("English TTS Error: $e");
        await _tts.speak(text);
      }
    }
  }

  Future<void> _removeFromFavorites(PhraseModel phrase) async {
    await _phraseService.toggleFavorite(phrase.id);
    
    if (mounted) {
      // Refresh the screen to show updated list
      setState(() {});
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Removed from favorites'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.grey[600],
          action: SnackBarAction(
            label: 'Undo',
            textColor: Colors.white,
            onPressed: () async {
              await _phraseService.toggleFavorite(phrase.id);
              setState(() {}); // Refresh after undo
            },
          ),
        ),
      );
    }
  }

  // Group phrases by category and maintain order within categories
  Map<String, List<PhraseModel>> _groupPhrasesByCategory(List<PhraseModel> phrases) {
    final Map<String, List<PhraseModel>> grouped = {};
    
    for (final phrase in phrases) {
      if (!grouped.containsKey(phrase.category)) {
        grouped[phrase.category] = [];
      }
      grouped[phrase.category]!.add(phrase);
    }
    
    // Each category maintains the order from getFavoritePhrases (recently added first)
    return grouped;
  }

  // Get category color based on app's phrasebook theme colors
  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Food & Dining':
        return Colors.orange;
      case 'Transport':
        return Colors.blue;
      case 'Emergencies':
        return Colors.red;
      case 'Greetings':
        return Colors.green;
      case 'Shopping':
        return Colors.purple;
      case 'Accommodation':
        return Colors.brown;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  // Get category icon based on app's phrasebook theme icons
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Food & Dining':
        return Icons.restaurant;
      case 'Transport':
        return Icons.directions_car;
      case 'Emergencies':
        return Icons.local_hospital;
      case 'Greetings':
        return Icons.waving_hand;
      case 'Shopping':
        return Icons.shopping_bag;
      case 'Accommodation':
        return Icons.hotel;
      default:
        return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.star, color: Colors.white),
            const SizedBox(width: 8),
            const Text('Favorite Phrases'),
          ],
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: FutureBuilder<List<PhraseModel>>(
        future: _phraseService.getFavoritePhrases(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {}); // Trigger rebuild
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          
          final phrases = snapshot.data ?? [];
          
          if (phrases.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.star_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No favorite phrases yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the ❤️ icon on phrases to add them here',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          
          // Group phrases by category
          final groupedPhrases = _groupPhrasesByCategory(phrases);
          final categories = groupedPhrases.keys.toList()..sort();
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: categories.length,
            itemBuilder: (context, categoryIndex) {
              final category = categories[categoryIndex];
              final categoryPhrases = groupedPhrases[category]!;
              final categoryColor = _getCategoryColor(category);
              final categoryIcon = _getCategoryIcon(category);
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category header (clickable)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _expandedCategories[category] = !(_expandedCategories[category] ?? true);
                      });
                    },
                    child: Container(
                      margin: EdgeInsets.only(bottom: 12, top: categoryIndex == 0 ? 0 : 24),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: categoryColor.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: categoryColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              categoryIcon,
                              color: categoryColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              category,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: categoryColor,
                              ),
                            ),
                          ),
                          // Expand/collapse arrow
                          AnimatedRotation(
                            duration: const Duration(milliseconds: 200),
                            turns: (_expandedCategories[category] ?? true) ? 0.5 : 0,
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              color: categoryColor,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Phrases in this category (collapsible)
                  if (_expandedCategories[category] ?? true)
                    ...categoryPhrases.map((phrase) => Dismissible(
                    key: Key(phrase.id),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (direction) async {
                      return await showDialog<bool>(
                        context: context,
                        barrierDismissible: false,
                        builder: (BuildContext dialogContext) {
                          return AlertDialog(
                            title: const Text(
                              'Remove from Favorites',
                              style: TextStyle(fontSize: 18),
                            ),
                            content: Text(
                              'Are you sure you want to remove "${phrase.english}" from your favorites?',
                              style: const TextStyle(fontSize: 14),
                            ),
                            contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                            actionsPadding: const EdgeInsets.fromLTRB(8, 0, 16, 16),
                            actions: <Widget>[
                              TextButton(
                                child: const Text('Cancel', style: TextStyle(fontSize: 14)),
                                onPressed: () => Navigator.of(dialogContext).pop(false),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: primaryColor,
                                ),
                                child: const Text('Remove', style: TextStyle(fontSize: 14)),
                                onPressed: () => Navigator.of(dialogContext).pop(true),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    onDismissed: (direction) {
                      _removeFromFavorites(phrase);
                    },
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                            size: 24,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Remove',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: _buildPhraseCard(phrase),
                    ),
                  )).toList(),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPhraseCard(PhraseModel phrase) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // English section
          GestureDetector(
            onTap: () => _speakEnglish(phrase.english),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'EN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      phrase.english,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.volume_up_rounded,
                    size: 20,
                    color: Colors.blue[600],
                  ),
                ],
              ),
            ),
          ),
          
          // Divider
          Container(
            height: 1,
            color: Colors.grey[200],
          ),
          
          // Spanish section
          GestureDetector(
            onTap: () => _speakSpanish(phrase.spanish),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'ES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[700],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      phrase.spanish,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.volume_up_rounded,
                    size: 20,
                    color: Colors.red[600],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}