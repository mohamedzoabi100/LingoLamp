//lib/screens/category_phrases_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/phrase_service.dart';

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

class _CategoryPhrasesScreenState extends State<CategoryPhrasesScreen> {
  late FlutterTts _tts;
  bool _ttsReady = false;
  final PhraseService _phraseService = PhraseService();

  @override
  void initState() {
    super.initState();
    _initTts();
    // Initialize sample data on first run
    _phraseService.initializeSampleData();
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

  Future<void> _toggleFavorite(PhraseModel phrase) async {
    await _phraseService.toggleFavorite(phrase.id);
    // Show a snackbar to give user feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !phrase.isFavorite 
              ? '❤️ Added to favorites' 
              : 'Removed from favorites',
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: !phrase.isFavorite 
            ? Theme.of(context).colorScheme.primary
            : Colors.grey[600],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    return Scaffold(
      appBar: AppBar(
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
      body: StreamBuilder<List<PhraseModel>>(
        stream: _phraseService.getPhrasesForCategory(widget.categoryTitle),
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
                      _phraseService.initializeSampleData();
                    },
                    child: const Text('Load Sample Data'),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            spreadRadius: 0,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with favorite button
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
          
          // Spanish section
          GestureDetector(
            onTap: () => _speakSpanish(phrase.spanish),
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