import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/chat_message_model.dart';
import '../core/providers/flashcard_provider.dart';

class ChatMessageBubble extends StatefulWidget {
  final ChatMessage message;
  final VoidCallback onToggleFavorite;
  final VoidCallback onToggleFlashcard;
  final VoidCallback onCopy;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.onToggleFavorite,
    required this.onToggleFlashcard,
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

  void _showFlashcardDialog() async {
    final flashcardProvider = Provider.of<FlashcardProvider>(context, listen: false);
    final isUser = widget.message.sender == 'user';
    final front = isUser ? widget.message.text : '';
    final back = isUser ? '' : widget.message.text;
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
                labelText: 'Front (question/word)',
                border: OutlineInputBorder(),
              ),
              minLines: 1,
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controllerBack,
              decoration: const InputDecoration(
                labelText: 'Back (answer/translation)',
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
        const SnackBar(content: Text('Flashcard saved!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.sender == 'user';
    
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
                _buildMessageBubble(context, isUser),
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
    final isUser = widget.message.sender == 'user';
    
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
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      decoration: BoxDecoration(
        color: isUser
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isUser ? 16 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 16),
        ),
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
                data: widget.message.text,
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Speaker button (only for AI messages)
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
        // Flashcard button
        IconButton(
          onPressed: _showFlashcardDialog,
          icon: Icon(
            widget.message.isFlashcard ? Icons.style : Icons.style_outlined,
            size: 16,
            color: widget.message.isFlashcard 
                ? Theme.of(context).colorScheme.primary 
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          tooltip: widget.message.isFlashcard ? 'Remove from flashcards' : 'Add to flashcards',
        ),
        // Favorite button
        IconButton(
          onPressed: widget.onToggleFavorite,
          icon: Icon(
            widget.message.isFavorite ? Icons.favorite : Icons.favorite_border,
            size: 16,
            color: widget.message.isFavorite 
                ? Colors.red 
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          tooltip: widget.message.isFavorite ? 'Remove from favorites' : 'Add to favorites',
        ),
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
} 