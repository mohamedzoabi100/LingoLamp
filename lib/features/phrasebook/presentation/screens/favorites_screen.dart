import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/phrasebook_provider.dart';
import '../../../../models/phrase_model.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../services/cloud_tts_service.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({Key? key}) : super(key: key);

  @override
  _FavoritesScreenState createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> with WidgetsBindingObserver {
  final CloudTtsService _cloudTts = CloudTtsService()..register();
  
  // Track which categories are expanded - DEFAULT TO COLLAPSED (false)
  final Map<String, bool> _expandedCategories = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final languageProvider = context.read<LanguageProvider>();
      await context.read<PhrasebookProvider>().init(languageCode: languageProvider.currentLanguage, context: context);
    });
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen to language changes
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    languageProvider.addListener(_onLanguageChanged);
  }

  @override
  void dispose() {
    // Remove language listener
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    languageProvider.removeListener(_onLanguageChanged);
    // Stop TTS when leaving the screen
    _cloudTts.stop();
    _cloudTts.unregister();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
        // Stop TTS when app is paused, minimized, or closed
        _cloudTts.stop();
        break;
      case AppLifecycleState.resumed:
        // App resumed - no action needed
        break;
    }
  }

  void _onLanguageChanged() {
    // Reinitialize phrase service with new language
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    context.read<PhrasebookProvider>().onLanguageChanged(languageProvider.currentLanguage);
  }

  Future<void> _speakEnglish(String text) async {
    try {
      await _cloudTts.speak(
        text: text,
        languageCode: 'en-US',
        voiceName: 'en-US-Standard-A',
        speakingRate: 0.9,
      );
    } catch (e) {
      print('[Favorites] ERROR: Failed to speak English: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to play audio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _speakTranslation(String text, String languageCode) async {
    try {
      // Map language codes to Google Cloud TTS codes
      final ttsLanguageCode = _getTtsLanguageCode(languageCode);
      final voiceName = _getVoiceName(languageCode);
      
      await _cloudTts.speak(
        text: text,
        languageCode: ttsLanguageCode,
        voiceName: voiceName,
        speakingRate: 0.9,
      );
    } catch (e) {
      print('[Favorites] ERROR: Failed to speak translation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to play audio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getTtsLanguageCode(String languageCode) {
    final languageMap = {
      'es': 'es-ES',
      'fr': 'fr-FR',
      'de': 'de-DE',
      'it': 'it-IT',
      'pt': 'pt-BR',
    };
    return languageMap[languageCode] ?? 'es-ES';
  }

  String _getVoiceName(String languageCode) {
    final voiceMap = {
      'es': 'es-ES-Standard-A',
      'fr': 'fr-FR-Standard-A',
      'de': 'de-DE-Standard-A',
      'it': 'it-IT-Standard-A',
      'pt': 'pt-BR-Standard-A',
    };
    return voiceMap[languageCode] ?? 'es-ES-Standard-A';
  }

  Future<void> _toggleFavorite(PhraseModel phrase) async {
    try {
      await context.read<PhrasebookProvider>().toggleFavorite(phrase.id, phrase.languageCode);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating favorite: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Group phrases by category
  Map<String, List<PhraseModel>> _groupPhrasesByCategory(List<PhraseModel> phrases) {
    final Map<String, List<PhraseModel>> grouped = {};
    
    for (final phrase in phrases) {
      final category = phrase.category;
      
      if (!grouped.containsKey(category)) {
        grouped[category] = [];
      }
      grouped[category]!.add(phrase);
    }
    
    return grouped;
  }

  // Get category color based on category name
  Color _getCategoryColor(String category) {
    final Map<String, Color> categoryColors = {
      'Airport': Colors.teal,
      'Food & Dining': Colors.orange,
      'Travel': Colors.blue,
      'Business': Colors.purple,
      'Medical': Colors.red,
      'Shopping': Colors.green,
      'Hotel': Colors.indigo,
      'Transportation': Colors.brown,
      'Emergency': Colors.red.shade700,
      'Entertainment': Colors.pink,
      'Basic': Colors.grey,
    };
    
    // Try exact match first
    if (categoryColors.containsKey(category)) {
      return categoryColors[category]!;
    }
    
    // Fallback: check if category contains keywords
    final lowerCategory = category.toLowerCase();
    if (lowerCategory.contains('food') || lowerCategory.contains('dining') || lowerCategory.contains('restaurant')) {
      return Colors.orange;
    } else if (lowerCategory.contains('airport') || lowerCategory.contains('flight')) {
      return Colors.teal;
    } else if (lowerCategory.contains('travel')) {
      return Colors.blue;
    } else if (lowerCategory.contains('business')) {
      return Colors.purple;
    } else if (lowerCategory.contains('medical') || lowerCategory.contains('health')) {
      return Colors.red;
    } else if (lowerCategory.contains('shopping') || lowerCategory.contains('store')) {
      return Colors.green;
    } else if (lowerCategory.contains('hotel') || lowerCategory.contains('accommodation')) {
      return Colors.indigo;
    } else if (lowerCategory.contains('transport') || lowerCategory.contains('taxi') || lowerCategory.contains('bus')) {
      return Colors.brown;
    } else if (lowerCategory.contains('emergency')) {
      return Colors.red.shade700;
    } else if (lowerCategory.contains('entertainment') || lowerCategory.contains('fun')) {
      return Colors.pink;
    }
    
    // Default fallback
    return Theme.of(context).colorScheme.primary;
  }

  // Get category icon based on category name
  IconData _getCategoryIcon(String category) {
    final Map<String, IconData> categoryIcons = {
      'Airport': Icons.flight,
      'Food & Dining': Icons.restaurant,
      'Travel': Icons.luggage,
      'Business': Icons.business,
      'Medical': Icons.medical_services,
      'Shopping': Icons.shopping_bag,
      'Hotel': Icons.hotel,
      'Transportation': Icons.directions_car,
      'Emergency': Icons.emergency,
      'Entertainment': Icons.movie,
      'Basic': Icons.chat,
    };
    
    // Try exact match first
    if (categoryIcons.containsKey(category)) {
      return categoryIcons[category]!;
    }
    
    // Fallback: check if category contains keywords
    final lowerCategory = category.toLowerCase();
    if (lowerCategory.contains('food') || lowerCategory.contains('dining') || lowerCategory.contains('restaurant')) {
      return Icons.restaurant;
    } else if (lowerCategory.contains('airport') || lowerCategory.contains('flight')) {
      return Icons.flight;
    } else if (lowerCategory.contains('travel')) {
      return Icons.luggage;
    } else if (lowerCategory.contains('business')) {
      return Icons.business;
    } else if (lowerCategory.contains('medical') || lowerCategory.contains('health')) {
      return Icons.medical_services;
    } else if (lowerCategory.contains('shopping') || lowerCategory.contains('store')) {
      return Icons.shopping_bag;
    } else if (lowerCategory.contains('hotel') || lowerCategory.contains('accommodation')) {
      return Icons.hotel;
    } else if (lowerCategory.contains('transport') || lowerCategory.contains('taxi') || lowerCategory.contains('bus')) {
      return Icons.directions_car;
    } else if (lowerCategory.contains('emergency')) {
      return Icons.emergency;
    } else if (lowerCategory.contains('entertainment') || lowerCategory.contains('fun')) {
      return Icons.movie;
    }
    
    // Default fallback
    return Icons.category;
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            const Icon(Icons.favorite, color: Colors.white),
            const SizedBox(width: 8),
            const Text('Favorite Phrases'),
          ],
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Consumer<PhrasebookProvider>(
        builder: (context, provider, child) {
          final favorites = provider.favorites;
          
          if (favorites.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border,
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
                    'Tap the heart icon on any phrase to add it to favorites',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.explore),
                    label: const Text('Explore Phrases'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }
          
          // Group favorites by category
          final groupedPhrases = _groupPhrasesByCategory(favorites);
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
                children: [
                  // Category header (clickable)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _expandedCategories[category] = !isExpanded;
                      });
                    },
                    child: Container(
                      margin: EdgeInsets.only(bottom: isExpanded ? 8 : 16, top: categoryIndex == 0 ? 0 : 16),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
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
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: categoryColor.withOpacity(0.2),
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
                            turns: isExpanded ? 0.25 : 0,
                            child: Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: categoryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Expandable phrases list
                  if (isExpanded)
                    ...categoryPhrases.asMap().entries.map((entry) {
                      final phraseIndex = entry.key;
                      final phrase = entry.value;
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: phraseIndex == categoryPhrases.length - 1 ? 16 : 8,
                        ),
                        child: _buildPhraseCard(phrase, categoryColor),
                      );
                    }).toList(),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPhraseCard(PhraseModel phrase, [Color? categoryColor]) {
    // Check if phrase is AI-generated
    final isAiGenerated = phrase.category.contains('AI') || phrase.id.contains('ai_') || 
                         (phrase.category != 'Basic' && phrase.category != 'Travel' && 
                          phrase.category != 'Food & Dining' && phrase.category != 'Business' && 
                          phrase.category != 'Medical' && phrase.category != 'Shopping' && 
                          phrase.category != 'Hotel' && phrase.category != 'Airport' && 
                          phrase.category != 'Transportation' && phrase.category != 'Emergency' && 
                          phrase.category != 'Entertainment');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.06),
      child: Column(
        children: [
          // Header with AI badge and favorite button (if AI generated)
          if (isAiGenerated)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
              child: Row(
                children: [
                  // AI badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (categoryColor ?? Theme.of(context).colorScheme.primary).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 10,
                          color: categoryColor ?? Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          'AI',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: categoryColor ?? Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Favorite button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _toggleFavorite(phrase),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.favorite,
                          color: categoryColor ?? Theme.of(context).colorScheme.primary,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (categoryColor ?? Theme.of(context).colorScheme.primary).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    phrase.category,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: categoryColor ?? Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _toggleFavorite(phrase),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.favorite,
                      color: categoryColor ?? Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // English section
          GestureDetector(
            onTap: () => _speakEnglish(phrase.english),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(20, isAiGenerated ? 0 : 20, 20, 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'EN',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      phrase.english,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.volume_up_rounded,
                    size: 24,
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
          
          // Translation section
          GestureDetector(
            onTap: () => _speakTranslation(phrase.translation, phrase.languageCode),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      phrase.languageCode.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[700],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      phrase.translation,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.volume_up_rounded,
                    size: 24,
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