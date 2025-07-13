//lib/screens/phrase_search_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/phrase_model.dart';
import '../services/phrase_service.dart';

class PhraseSearchScreen extends StatefulWidget {
  const PhraseSearchScreen({Key? key}) : super(key: key);

  @override
  _PhraseSearchScreenState createState() => _PhraseSearchScreenState();
}

class _PhraseSearchScreenState extends State<PhraseSearchScreen> with WidgetsBindingObserver {
  final PhraseService _phraseService = PhraseService();
  final TextEditingController _searchController = TextEditingController();
  List<PhraseModel> _allPhrases = [];
  List<PhraseModel> _filteredPhrases = [];
  late FlutterTts _tts;
  bool _ttsReady = false;
  String _searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initTts();
    _phraseService.allPhrasesStream.listen((phrases) {
      if (mounted) {
        setState(() {
          _allPhrases = phrases;
          _filterPhrases();
        });
      }
    });
    _searchController.addListener(_filterPhrases);
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
    _searchController.dispose();
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
        _tts.stop();
        break;
      case AppLifecycleState.resumed:
        // App resumed - no action needed
        break;
    }
  }

  void _filterPhrases() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredPhrases = _allPhrases.where((phrase) {
        return phrase.english.toLowerCase().contains(query) ||
               phrase.spanish.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _speakSpanish(String text) async {
    if (_ttsReady) {
      try {
        // Stop any current speech
        await _tts.stop();
        
        // Try different Spanish language codes
        var result = await _tts.setLanguage('es-ES');
        
        if (result == 1) {
          await _tts.speak(text);
        } else {
          // Try alternative Spanish codes
          result = await _tts.setLanguage('es-MX');
          
          if (result == 1) {
            await _tts.speak(text);
          } else {
            result = await _tts.setLanguage('es-US');
            
            if (result == 1) {
              await _tts.speak(text);
            } else {
              await _tts.speak(text);
            }
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
        // Stop any current speech
        await _tts.stop();
        
        var result = await _tts.setLanguage('en-US');
        
        if (result == 1) {
          await _tts.speak(text);
        } else {
          // Try alternative English codes
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Search Phrases'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search English or Spanish...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredPhrases.length,
              itemBuilder: (context, index) {
                final phrase = _filteredPhrases[index];
                return ListTile(
                  title: Text(phrase.english),
                  subtitle: Text(phrase.spanish),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}