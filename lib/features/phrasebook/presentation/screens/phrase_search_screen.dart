import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/phrasebook_provider.dart';
import '../../../../models/phrase_model.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../services/cloud_tts_service.dart';
import '../../../../core/providers/auth_provider.dart';

class PhraseSearchScreen extends StatefulWidget {
  const PhraseSearchScreen({Key? key}) : super(key: key);

  @override
  _PhraseSearchScreenState createState() => _PhraseSearchScreenState();
}

class _PhraseSearchScreenState extends State<PhraseSearchScreen> with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  List<PhraseModel> _filteredPhrases = [];
  final CloudTtsService _cloudTts = CloudTtsService()..register();
  String _searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchController.addListener(_filterPhrases);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final languageProvider = context.read<LanguageProvider>();
      await context.read<PhrasebookProvider>().init(languageCode: languageProvider.currentLanguage, context: context);
    });
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
    _searchController.dispose();
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

  void _filterPhrases() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _searchQuery = query;
    });
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
      print('[PhraseSearch] ERROR: Failed to speak English: $e');
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
      print('[PhraseSearch] ERROR: Failed to speak translation: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Search Phrases'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search English or Spanish...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ),
          Expanded(
            child: Consumer<PhrasebookProvider>(
              builder: (context, provider, child) {
                _filteredPhrases = provider.searchPhrases(_searchQuery);
                
                if (_filteredPhrases.isEmpty && _searchQuery.isNotEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No phrases found for "$_searchQuery"',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(context, '/ai-suggestions');
                          },
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('Generate AI Phrases'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                if (_filteredPhrases.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Type to search phrases',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Search in English or your target language',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filteredPhrases.length,
                  itemBuilder: (context, index) {
                    return _buildPhraseCard(_filteredPhrases[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhraseCard(PhraseModel phrase) {
    final isGuest = context.read<AuthProvider>().isGuest;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: Column(
        children: [
          // Header with category and favorite
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    phrase.category,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const Spacer(),
                // Only show favorite icon if not guest
                if (!isGuest) ...[
                  GestureDetector(
                    onTap: () => _toggleFavorite(phrase),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        phrase.isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: phrase.isFavorite ? Theme.of(context).colorScheme.primary : Colors.grey[600],
                        size: 18,
                      ),
                    ),
                  ),
                ],
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
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'EN',
                      style: TextStyle(
                        fontSize: 10,
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
          
          // Translation section
          GestureDetector(
            onTap: () => _speakTranslation(phrase.translation, phrase.languageCode),
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
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      phrase.languageCode.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
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