import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

class ChatInputBar extends StatefulWidget {
  final Function(String) onSendMessage;
  final bool isSending;
  final VoidCallback onScrollToBottom;
  final bool hideBorder;

  const ChatInputBar({
    super.key,
    required this.onSendMessage,
    required this.isSending,
    required this.onScrollToBottom,
    this.hideBorder = false,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final stt.SpeechToText _speech = stt.SpeechToText();
  
  bool _hasText = false;
  bool _isListening = false;
  bool _speechAvailable = false;
  String _lastWords = '';
  
  late AnimationController _micAnimationController;
  late Animation<double> _micAnimation;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _initializeSpeech();
    
    _micAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _micAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _micAnimationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    _micAnimationController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  Future<void> _initializeSpeech() async {
    try {
      // Request microphone permission
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        return;
      }

      _speechAvailable = await _speech.initialize(
        onError: (error) {
          debugPrint('Speech recognition error: $error');
          _stopListening();
        },
        onStatus: (status) {
          debugPrint('Speech recognition status: $status');
          if (status == 'done' || status == 'notListening') {
            _stopListening();
          }
        },
      );
    } catch (e) {
      debugPrint('Failed to initialize speech: $e');
    }
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isNotEmpty && !widget.isSending) {
      widget.onSendMessage(text);
      _controller.clear();
      widget.onScrollToBottom();
    }
  }

  void _handleSubmitted(String text) {
    _sendMessage();
  }

  Future<void> _startListening() async {
    if (!_speechAvailable || _isListening) return;

    try {
      setState(() {
        _isListening = true;
        _lastWords = '';
      });
      
      _micAnimationController.repeat(reverse: true);

      await _speech.listen(
        onResult: (result) {
          setState(() {
            _lastWords = result.recognizedWords;
          });
          
          if (result.finalResult) {
            _controller.text = _lastWords;
            _stopListening();
          }
        },
        localeId: 'en_US', // Default to English, can be made configurable
        cancelOnError: true,
        partialResults: true,
      );
    } catch (e) {
      debugPrint('Error starting speech recognition: $e');
      _stopListening();
    }
  }

  void _stopListening() {
    _speech.stop();
    _micAnimationController.stop();
    _micAnimationController.reset();
    
    setState(() {
      _isListening = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Mic button
              AnimatedBuilder(
                animation: _micAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _micAnimation.value,
                    child: IconButton(
                      onPressed: widget.isSending ? null : _handleMicPress,
                      icon: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color: _getMicColor(),
                      ),
                      tooltip: _isListening ? 'Stop recording' : 'Voice input',
                    ),
                  );
                },
              ),
              
              const SizedBox(width: 8),
              
              // Text field
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(24),
                    border: widget.hideBorder
                        ? null
                        : Border.all(
                            color: _getBorderColor(),
                            width: 2,
                          ),
                  ),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    onSubmitted: _handleSubmitted,
                    enabled: !widget.isSending && !_isListening,
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: _getHintText(),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      hintStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6),
                      ),
                    ),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 8),
              
              // Send button
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: widget.isSending
                    ? const SizedBox(
                        width: 40,
                        height: 40,
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        onPressed: _hasText ? _sendMessage : null,
                        icon: Icon(
                          Icons.send,
                          color: _hasText 
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurface.withOpacity(0.38),
                        ),
                        tooltip: 'Send message',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleMicPress() {
    if (_isListening) {
      _stopListening();
    } else {
      _startListening();
    }
  }

  Color _getMicColor() {
    if (widget.isSending) {
      return Theme.of(context).colorScheme.onSurface.withOpacity(0.38);
    }
    if (_isListening) {
      return Theme.of(context).colorScheme.error;
    }
    return Theme.of(context).colorScheme.primary;
  }

  Color _getBorderColor() {
    if (_isListening) {
      return Theme.of(context).colorScheme.error;
    }
    if (_focusNode.hasFocus) {
      return Theme.of(context).colorScheme.primary;
    }
    return Colors.transparent;
  }

  String _getHintText() {
    if (widget.isSending) {
      return 'AI is typing...';
    }
    if (_isListening) {
      return _lastWords.isNotEmpty ? _lastWords : 'Listening...';
    }
    return 'Type a message...';
  }
} 