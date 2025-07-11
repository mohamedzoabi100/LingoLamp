// lib/screens/chat_screen.dart
// ** FINAL VERSION **

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as gen_ai;

import '../services/ai_chat_service.dart';
import '../utils/database_helper.dart';
import '../models/chat_message_model.dart' as model;
import '../models/conversation_model.dart';
import '../models/flashcard_model.dart';
import '../models/phrase_model.dart';
import 'chat_history_screen.dart';
import '../services/xp_event_tracker.dart';
import '../services/user_data_service.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/chat_input_bar.dart';

const targetLangCode = 'es-ES';

class ChatScreen extends StatefulWidget {
  final VoidCallback? onBackToHome;

  final int? conversationId;
  final void Function(int)? onConversationIdChanged;
  const ChatScreen({Key? key, this.conversationId, this.onBackToHome, this.onConversationIdChanged})
      : super(key: key);


  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

// Add this helper class at the top of lib/screens/chat_screen.dart
class FlashcardData {
  final String front;
  final String back;
  FlashcardData({required this.front, required this.back});
}

class _ChatScreenState extends State<ChatScreen> {
  final _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final AiChatService _aiChatService = AiChatService();
  final FlutterTts _tts = FlutterTts();

  final List<model.ChatMessage> _messages = [];
  int? _currentConversationId;
  Conversation? _currentConversation;
  bool _isResponding = false;
  bool _isConversationReady = false;
  bool _showScrollToBottom = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _initChat();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final atBottom = _scrollController.offset >= _scrollController.position.maxScrollExtent - 20;
    if (_showScrollToBottom == atBottom) {
      setState(() { _showScrollToBottom = !atBottom; });
    }
  }

  void _maybeShowScrollToBottom(List messages) {
    if (!_scrollController.hasClients) return;
    final atBottom = _scrollController.offset >= _scrollController.position.maxScrollExtent - 20;
    if (!atBottom && messages.isNotEmpty) {
      setState(() { _showScrollToBottom = true; });
    } else {
      setState(() { _showScrollToBottom = false; });
    }
  }

  Future<void> _initChat() async {
    setState(() { _isConversationReady = false; });
    if (widget.conversationId != null) {
      await _loadConversationAndMessages(widget.conversationId!);
      setState(() { _isConversationReady = true; });
    } else {
      // Ensure a new conversation is created and loaded
      await _ensureConversationExists();
      if (_currentConversationId != null) {
        await _loadConversationAndMessages(_currentConversationId!);
        if (widget.onConversationIdChanged != null) {
          widget.onConversationIdChanged!(_currentConversationId!);
        }
      }
      setState(() { _isConversationReady = true; });
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.conversationId != oldWidget.conversationId && widget.conversationId != null) {
      debugPrint('[CHAT] didUpdateWidget: conversationId changed to ${widget.conversationId}');
      _currentConversationId = widget.conversationId;
      _loadConversationAndMessages(_currentConversationId!).then((_) {
        if (mounted) setState(() { _isResponding = false; });
      });
    }
  }

