//lib/screens/ai_suggestions_screen.dart
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
  bool _isGeneratingMore = false; // NEW: Separate loading state for generate more
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
      // Add performance timing
      final stopwatch = Stopwatch()..start();
      
      final aiPhrases = await _aiPhraseService.generatePhrasesForTopic(topic);
      final phraseModels = _aiPhraseService.aiPhrasesToPhraseModels(aiPhrases);
      
      // FIXED: Add new AI phrases to the main phrase service
      await _phraseService.addAiPhrases(phraseModels);
      
      stopwatch.stop();
      debugPrint('⏱️ Phrase generation took: ${stopwatch.elapsedMilliseconds}ms');
      
      setState(() {
        _generatedPhrases = phraseModels;
        _currentTopic = topic;
        _isLoading = false;
      });

      // Hide keyboard
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
      // Toggle the favorite status
      await _phraseService.toggleFavorite(phrase.id);
      
      // Update the phrase in the current list
      final index = _generatedPhrases.indexWhere((p) => p.id == phrase.id);
      if (index != -1) {
        setState(() {
          _generatedPhrases[index].isFavorite = !_generatedPhrases[index].isFavorite;
        });
      }
      
      if (mounted) {
        final isNowFavorite = _generatedPhrases[index].isFavorite;
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
            content: Text('Error updating favorites: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // FIXED: Generate More button functionality
  Future<void> _generateMorePhrases() async {
    if (_currentTopic.isEmpty) return;
    
    setState(() {
      _isGeneratingMore = true;
      _errorMessage = null;
    });

    try {
      // CRITICAL FIX: Clear all caches
      _aiPhraseService.clearCacheForTopic(_currentTopic);
      _aiPhraseService.clearAllCache();
      await _phraseService.clearAiPhrasesForCategory(_currentTopic);
      
      // WORKAROUND: Add timestamp to bypass Firebase cache
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final modifiedTopic = '${_currentTopic}_$timestamp';
      
      debugPrint('🔄 Generating new phrases with modified topic: $modifiedTopic');
      
      // Generate with modified topic to bypass cache
      final aiPhrases = await _aiPhraseService.generatePhrasesForTopic(modifiedTopic);
      var phraseModels = _aiPhraseService.aiPhrasesToPhraseModels(aiPhrases);
      
      // Fix the category back to original topic for all phrases
      phraseModels = phraseModels.map((phrase) {
        return phrase.copyWith(
          // Update the category to be the original topic
          // Note: We need to create a new PhraseModel with correct category
        );
      }).toList();
      
      // Manually fix each phrase's category
      final fixedPhrases = <PhraseModel>[];
      for (final phrase in phraseModels) {
        final fixedPhrase = PhraseModel(
          id: 'ai_${phrase.english.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}_${DateTime.now().millisecondsSinceEpoch}',
          english: phrase.english,
          spanish: phrase.spanish,
          category: _currentTopic, // Use original topic as category
          difficulty: phrase.difficulty,
          createdAt: phrase.createdAt,
          isFavorite: phrase.isFavorite,
          isAiGenerated: true,
        );
        fixedPhrases.add(fixedPhrase);
      }
      
      // Add new AI phrases to the main phrase service
      await _phraseService.addAiPhrases(fixedPhrases);
      
      setState(() {
        _generatedPhrases = fixedPhrases;
        _isGeneratingMore = false;
      });

      debugPrint('✅ Generated ${fixedPhrases.length} NEW phrases for $_currentTopic');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Generated ${fixedPhrases.length} fresh phrases for $_currentTopic! 🚀'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );

    } catch (e) {
      debugPrint('❌ Error generating more phrases: $e');
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isGeneratingMore = false;
      });
    }
  }

  void _quickSelectTopic(String topic) {
    _topicController.text = topic;
    _generatePhrases();
  }
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
            // IMPROVED: Better input section design
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
                  
                  // Text input with better design
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
                  
                  // Generate button with better design
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
                  
                  // Quick topics - IMPROVED design
                  if (!_isLoading && _generatedPhrases.isEmpty) ...[
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
                ],
              ),
            ),
            
            // IMPROVED: Better results section with enhanced scrolling
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // IMPROVED: Results header with better design
        Container(
          padding: const EdgeInsets.all(20),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Phrases for "$_currentTopic"',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${_generatedPhrases.length} phrases generated',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              // FIXED: Generate More button
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isGeneratingMore ? null : _generateMorePhrases,
                  icon: _isGeneratingMore 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
                  label: Text(_isGeneratingMore ? 'Generating...' : 'Generate More Phrases'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    side: BorderSide(color: Theme.of(context).colorScheme.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // IMPROVED: Better scrolling phrases list with performance optimization
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _generatedPhrases.length,
            // Add performance optimizations
            cacheExtent: 200, // Cache nearby items
            itemExtent: null, // Let Flutter calculate
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildPhraseCard(_generatedPhrases[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPhraseCard(PhraseModel phrase) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
        children: [
          // Header with AI badge and favorite button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.purple.withOpacity(0.2), Colors.blue.withOpacity(0.2)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 14,
                        color: Colors.purple[700],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'AI',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple[700],
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _toggleFavorite(phrase), // FIXED: Now toggles favorite status
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      phrase.isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: phrase.isFavorite 
                        ? Theme.of(context).colorScheme.primary 
                        : Colors.grey[600],
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
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
                    size: 22,
                    color: Colors.blue[600],
                  ),
                ],
              ),
            ),
          ),
          
          // Divider
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            color: Colors.grey[200],
          ),
          
          // Spanish section
          GestureDetector(
            onTap: () => _speakSpanish(phrase.spanish),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'ES',
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
                      phrase.spanish,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.volume_up_rounded,
                    size: 22,
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