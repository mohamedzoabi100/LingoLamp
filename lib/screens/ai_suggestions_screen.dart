//lib/screens/ai_suggestions_screen.dart - UPDATED WITH SIDE-BY-SIDE LAYOUT
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/ai_phrase_service.dart';
import '../services/phrase_service.dart';

class AiSuggestionsScreen extends StatefulWidget {
  const AiSuggestionsScreen({super.key});

  @override
  State<AiSuggestionsScreen> createState() => _AiSuggestionsScreenState();
}

class _AiSuggestionsScreenState extends State<AiSuggestionsScreen> {
  final TextEditingController _topicController = TextEditingController();
  final AiPhraseService _aiPhraseService = AiPhraseService();
  final PhraseService _phraseService = PhraseService();
  late FlutterTts _tts;
  bool _ttsReady = false;
  bool _isLoading = false;
  bool _isGeneratingMore = false;
  List<PhraseModel> _generatedPhrases = [];
  String _currentTopic = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    _tts = FlutterTts();
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    
    _tts.setCompletionHandler(() {
      debugPrint("TTS completed");
    });
    
    _tts.setErrorHandler((msg) {
      debugPrint("TTS Error: $msg");
    });
    
    setState(() => _ttsReady = true);
  }

  @override
  void dispose() {
    _tts.stop();
    _topicController.dispose();
    super.dispose();
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
      _generatedPhrases = [];
    });

    try {
      final stopwatch = Stopwatch()..start();
      
      final aiPhrases = await _aiPhraseService.generatePhrasesForTopic(topic);
      final phraseModels = _aiPhraseService.aiPhrasesToPhraseModels(aiPhrases);
      
      await _phraseService.addAiPhrases(phraseModels);
      
      final allCategoryPhrases = await _phraseService.getPhrasesForCategory(topic);
      final allAiPhrases = allCategoryPhrases.where((p) => p.isAiGenerated).toList();
      
      stopwatch.stop();
      debugPrint('⏱️ Phrase generation took: ${stopwatch.elapsedMilliseconds}ms');
      debugPrint('📊 Showing ${allAiPhrases.length} total AI phrases for $topic');
      
      setState(() {
        _generatedPhrases = allAiPhrases;
        _currentTopic = topic;
        _isLoading = false;
      });

      FocusScope.of(context).unfocus();

    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
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

  Future<void> _toggleFavorite(PhraseModel phrase) async {
    try {
      final wasInFavorites = phrase.isFavorite;
      
      debugPrint('🔄 Toggling favorite for: ${phrase.english}');
      debugPrint('🔄 Current state: ${wasInFavorites ? "IS favorite" : "NOT favorite"}');
      
      await _phraseService.toggleFavorite(phrase.id);
      
      final index = _generatedPhrases.indexWhere((p) => p.id == phrase.id);
      if (index != -1) {
        setState(() {
          _generatedPhrases[index].isFavorite = !wasInFavorites;
        });
        
        debugPrint('🔄 Updated UI state to: ${_generatedPhrases[index].isFavorite ? "IS favorite" : "NOT favorite"}');
      }
      
      if (mounted) {
        final isNowInFavorites = !wasInFavorites;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isNowInFavorites ? '💚 Added to favorites!' : '💔 Removed from favorites'),
            backgroundColor: isNowInFavorites 
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
            content: Text('Error updating favorites: $e'),
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
              // UNCHANGED: Keep compact header exactly as it is
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
                    
                    // Results header WITHOUT the More button
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
                              Text(
                                '${_generatedPhrases.length} phrases generated',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            
            Expanded(
              child: _buildResultsSection(),
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
            ),
            const SizedBox(height: 8),
            Text(
              'Try topics like "golf", "business", "travel"...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    // NEW: Use side-by-side layout from the second image
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

  // NEW: Side-by-side layout matching the second image
  Widget _buildSideBySidePhraseCard(PhraseModel phrase, int index) {
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
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
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
                        phrase.isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: phrase.isFavorite 
                          ? Theme.of(context).colorScheme.primary 
                          : Colors.grey[400],
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // NEW: Side-by-side English and Spanish layout
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
                
                // Spanish phrase
                GestureDetector(
                  onTap: () => _speakSpanish(phrase.spanish),
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
                            'ES',
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
                            phrase.spanish,
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