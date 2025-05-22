//lib/screens/phrase_search_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class PhraseSearchScreen extends StatefulWidget {
  const PhraseSearchScreen({super.key});

  @override
  State<PhraseSearchScreen> createState() => _PhraseSearchScreenState();
}

class _PhraseSearchScreenState extends State<PhraseSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  late FlutterTts _tts;
  bool _ttsReady = false;
  String _searchQuery = '';
  
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
    _searchController.dispose();
    super.dispose();
  }

  // All phrases from all categories
  List<PhraseWithCategory> get _allPhrases {
    return [
      // Food & Dining
      PhraseWithCategory(english: 'I would like to order', spanish: 'Me gustaría pedir', category: 'Food & Dining'),
      PhraseWithCategory(english: 'The menu, please', spanish: 'La carta, por favor', category: 'Food & Dining'),
      PhraseWithCategory(english: 'What do you recommend?', spanish: '¿Qué me recomienda?', category: 'Food & Dining'),
      PhraseWithCategory(english: 'I am vegetarian', spanish: 'Soy vegetariano/a', category: 'Food & Dining'),
      PhraseWithCategory(english: 'The bill, please', spanish: 'La cuenta, por favor', category: 'Food & Dining'),
      PhraseWithCategory(english: 'Is this spicy?', spanish: '¿Está picante?', category: 'Food & Dining'),
      PhraseWithCategory(english: 'I am allergic to...', spanish: 'Soy alérgico/a a...', category: 'Food & Dining'),
      PhraseWithCategory(english: 'More water, please', spanish: 'Más agua, por favor', category: 'Food & Dining'),

      // Transport
      PhraseWithCategory(english: 'Where is the bus station?', spanish: '¿Dónde está la estación de autobús?', category: 'Transport'),
      PhraseWithCategory(english: 'How much is a ticket?', spanish: '¿Cuánto cuesta un boleto?', category: 'Transport'),
      PhraseWithCategory(english: 'I need to go to...', spanish: 'Necesito ir a...', category: 'Transport'),
      PhraseWithCategory(english: 'Is this the right bus?', spanish: '¿Es este el autobús correcto?', category: 'Transport'),
      PhraseWithCategory(english: 'Please stop here', spanish: 'Pare aquí, por favor', category: 'Transport'),
      PhraseWithCategory(english: 'Call a taxi, please', spanish: 'Llame un taxi, por favor', category: 'Transport'),

      // Emergencies
      PhraseWithCategory(english: 'Help!', spanish: '¡Ayuda!', category: 'Emergencies'),
      PhraseWithCategory(english: 'Call the police', spanish: 'Llame a la policía', category: 'Emergencies'),
      PhraseWithCategory(english: 'I need a doctor', spanish: 'Necesito un médico', category: 'Emergencies'),
      PhraseWithCategory(english: 'Where is the hospital?', spanish: '¿Dónde está el hospital?', category: 'Emergencies'),
      PhraseWithCategory(english: 'I am lost', spanish: 'Estoy perdido/a', category: 'Emergencies'),
      PhraseWithCategory(english: 'Call an ambulance', spanish: 'Llame una ambulancia', category: 'Emergencies'),

      // Greetings
      PhraseWithCategory(english: 'Hello', spanish: 'Hola', category: 'Greetings'),
      PhraseWithCategory(english: 'Good morning', spanish: 'Buenos días', category: 'Greetings'),
      PhraseWithCategory(english: 'Good afternoon', spanish: 'Buenas tardes', category: 'Greetings'),
      PhraseWithCategory(english: 'Good night', spanish: 'Buenas noches', category: 'Greetings'),
      PhraseWithCategory(english: 'Please', spanish: 'Por favor', category: 'Greetings'),
      PhraseWithCategory(english: 'Thank you', spanish: 'Gracias', category: 'Greetings'),
      PhraseWithCategory(english: 'Excuse me', spanish: 'Disculpe', category: 'Greetings'),
      PhraseWithCategory(english: 'See you later', spanish: 'Hasta luego', category: 'Greetings'),

      // Shopping
      PhraseWithCategory(english: 'How much does this cost?', spanish: '¿Cuánto cuesta esto?', category: 'Shopping'),
      PhraseWithCategory(english: 'Do you accept credit cards?', spanish: '¿Aceptan tarjetas de crédito?', category: 'Shopping'),
      PhraseWithCategory(english: 'Can I try this on?', spanish: '¿Me lo puedo probar?', category: 'Shopping'),
      PhraseWithCategory(english: 'Do you have this in another size?', spanish: '¿Tienen esto en otra talla?', category: 'Shopping'),
      PhraseWithCategory(english: 'I am just looking', spanish: 'Solo estoy mirando', category: 'Shopping'),
      PhraseWithCategory(english: 'Where is the cashier?', spanish: '¿Dónde está la caja?', category: 'Shopping'),

      // Accommodation
      PhraseWithCategory(english: 'I have a reservation', spanish: 'Tengo una reservación', category: 'Accommodation'),
      PhraseWithCategory(english: 'Do you have available rooms?', spanish: '¿Tienen habitaciones disponibles?', category: 'Accommodation'),
      PhraseWithCategory(english: 'What time is check-out?', spanish: '¿A qué hora es el check-out?', category: 'Accommodation'),
      PhraseWithCategory(english: 'Can I have extra towels?', spanish: '¿Puedo tener toallas extra?', category: 'Accommodation'),
      PhraseWithCategory(english: 'The Wi-Fi password, please', spanish: 'La contraseña del Wi-Fi, por favor', category: 'Accommodation'),
      PhraseWithCategory(english: 'Where is the elevator?', spanish: '¿Dónde está el ascensor?', category: 'Accommodation'),
    ];
  }

  List<PhraseWithCategory> get _filteredPhrases {
    if (_searchQuery.isEmpty) {
      return [];
    }
    return _allPhrases.where((phrase) =>
      phrase.english.toLowerCase().contains(_searchQuery) ||
      phrase.spanish.toLowerCase().contains(_searchQuery)
    ).toList();
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

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Phrases'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search phrases in English or Spanish...',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  prefixIcon: Icon(
                    Icons.search,
                    color: primaryColor,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              ),
            ),
          ),

          // Search results
          Expanded(
            child: _searchQuery.isEmpty
                ? Center(
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
                          'Search in English or Spanish',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : _filteredPhrases.isEmpty
                    ? Center(
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
                              'No phrases found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try a different search term',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredPhrases.length,
                        itemBuilder: (context, index) {
                          return _buildPhraseCard(_filteredPhrases[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhraseCard(PhraseWithCategory phrase) {
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
          // Category badge
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Text(
              phrase.category,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
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

// Data model for phrases with category info
class PhraseWithCategory {
  final String english;
  final String spanish;
  final String category;

  PhraseWithCategory({
    required this.english,
    required this.spanish,
    required this.category,
  });
}