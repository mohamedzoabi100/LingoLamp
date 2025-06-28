//lib/screens/favorites_screen.dart - ORIGINAL VERSION + CLEAR ALL
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/phrase_model.dart';
import '../services/phrase_service.dart';
import '../services/user_data_service.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late FlutterTts _tts;
  bool _ttsReady = false;
  final PhraseService _phraseService = PhraseService();
  final UserDataService _userDataService = UserDataService();
  
  // Track which categories are expanded - DEFAULT TO COLLAPSED (false)
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
    
    // Check available voices
    List<dynamic> voices = await _tts.getVoices;
    
    // Set completion handler
    _tts.setCompletionHandler(() {
    });
    
    _tts.setErrorHandler((msg) {
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
      try {
        await _tts.stop();
        
        var result = await _tts.setLanguage('es-ES');
        
        if (result == 1) {
          await _tts.speak(text);
        } else {
          result = await _tts.setLanguage('es-MX');
          if (result == 1) {
            await _tts.speak(text);
          } else {
          await _tts.speak(text);
          }
        }
      } catch (e) {
        await _tts.speak(text);
      }
    }
  }

  Future<void> _speakEnglish(String text) async {
    if (_ttsReady) {
      try {
        await _tts.stop();
        
        var result = await _tts.setLanguage('en-US');
        
        if (result == 1) {
          await _tts.speak(text);
        } else {
          result = await _tts.setLanguage('en-GB');
          if (result == 1) {
            await _tts.speak(text);
          } else {
          await _tts.speak(text);
          }
        }
      } catch (e) {
        await _tts.speak(text);
      }
    }
  }

  Future<void> _removeFromFavorites(PhraseModel phrase) async {
    await _userDataService.removeFavorite(phrase.id);
    
    if (mounted) {
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
              await _userDataService.addFavorite(phrase.id);
              setState(() {});
            },
          ),
        ),
      );
    }
  }

  // 🔥 NEW: Clear All Favorites functionality
  Future<void> _clearAllFavorites() async {
    try {
      // Get current favorites first
      final currentFavorites = await _phraseService.getFavoritePhrases();
      
      // Remove each favorite
      for (final phrase in currentFavorites) {
        await _userDataService.removeFavorite(phrase.id);
      }
      
      // Refresh the UI
      if (mounted) {
        setState(() {});
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cleared ${currentFavorites.length} favorites'),
            duration: const Duration(seconds: 3),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing favorites: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 🔥 NEW: Show Clear All confirmation dialog
  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Clear All Favorites?',
          style: TextStyle(fontSize: 18),
        ),
        content: const Text(
          'This will remove all phrases from your favorites. This action cannot be undone.',
          style: TextStyle(fontSize: 14),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        actionsPadding: const EdgeInsets.fromLTRB(8, 0, 16, 16),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel', style: TextStyle(fontSize: 14)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Clear All', style: TextStyle(fontSize: 14)),
            onPressed: () {
              Navigator.of(context).pop();
              _clearAllFavorites();
            },
          ),
        ],
      ),
    );
  }

  Map<String, List<PhraseModel>> _groupPhrasesByCategory(List<PhraseModel> phrases) {
    final Map<String, List<PhraseModel>> grouped = {};
    
    for (final phrase in phrases) {
      final normalizedCategory = _normalizeCategory(phrase.category);
      
      if (!grouped.containsKey(normalizedCategory)) {
        grouped[normalizedCategory] = [];
      }
      grouped[normalizedCategory]!.add(phrase);
    }
    
    return grouped;
  }

  String _normalizeCategory(String category) {
    if (category.isEmpty) return category;
    
    final words = category.toLowerCase().split(' ');
    final normalizedWords = words.map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1);
    }).toList();
    
    return normalizedWords.join(' ');
  }

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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Icon(Icons.star, color: Colors.white),
            const SizedBox(width: 8),
            const Text('Favorite Phrases'),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        // 🔥 NEW: Add Clear All action to AppBar
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'clear_all':
                  _showClearAllDialog();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.clear_all, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Clear All Favorites'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: StreamBuilder<List<PhraseModel>>(
        stream: _phraseService.favoritePhrasesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final phrases = snapshot.data ?? [];

          if (phrases.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.star_outline,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No favorite phrases yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
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
              
              final isExpanded = _expandedCategories[category] ?? false;
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category header (clickable)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _expandedCategories[category] = !isExpanded;
                      });
                    },
                    child: Container(
                      margin: EdgeInsets.only(bottom: 12, top: categoryIndex == 0 ? 0 : 24),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: categoryColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: categoryColor.withAlpha(75),
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: categoryColor.withAlpha(50),
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
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: categoryColor.withAlpha(50),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${categoryPhrases.length}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: categoryColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          AnimatedRotation(
                            duration: const Duration(milliseconds: 200),
                            turns: isExpanded ? 0.5 : 0,
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
                  
                  // Phrases in this category (only show when expanded)
                  if (isExpanded)
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
                                  foregroundColor: Theme.of(context).colorScheme.primary,
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
                        color: Theme.of(context).colorScheme.primary,
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with AI badge only (if AI-generated), no favorite icon
          if (phrase.isAiGenerated)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.purple.withOpacity(0.1),
                    Colors.blue.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
            child: Row(
              children: [
                if (phrase.isAiGenerated) 
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.purple.withOpacity(0.2), Colors.blue.withOpacity(0.2)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 12,
                          color: Colors.purple[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'AI',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
              ],
            ),
          ),
          
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
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  bottomLeft: const Radius.circular(16),
                  bottomRight: const Radius.circular(16),
                  topLeft: phrase.isAiGenerated ? Radius.zero : const Radius.circular(16),
                  topRight: phrase.isAiGenerated ? Radius.zero : const Radius.circular(16),
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