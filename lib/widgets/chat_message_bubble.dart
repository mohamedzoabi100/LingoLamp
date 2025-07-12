import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/chat_message_model.dart';
import '../core/providers/flashcard_provider.dart';
import '../utils/flashcard_extractor.dart';

class ChatMessageBubble extends StatefulWidget {
  final ChatMessage message;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onToggleFlashcard;
  final VoidCallback onCopy;

  const ChatMessageBubble({
    super.key,
    required this.message,
    this.onToggleFavorite,
    this.onToggleFlashcard,
    required this.onCopy,
  });

  @override
  State<ChatMessageBubble> createState() => _ChatMessageBubbleState();
}

class _ChatMessageBubbleState extends State<ChatMessageBubble> {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeTts();
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _initializeTts() async {
    try {
      await _flutterTts.setLanguage('es-ES'); // Spanish for AI responses
      await _flutterTts.setSpeechRate(0.5); // Slower for learning
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      
      _flutterTts.setStartHandler(() {
        setState(() {
          _isSpeaking = true;
        });
      });
      
      _flutterTts.setCompletionHandler(() {
        setState(() {
          _isSpeaking = false;
        });
      });
      
      _flutterTts.setErrorHandler((msg) {
        setState(() {
          _isSpeaking = false;
        });
        debugPrint('TTS Error: $msg');
      });
      
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint('Failed to initialize TTS: $e');
    }
  }