  Widget _buildBubbleButton(IconData icon, String label, VoidCallback onPressed) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primaryColor.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: primaryColor),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, color: primaryColor, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Future<void> _initTts() async {
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  Future<void> _loadConversationAndMessages(int conversationId) async {
    _currentConversation = await _dbHelper.getConversation(conversationId);
    if (_currentConversation == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load conversation. It may have been deleted.'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      }
      return;
    }
    final dbMessages = await _dbHelper.getMessagesForConversation(conversationId);
    // Update the chat stream for this conversation
    _dbHelper.updateChatStreamForConversation(conversationId);
    if (!mounted) return;
    setState(() {
      _currentConversationId = conversationId;
    });
    _scrollToBottom(milliseconds: 100);
  }
  
  Future<void> _ensureConversationExists() async {
    if (_currentConversationId == null && _messages.isNotEmpty) {
      final now = DateTime.now();
      final firstUserMessage = _messages.firstWhere((m) => m.sender == 'user', orElse: () => _messages.first).text;
      final convoTitle = firstUserMessage.substring(0, firstUserMessage.length > 30 ? 30 : firstUserMessage.length);
      Conversation newConvo = Conversation(
        id: UniqueKey().toString(),
        title: convoTitle,
        createdAt: now,
        updatedAt: now,
      );
      _currentConversationId = await _dbHelper.insertConversation(newConvo);
      _currentConversation = await _dbHelper.getConversation(_currentConversationId!);
      if (widget.onConversationIdChanged != null) {
        widget.onConversationIdChanged!(_currentConversationId!);
      }
      for (int i = 0; i < _messages.length; i++) {
        if (_messages[i].conversationId == -1) {
          final oldMsg = _messages[i];
          final newMsg = model.ChatMessage(
            id: oldMsg.id,
            conversationId: _currentConversationId!.toString(),
            sender: oldMsg.sender,
            text: oldMsg.text,
            timestamp: oldMsg.timestamp,
          );
          _messages[i] = newMsg;
          await _dbHelper.insertMessage(newMsg);
        }
      }
    }
  }

  // In lib/screens/chat_screen.dart, inside _ChatScreenState
  // REPLACE your _handleSubmittedText function with this:

  Future<void> _handleSubmittedText() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isResponding) return;
    
    _inputController.clear();
    FocusScope.of(context).unfocus();
    debugPrint('[CHAT] User submitted: $text');

    final userMessage = model.ChatMessage(
      id: UniqueKey().toString(),
      conversationId: (_currentConversationId ?? -1).toString(),
      sender: 'user',
      text: text,
      timestamp: DateTime.now(),
    );
    
    if (!mounted) return;
    setState(() { 
      _isResponding = true; 
    });
    _scrollToBottom();
    
    try {
    await _ensureConversationExists();

    final messageToSave = model.ChatMessage(
        id: UniqueKey().toString(),
        conversationId: _currentConversationId!.toString(),
        sender: 'user',
        text: userMessage.text,
        timestamp: userMessage.timestamp,
      );
        
    await _dbHelper.insertMessage(messageToSave);
      debugPrint('[CHAT] Message saved to DB');
      
      // Update chat stream
      _dbHelper.updateChatStreamForConversation(_currentConversationId!);
    
      final aiResponseText = await _aiChatService.sendMessage(messageToSave.text);
      debugPrint('[CHAT] AI response: $aiResponseText');
    
    final aiMessage = model.ChatMessage(
      id: UniqueKey().toString(),
      conversationId: _currentConversationId!.toString(),
      sender: 'ai',
      text: aiResponseText,
      timestamp: DateTime.now(),
    );
    
    await _dbHelper.insertMessage(aiMessage);
      // Update chat stream again
      _dbHelper.updateChatStreamForConversation(_currentConversationId!);
      
      await _loadConversationAndMessages(_currentConversationId!);
      
      if (mounted) {
        setState(() { _isResponding = false; });
    _scrollToBottom();
      }
    } catch (e, st) {
      debugPrint('[CHAT] Error in _handleSubmittedText: $e\n$st');
      
      if (mounted) {
        setState(() { _isResponding = false; });
        
        // Show user-friendly error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message. Please try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // In _ChatScreenState, REPLACE this function
  Future<void> _addToFlashcards(String originalText, String translatedText) async {
    // No cleaning needed, as we get perfect data from the JSON
    if (await _dbHelper.flashcardExists(originalText, translatedText)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('This flashcard already exists!'),
            backgroundColor: Colors.orange));
      }
      return;
    }
    final flashcard = Flashcard(
      originalText: originalText,
      translatedText: translatedText,
      sourceLanguage: 'en-US',
      targetLanguage: 'es-ES',
      createdAt: DateTime.now(),
      lastStudied: DateTime.now(),
      timesStudied: 0,
      difficulty: 2,
      isFavorite: false,
      category: 'Chat Generated',
      tags: ['chat', 'ai-generated'],
    );
    await _dbHelper.insertFlashcard(flashcard);

    // Remove from recommendations if it exists there
    await _dbHelper.deleteRecommendedByTerm(originalText);

    // Award XP for creating flashcard from chat
    final xpTracker = XPEventTracker();
    xpTracker.addXP(XPEventTracker.flashcardCreatedFromChat, 'Flashcard created from chat');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Added to flashcards! 📚'),
          backgroundColor: Colors.green));
    }
  }

  void _scrollToBottom({int milliseconds = 300}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: milliseconds), curve: Curves.easeOut);
      }
    });
  }
  
  // The rest of the file...
  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    String appBarTitle = _currentConversation?.title ?? 'AI Language Tutor';
    return Scaffold(
      appBar: AppBar( 
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (widget.onBackToHome != null) {
              widget.onBackToHome!();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(appBarTitle, 
         overflow: TextOverflow.ellipsis), 
         backgroundColor: primaryColor, 
         foregroundColor: Colors.white, 
         actions: [
        IconButton(
          icon: const Icon(Icons.history),
          tooltip: 'Chat History',
          onPressed: () async {
            if (_inputController.text.isNotEmpty) {
              final discard = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Discard unsent message?'),
                  content: const Text('You have unsent input. Discard and continue?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Discard')),
                  ],
                ),
              );
              if (discard != true) return;
            }
            final selectedId = await Navigator.push<int?>(context, MaterialPageRoute(builder: (context) => const ChatHistoryScreen()));
            if (selectedId != null && selectedId != _currentConversationId) {
              _currentConversationId = selectedId;
              _loadConversationAndMessages(selectedId);
            }
          },
        ),
        PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'new') {
              if (_inputController.text.isNotEmpty) {
                final discard = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Discard unsent message?'),
                    content: const Text('You have unsent input. Discard and start a new chat?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Discard')),
                    ],
                  ),
                );
                if (discard != true) return;
              }
              // Confirm if the current chat has any messages (other than greeting)
              final currentMessages = await _dbHelper.getMessagesForConversation(_currentConversationId ?? -1);
              final hasRealMessages = currentMessages.any((m) => m.sender == 'user' || (m.text != "¡Hola! I'm Lingo, your personal Spanish tutor. How can I help you practice today?"));
              if (hasRealMessages) {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Start new chat?'),
                    content: const Text('You have an active chat. Start a new chat and discard the current one?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Start New Chat')),
                    ],
                  ),
                );
                if (confirm != true) return;
              }
              setState(() { _isConversationReady = false; });
              final now = DateTime.now();
              final greeting = "¡Hola! I'm Lingo, your personal Spanish tutor. How can I help you practice today?";
              final newConvo = Conversation(
                id: UniqueKey().toString(),
                title: 'New Chat',
                createdAt: now,
                updatedAt: now,
              );
              final newId = await _dbHelper.insertConversation(newConvo);
              final greetingMsg = model.ChatMessage(
                id: UniqueKey().toString(),
                conversationId: newId.toString(),
                sender: 'ai',
                text: greeting,
                timestamp: now,
              );
              await _dbHelper.insertMessage(greetingMsg);
              _currentConversationId = newId;
              _currentConversation = newConvo;
              if (widget.onConversationIdChanged != null) {
                widget.onConversationIdChanged!(newId);
              }
              // Poll the DB until the greeting is present (max 500ms)
              bool found = false;
              for (int i = 0; i < 5; i++) {
                final msgs = await _dbHelper.getMessagesForConversation(newId);
                if (msgs.any((m) => m.text == greeting)) {
                  found = true;
                  break;
                }
                await Future.delayed(const Duration(milliseconds: 100));
              }
              if (!found) {
                if (mounted) {
                  setState(() { _isConversationReady = true; });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to load greeting message. Please try again.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return;
              }
              await _loadConversationAndMessages(newId);
              setState(() { _isConversationReady = true; });
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'new',
              child: Text('New Chat'),
            ),
          ],
        ),
      ]),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: _isConversationReady
        ? StreamBuilder<List<model.ChatMessage>>(
            stream: _dbHelper.chatStream,
            builder: (context, snapshot) {
              final messages = snapshot.data ?? [];
              WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowScrollToBottom(messages));
              return Stack(
                children: [
                  Column(children: [
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (_, index) => _buildChatBubble(messages[index]),
                      ),
                    ),
        if (_isResponding)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Row(children: [
              SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor)),
              const SizedBox(width: 12),
              Text("Lingo is typing...", style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic)),
            ]),
          ),
        _buildInputRow(primaryColor),
      ]),
                  if (_showScrollToBottom)
                    Positioned(
                      right: 16,
                      bottom: 80,
                      child: FloatingActionButton(
                        mini: true,
                        backgroundColor: primaryColor,
                        child: const Icon(Icons.arrow_downward, color: Colors.white),
                        onPressed: () {
                          _scrollToBottom(milliseconds: 300);
                        },
                      ),
                    ),
                ],
              );
            },
          )
        : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildInputRow(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), spreadRadius: 1, blurRadius: 8, offset: const Offset(0, -3))]),
      child: SafeArea(child: Row(children: [
        Expanded(
          child: TextField(
            controller: _inputController,
            // Removed onSubmitted to avoid double submission
            textInputAction: TextInputAction.send,
            decoration: InputDecoration(
              hintText: 'Ask Lingo anything...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(25.0), borderSide: BorderSide.none),
              filled: true,
              fillColor: Colors.grey[100],
              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            ),
            enabled: !_isResponding && _isConversationReady,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: (!_isResponding && _isConversationReady) ? _handleSubmittedText : null,
          icon: Icon(Icons.send_rounded, color: primaryColor),
          tooltip: 'Send',
        ),
      ])),
    );
  }

  // In lib/screens/chat_screen.dart, inside _ChatScreenState

 // In lib/screens/chat_screen.dart, inside _ChatScreenState
