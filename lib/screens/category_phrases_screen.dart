//lib/screens/category_phrases_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

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
    super.dispose();
  }

  // Sample phrases data - you can expand this
  List<Phrase> get _phrases {
    switch (widget.categoryTitle) {
      case 'Food & Dining':
        return [
          Phrase(english: 'I would like to order', spanish: 'Me gustaría pedir'),
          Phrase(english: 'The menu, please', spanish: 'La carta, por favor'),
          Phrase(english: 'What do you recommend?', spanish: '¿Qué me recomienda?'),
          Phrase(english: 'I am vegetarian', spanish: 'Soy vegetariano/a'),
          Phrase(english: 'The bill, please', spanish: 'La cuenta, por favor'),
          Phrase(english: 'Is this spicy?', spanish: '¿Está picante?'),
          Phrase(english: 'I am allergic to...', spanish: 'Soy alérgico/a a...'),
          Phrase(english: 'More water, please', spanish: 'Más agua, por favor'),
        ];
      case 'Transport':
        return [
          Phrase(english: 'Where is the bus station?', spanish: '¿Dónde está la estación de autobús?'),
          Phrase(english: 'How much is a ticket?', spanish: '¿Cuánto cuesta un boleto?'),
          Phrase(english: 'I need to go to...', spanish: 'Necesito ir a...'),
          Phrase(english: 'Is this the right bus?', spanish: '¿Es este el autobús correcto?'),
          Phrase(english: 'Please stop here', spanish: 'Pare aquí, por favor'),
          Phrase(english: 'Call a taxi, please', spanish: 'Llame un taxi, por favor'),
        ];
      case 'Emergencies':
        return [
          Phrase(english: 'Help!', spanish: '¡Ayuda!'),
          Phrase(english: 'Call the police', spanish: 'Llame a la policía'),
          Phrase(english: 'I need a doctor', spanish: 'Necesito un médico'),
          Phrase(english: 'Where is the hospital?', spanish: '¿Dónde está el hospital?'),
          Phrase(english: 'I am lost', spanish: 'Estoy perdido/a'),
          Phrase(english: 'Call an ambulance', spanish: 'Llame una ambulancia'),
        ];
      case 'Greetings':
        return [
          Phrase(english: 'Hello', spanish: 'Hola'),
          Phrase(english: 'Good morning', spanish: 'Buenos días'),
          Phrase(english: 'Good afternoon', spanish: 'Buenas tardes'),
          Phrase(english: 'Good night', spanish: 'Buenas noches'),
          Phrase(english: 'Please', spanish: 'Por favor'),
          Phrase(english: 'Thank you', spanish: 'Gracias'),
          Phrase(english: 'Excuse me', spanish: 'Disculpe'),
          Phrase(english: 'See you later', spanish: 'Hasta luego'),
        ];
      case 'Shopping':
        return [
          Phrase(english: 'How much does this cost?', spanish: '¿Cuánto cuesta esto?'),
          Phrase(english: 'Do you accept credit cards?', spanish: '¿Aceptan tarjetas de crédito?'),
          Phrase(english: 'Can I try this on?', spanish: '¿Me lo puedo probar?'),
          Phrase(english: 'Do you have this in another size?', spanish: '¿Tienen esto en otra talla?'),
          Phrase(english: 'I am just looking', spanish: 'Solo estoy mirando'),
          Phrase(english: 'Where is the cashier?', spanish: '¿Dónde está la caja?'),
        ];
      case 'Accommodation':
        return [
          Phrase(english: 'I have a reservation', spanish: 'Tengo una reservación'),
          Phrase(english: 'Do you have available rooms?', spanish: '¿Tienen habitaciones disponibles?'),
          Phrase(english: 'What time is check-out?', spanish: '¿A qué hora es el check-out?'),
          Phrase(english: 'Can I have extra towels?', spanish: '¿Puedo tener toallas extra?'),
          Phrase(english: 'The Wi-Fi password, please', spanish: 'La contraseña del Wi-Fi, por favor'),
          Phrase(english: 'Where is the elevator?', spanish: '¿Dónde está el ascensor?'),
        ];
      default:
        return [];
    }
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
      body: _phrases.isEmpty
          ? Center(
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
                    'Phrases coming soon!',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _phrases.length,
              itemBuilder: (context, index) {
                return _buildPhraseCard(_phrases[index]);
              },
            ),
    );
  }

  Widget _buildPhraseCard(Phrase phrase) {
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
          // English section
          GestureDetector(
            onTap: () => _speakEnglish(phrase.english),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
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

// Data model for phrases
class Phrase {
  final String english;
  final String spanish;

  Phrase({
    required this.english,
    required this.spanish,
  });
}