  Future<void> _speakText() async {
    if (!_isInitialized || _isSpeaking) return;

    try {
      await _flutterTts.speak(_getPlainText(widget.message.text));
    } catch (e) {
      debugPrint('Error speaking text: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to play audio')),
        );
      }
    }
  }

  Future<void> _stopSpeaking() async {
    if (_isSpeaking) {
      await _flutterTts.stop();
    }
  }

  String _getPlainText(String markdown) {
    // Remove markdown formatting for TTS
    return markdown.replaceAll(RegExp(r'[\*_`#\[\]()>-]'), '').replaceAll(RegExp(r'\n+'), ' ');
  }

  String _detectLanguage(String text) {
    // Simple language detection based on common patterns
    if (text.contains('¿') || text.contains('á') || text.contains('é') || text.contains('í') || text.contains('ó') || text.contains('ú')) {
      return 'es';
    }
    if (text.contains('à') || text.contains('â') || text.contains('é') || text.contains('è') || text.contains('ê') || text.contains('î') || text.contains('ô') || text.contains('û')) {
      return 'fr';
    }
    if (text.contains('ä') || text.contains('ö') || text.contains('ü') || text.contains('ß')) {
      return 'de';
    }
    if (text.contains('à') || text.contains('è') || text.contains('é') || text.contains('ì') || text.contains('ò') || text.contains('ù')) {
      return 'it';
    }
    if (text.contains('ã') || text.contains('õ') || text.contains('ç')) {
      return 'pt';
    }
    return 'en'; // Default to English
  }

  String _getTtsLanguageCode(String language) {
    final languageMap = {
      'en': 'en-US',
      'es': 'es-ES',
      'fr': 'fr-FR',
      'de': 'de-DE',
      'it': 'it-IT',
      'pt': 'pt-BR',
    };
    return languageMap[language] ?? 'en-US';
  }

  String _getVoiceName(String language) {
    final voiceMap = {
      'en': 'en-US-Standard-A',
      'es': 'es-ES-Standard-A',
      'fr': 'fr-FR-Standard-A',
      'de': 'de-DE-Standard-A',
      'it': 'it-IT-Standard-A',
      'pt': 'pt-BR-Standard-A',
    };
    return voiceMap[language] ?? 'en-US-Standard-A';
  }

  String cleanMessageForDisplay(String text) {
    // Remove visible JSON payloads
    return text.replaceAll(RegExp(r'\{"tool":"create_flashcard".*?\}', dotAll: true), '').trim();
  }

  void _showFlashcardDialog() async {
    final flashcardProvider = Provider.of<FlashcardProvider>(context, listen: false);
    final isUser = widget.message.isUserMessage;
    
    // Try to extract flashcard data from AI response
    FlashcardData? extractedData;
    if (!isUser) {
      extractedData = FlashcardExtractor.extractFlashcardData(widget.message.text);
    }
    
    final front = extractedData?.front ?? (isUser ? widget.message.text : '');
    final back = extractedData?.back ?? (isUser ? '' : widget.message.text);
    
    // Check if flashcard already exists
    if (extractedData != null) {
      final exists = flashcardProvider.flashcards.any((card) =>
          card.originalText.toLowerCase() == front.toLowerCase() &&
          card.translatedText.toLowerCase() == back.toLowerCase());
      
      if (exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This flashcard already exists!'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
    }
    
    final controllerFront = TextEditingController(text: front);
    final controllerBack = TextEditingController(text: back);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save as Flashcard'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controllerFront,
              decoration: const InputDecoration(
                labelText: 'Front (English)',
                border: OutlineInputBorder(),
              ),
              minLines: 1,
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controllerBack,
              decoration: const InputDecoration(
                labelText: 'Back (Spanish)',
                border: OutlineInputBorder(),
              ),
              minLines: 1,
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final frontText = controllerFront.text.trim();
              final backText = controllerBack.text.trim();
              if (frontText.isNotEmpty && backText.isNotEmpty) {
                flashcardProvider.addFlashcard(frontText, backText, 'Chat');
                Navigator.pop(context, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Flashcard saved! 📚'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.isUserMessage;
    final hasFlashcardData = !isUser && FlashcardExtractor.hasFlashcardData(widget.message.text);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) _buildAvatar(context),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasFlashcardData) ...[
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(
                          Icons.translate,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(child: _buildMessageBubble(context, isUser)),
                  ],
                ),
                const SizedBox(height: 4),
                _buildMessageActions(context, isUser),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isUser) _buildAvatar(context),
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    final isUser = widget.message.isUserMessage;
    
    return CircleAvatar(
      radius: 16,
      backgroundColor: isUser 
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.secondary,
      child: Icon(
        isUser ? Icons.person : Icons.smart_toy,
        size: 16,
        color: isUser 
            ? Theme.of(context).colorScheme.onPrimary
            : Theme.of(context).colorScheme.onSecondary,
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, bool isUser) {
    final hasFlashcardData = !isUser && FlashcardExtractor.hasFlashcardData(widget.message.text);
    
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      decoration: BoxDecoration(
        color: isUser
            ? Theme.of(context).colorScheme.primary
            : hasFlashcardData
                ? Theme.of(context).colorScheme.primary.withOpacity(0.05)
                : Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isUser ? 16 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 16),
        ),
        border: hasFlashcardData
            ? Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                width: 1,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: isUser
            ? Text(
                widget.message.text,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 16,
                  height: 1.4,
                ),
              )
            : MarkdownBody(
                data: cleanMessageForDisplay(widget.message.text),
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 16,
                    height: 1.4,
                  ),
                  strong: const TextStyle(fontWeight: FontWeight.bold),
                  em: const TextStyle(fontStyle: FontStyle.italic),
                  code: TextStyle(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    fontFamily: 'monospace',
                  ),
                ),
                onTapLink: (text, href, title) {
                  // Optionally handle links
                },
              ),
      ),
    );
  }

  Widget _buildMessageActions(BuildContext context, bool isUser) {
    final hasFlashcardData = !isUser && FlashcardExtractor.hasFlashcardData(widget.message.text);
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isUser) ...[
          IconButton(
            onPressed: _isSpeaking ? _stopSpeaking : _speakText,
            icon: Icon(
              _isSpeaking ? Icons.stop : Icons.volume_up,
              size: 16,
              color: _isSpeaking 
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            tooltip: _isSpeaking ? 'Stop audio' : 'Listen to pronunciation',
          ),
          const SizedBox(width: 4),
        ],
        // Only show flashcard button if you want to reimplement it via provider
        // Copy button
        IconButton(
          onPressed: widget.onCopy,
          icon: Icon(
            Icons.copy,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          tooltip: 'Copy message',
        ),
      ],
    );
  }

  Widget _buildFlashcardButton(BuildContext context, bool isTranslation) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showFlashcardDialog,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.library_add_rounded,
                  size: 14,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Save',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 