// REPLACE your _buildChatBubble function with this:

  Widget _buildChatBubble(model.ChatMessage message) {
    final bool isUser = message.sender == 'user';
    final primaryColor = Theme.of(context).colorScheme.primary;

    String textForDisplay;
    
    // On AI messages, we check for hidden data.
    if (!isUser) {
      final flashcardData = _extractFlashcardData(message.text);
      if (flashcardData != null) {
        // If we found data, we construct our own friendly message to show the user.
        textForDisplay = "The translation for \"${flashcardData.front}\" is **${flashcardData.back}**.";
      } else {
        // If no data, it's a normal conversation, so we display the text as is.
        textForDisplay = message.text;
      }
    } else {
      // For user messages, we always display their text directly.
      textForDisplay = message.text;
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
        decoration: BoxDecoration(
          color: isUser ? primaryColor : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MarkdownBody(
              data: textForDisplay,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(fontSize: 16.0, color: isUser ? Colors.white : Colors.black87),
                strong: TextStyle(fontSize: 16.0, color: isUser ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
              ),
            ),
            if (!isUser) ...[
              const SizedBox(height: 8),
              Row(mainAxisSize: MainAxisSize.min, children: [
                _buildBubbleButton(Icons.volume_up_rounded, 'Listen', () async {
                  await _tts.setLanguage(targetLangCode);
                  _tts.speak(textForDisplay.replaceAll('*', ''));
                }),
                // The save button checks the original message text for data
                _buildSmartSaveButton(message),
              ]),
            ]
          ],
        ),
      ),
    );
  }
  // And REPLACE the existing _buildSmartSaveButton function
  // In _ChatScreenState...

