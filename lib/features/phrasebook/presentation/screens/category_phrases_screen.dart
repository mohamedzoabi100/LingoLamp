import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/phrasebook_provider.dart';
import '../../../../models/phrase_model.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../services/cloud_tts_service.dart';

class CategoryPhrasesScreen extends StatefulWidget {
  final String categoryTitle;
  final Color categoryColor;
  final IconData categoryIcon;

  const CategoryPhrasesScreen({
    super.key,
    required this.categoryTitle,
    required this.categoryColor,
    required this.categoryIcon,
  });

  @override
  State<CategoryPhrasesScreen> createState() => _CategoryPhrasesScreenState();
}

class _CategoryPhrasesScreenState extends State<CategoryPhrasesScreen> with WidgetsBindingObserver {
  final CloudTtsService _cloudTts = CloudTtsService()..register();
  String? _currentlySpeakingText;

  @override
  void initState() {
    super.initState();
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
        setState(() {
          _currentlySpeakingText = null;
        });
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
      setState(() {
        _currentlySpeakingText = text;
      });
      
      await _cloudTts.speak(
        text: text,
        languageCode: 'en-US',
        voiceName: 'en-US-Standard-A',
        speakingRate: 0.9,
      );
      
      if (mounted) {
        setState(() {
          _currentlySpeakingText = null;
        });
      }
    } catch (e) {
      print('[CategoryPhrases] ERROR: Failed to speak English: $e');
      if (mounted) {
        setState(() {
          _currentlySpeakingText = null;
        });
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
      setState(() {
        _currentlySpeakingText = text;
      });
      
      // Map language codes to Google Cloud TTS codes
      final ttsLanguageCode = _getTtsLanguageCode(languageCode);
      final voiceName = _getVoiceName(languageCode);
      
      await _cloudTts.speak(
        text: text,
        languageCode: ttsLanguageCode,
        voiceName: voiceName,
        speakingRate: 0.9,
      );
      
      if (mounted) {
        setState(() {
          _currentlySpeakingText = null;
        });
      }
    } catch (e) {
      print('[CategoryPhrases] ERROR: Failed to speak translation: $e');
      if (mounted) {
        setState(() {
          _currentlySpeakingText = null;
        });
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
            Icon(widget.categoryIcon, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.categoryTitle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Consumer<PhrasebookProvider>(
        builder: (context, provider, child) {
          final phrases = provider.getPhrasesByCategory(widget.categoryTitle);
          
          if (phrases.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No phrases found for ${widget.categoryTitle}',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/ai-suggestions');
                    },
                    child: const Text('Generate AI Phrases'),
                  ),
                ],
              ),
            );
          }
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: phrases.length,
            itemBuilder: (context, index) {
              return _buildPhraseCard(phrases[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildPhraseCard(PhraseModel phrase) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.06),
      child: Column(
        children: [
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
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () => _toggleFavorite(phrase),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      phrase.isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: phrase.isFavorite ? Theme.of(context).colorScheme.primary : Colors.grey[600],
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
              padding: const EdgeInsets.all(20),
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
                    _currentlySpeakingText == phrase.english ? Icons.stop : Icons.volume_up_rounded,
                    size: 24,
                    color: _currentlySpeakingText == phrase.english ? Colors.red : Colors.blue[600],
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
                    _currentlySpeakingText == phrase.translation ? Icons.stop : Icons.volume_up_rounded,
                    size: 24,
                    color: _currentlySpeakingText == phrase.translation ? Colors.red : Colors.red[600],
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