import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/phrasebook_provider.dart';
import '../../../../models/phrase_model.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../services/cloud_tts_service.dart';
import '../../../../services/ai_phrase_service.dart';
import '../../../../services/xp_service.dart';
import '../../../../core/providers/auth_provider.dart';

class AiSuggestionsScreen extends StatefulWidget {
  const AiSuggestionsScreen({Key? key}) : super(key: key);

  @override
  _AiSuggestionsScreenState createState() => _AiSuggestionsScreenState();
}

class _AiSuggestionsScreenState extends State<AiSuggestionsScreen> with WidgetsBindingObserver {
  final CloudTtsService _cloudTts = CloudTtsService()..register();
  final AiPhraseService _aiPhraseService = AiPhraseService();
  final XPService _xpService = XPService();
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _contextController = TextEditingController();
  String _selectedDifficulty = 'beginner';
  List<PhraseModel> _generatedPhrases = [];
  bool _isGenerating = false;
  bool _isLoading = false;
  bool _isGeneratingMore = false;
  String _currentTopic = '';
  String? _errorMessage;
  Set<String> _favoriteIds = {};
  LanguageProvider? _languageProvider; // Store reference

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only add listener once
    _languageProvider ??= Provider.of<LanguageProvider>(context, listen: false);
    _languageProvider!.addListener(_onLanguageChanged);
  }

  @override
  void dispose() {
    _topicController.dispose();
    _contextController.dispose();
    // Remove language listener
    _languageProvider?.removeListener(_onLanguageChanged); // Use stored reference
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
      print('[AiSuggestions] ERROR: Failed to speak English: $e');
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
      print('[AiSuggestions] ERROR: Failed to speak translation: $e');
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

  Future<void> _generatePhrases() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a topic first';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentTopic = topic;
      _generatedPhrases = [];
    });

    try {
      // Get current language from provider
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      final currentLanguage = languageProvider.currentLanguage;
      
      final aiPhrases = await _aiPhraseService.generatePhrasesForTopic(topic, languageCode: currentLanguage);
      final phraseModels = _aiPhraseService.aiPhrasesToPhraseModels(
        aiPhrases: aiPhrases,
        category: topic,
        languageCode: currentLanguage,
      );
      
      for (final model in phraseModels) {
        await context.read<PhrasebookProvider>().addAiPhrase(model);
      }
      
      // Award XP for learning phrases
      await _xpService.awardPhraseLearned();
      
      setState(() {
        _isLoading = false;
        _errorMessage = null;
        _currentTopic = topic;
      });

      FocusScope.of(context).unfocus();

    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _generateMorePhrases() async {
    if (_isGeneratingMore) return;
    
    try {
      setState(() {
        _isGeneratingMore = true;
        _errorMessage = null;
      });
      
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      final newPhrases = await _aiPhraseService.generateMultiplePhrases(
        count: 3,
        topic: _currentTopic,
        difficulty: _selectedDifficulty,
        languageCode: languageProvider.currentLanguage,
      );
      
      // Save new phrases to the provider so they persist
      print('🔄 [AI Suggestions] Saving ${newPhrases.length} new phrases to provider');
      for (final phrase in newPhrases) {
        print('🔄 [AI Suggestions] Saving phrase: ${phrase.english} (ID: ${phrase.id})');
        await context.read<PhrasebookProvider>().addAiPhrase(phrase);
      }
      
      // Small delay to ensure provider updates are processed
      await Future.delayed(const Duration(milliseconds: 100));
      
      setState(() {
        _isGeneratingMore = false;
      });
      
      // Award XP for learning more phrases
      await _xpService.awardPhraseLearned();
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✨ Generated ${newPhrases.length} more phrases!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }

    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isGeneratingMore = false;
      });
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate more phrases: ${_errorMessage}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _toggleFavorite(PhraseModel phrase) async {
    try {
      await context.read<PhrasebookProvider>().toggleFavorite(phrase.id, phrase.languageCode);
      
      if (mounted) {
        final isNowFavorite = !_favoriteIds.contains(phrase.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isNowFavorite ? '💚 Added to favorites!' : '💔 Removed from favorites'),
            backgroundColor: isNowFavorite 
              ? Theme.of(context).colorScheme.primary 
              : Colors.grey[600],
            duration: const Duration(seconds: 2),
          ),
        );
      }
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

  void _quickSelectTopic(String topic) {
    _topicController.text = topic;
    _generatePhrases();
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
            const Icon(Icons.auto_awesome, color: Colors.white),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('AI Smart Suggestions'),
            ),
          ],
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // UNCHANGED: Keep search bar exactly as it is
            if (_generatedPhrases.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      spreadRadius: 0,
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.psychology,
                            color: primaryColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'What do you need phrases for?',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: TextField(
                        controller: _topicController,
                        decoration: InputDecoration(
                          hintText: 'e.g., golf, business meeting, airport...',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          prefixIcon: Icon(Icons.search, color: primaryColor),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        ),
                        onSubmitted: (_) => _generatePhrases(),
                        textInputAction: TextInputAction.search,
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _generatePhrases,
                        icon: _isLoading 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.auto_awesome),
                        label: Text(_isLoading ? 'Generating...' : 'Generate Phrases'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    Text(
                      'Popular topics:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _aiPhraseService.getPopularTopics().length,
                        itemBuilder: (context, index) {
                          final topic = _aiPhraseService.getPopularTopics()[index];
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => _quickSelectTopic(topic),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: primaryColor.withOpacity(0.3)),
                                ),
                                child: Text(
                                  topic,
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // UPDATED: Header with "Generate More" button
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Topic input (smaller)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: TextField(
                        controller: _topicController,
                        decoration: InputDecoration(
                          hintText: 'Search new topic...',
                          hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                          prefixIcon: Icon(Icons.search, color: primaryColor, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(Icons.send, color: primaryColor, size: 20),
                            onPressed: _isLoading ? null : _generatePhrases,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onSubmitted: (_) => _generatePhrases(),
                        textInputAction: TextInputAction.search,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Results header WITH the "Generate More" button
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.auto_awesome, color: primaryColor, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AI Phrases for "$_currentTopic"',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Consumer<PhrasebookProvider>(
                                builder: (context, provider, child) {
                                  final currentPhrases = provider.getAiGeneratedPhrases()
                                      .where((p) => p.category.toLowerCase() == _currentTopic.toLowerCase())
                                      .toList();
                                  return Text(
                                    '${currentPhrases.length} phrases generated',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        // "Generate More" button
                        if (_generatedPhrases.isNotEmpty && !_isGeneratingMore)
                          GestureDetector(
                            onTap: _generateMorePhrases,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: primaryColor.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.add,
                                    size: 14,
                                    color: primaryColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'More',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        // Loading indicator for "generating more"
                        if (_isGeneratingMore)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            
            Expanded(
              child: Consumer<PhrasebookProvider>(
                builder: (context, provider, child) {
                  final allAiPhrases = provider.getAiGeneratedPhrases();
                  _generatedPhrases = allAiPhrases
                      .where((p) => p.category.toLowerCase() == _currentTopic.toLowerCase())
                      .toList();
                  print('🔄 [AI Suggestions] Consumer update - Total AI phrases: ${allAiPhrases.length}, Filtered for "$_currentTopic": ${_generatedPhrases.length}');
                  return _buildResultsSection();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsSection() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'AI is generating phrases for you...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This may take a few seconds',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _errorMessage = null;
                  });
                },
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_generatedPhrases.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.psychology_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Enter a topic to get AI-generated phrases!',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Try topics like "golf", "business", "travel"...',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Side-by-side layout with phrases
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: _generatedPhrases.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildSideBySidePhraseCard(_generatedPhrases[index], index),
        );
      },
    );
  }

  // Side-by-side layout matching the design
  Widget _buildSideBySidePhraseCard(PhraseModel phrase, int index) {
    final isGuest = context.read<AuthProvider>().isGuest;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          // Header with AI badge and favorite button
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
            child: Row(
              children: [
                // Phrase number
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // AI badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 10,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'AI',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Only show favorite icon if not guest
                if (!isGuest) ...[
                  IconButton(
                    icon: Icon(
                      phrase.isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: phrase.isFavorite ? Colors.red : Colors.grey[400],
                      size: 20,
                    ),
                    onPressed: () => _toggleFavorite(phrase),
                    tooltip: phrase.isFavorite ? 'Remove from favorites' : 'Save as favorite',
                  ),
                ],
              ],
            ),
          ),
          
          // Side-by-side English and Spanish layout
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                // English phrase
                GestureDetector(
                  onTap: () => _speakEnglish(phrase.english),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey[200]!,
                        width: 1,
                      ),
                    ),
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
                              height: 1.3,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.volume_up_rounded,
                          size: 18,
                          color: Colors.blue[600],
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Translation phrase
                GestureDetector(
                  onTap: () => _speakTranslation(phrase.translation, phrase.languageCode),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey[200]!,
                        width: 1,
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
                              height: 1.3,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.volume_up_rounded,
                          size: 18,
                          color: Colors.red[600],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 