// First, ADD this NEW function right above _buildSmartSaveButton
// In lib/screens/chat_screen.dart, inside _ChatScreenState

  // In lib/screens/chat_screen.dart, inside _ChatScreenState

  FlashcardData? _extractFlashcardData(String text) {
    // 1️⃣ Hidden payload  \u200B … \u200C
    final hidden = RegExp(r'\u200B(\{.*?\})\u200C', dotAll: true).firstMatch(text);
    if (hidden != null) {
      return _parseJson(hidden.group(1)!);
    }

    // 2️⃣ Visible JSON anywhere (single or multi-line)
    final visible = RegExp(r'\{"tool":"create_flashcard".*?\}', dotAll: true)
        .firstMatch(text);
    if (visible != null) {
      return _parseJson(visible.group(0)!);
    }

    // 3️⃣ Fallback "The Spanish word for X is **Y**."
    final visSentence = RegExp(
      r'The Spanish (?:word|translation) for "?([^"]+)"? is \*\*([^*]+)\*\*',
      caseSensitive: false,
    ).firstMatch(text);

    if (visSentence != null) {
      return FlashcardData(
          front: visSentence.group(1)!.trim(),
          back: visSentence.group(2)!.trim());
    }
    return null;
  }

  // helper
  FlashcardData? _parseJson(String jsonStr) {
    try {
      final m = json.decode(jsonStr);
      if (m['tool'] == 'create_flashcard') {
        final args = m['args'];
        return FlashcardData(front: args['front'], back: args['back']);
      }
    } catch (_) {/* ignore */}
    return null;
  }



  // In _ChatScreenState, REPLACE your _buildSmartSaveButton function with this one

  // lib/screens/chat_screen.dart  inside _ChatScreenState
  Widget _buildSmartSaveButton(model.ChatMessage message) {
    // Look for hidden JSON in the raw AI response
    final flashcardData = _extractFlashcardData(message.text);

    if (flashcardData != null) {
      return _buildBubbleButton(
        Icons.library_add_rounded,
        'Save',
        () => _addToFlashcards(flashcardData.front, flashcardData.back),
      );
    }
    return const SizedBox.shrink();   // nothing if no JSON
  }

  
}