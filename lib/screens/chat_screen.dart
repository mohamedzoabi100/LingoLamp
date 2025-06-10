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
import 'chat_history_screen.dart';

const targetLangCode = 'es-ES';

class ChatScreen extends StatefulWidget {
  final int? conversationId;
  const ChatScreen({super.key, this.conversationId});

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

  @override
  void initState() {
    super.initState();
    _currentConversationId = widget.conversationId;
    _initTts();

    if (_currentConversationId != null) {
      _loadConversationAndMessages(_currentConversationId!);
    } else {
      _messages.add(model.ChatMessage(
        conversationId: -1,
        text: "¡Hola! I'm Lingo, your personal Spanish tutor. How can I help you practice today?",
        isUserMessage: false,
        timestamp: DateTime.now(),
      ));
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _tts.stop();
    super.dispose();
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
      if (mounted) Navigator.pop(context);
      return;
    }
    final dbMessages = await _dbHelper.getMessagesForConversation(conversationId);
    final history = <gen_ai.Content>[];
    for (var msg in dbMessages) {
      history.add(msg.isUserMessage
          ? gen_ai.Content.text(msg.text)
          : gen_ai.Content.model([gen_ai.TextPart(msg.text)]));
    }
    _aiChatService.startChat(history: history);
    setState(() {
      _messages.clear();
      _messages.addAll(dbMessages);
    });
    _scrollToBottom(milliseconds: 100);
  }
  
  Future<void> _ensureConversationExists() async {
    if (_currentConversationId == null && _messages.isNotEmpty) {
      final now = DateTime.now();
      final firstUserMessage = _messages.firstWhere((m) => m.isUserMessage, orElse: () => _messages.first).text;
      final convoTitle = firstUserMessage.substring(0, firstUserMessage.length > 30 ? 30 : firstUserMessage.length);
      Conversation newConvo = Conversation(title: convoTitle, createdAt: now, lastMessageTimestamp: now);
      _currentConversationId = await _dbHelper.insertConversation(newConvo);
      _currentConversation = await _dbHelper.getConversation(_currentConversationId!);
      for (int i = 0; i < _messages.length; i++) {
        if (_messages[i].conversationId == -1) {
          final oldMsg = _messages[i];
          final newMsg = model.ChatMessage(id: oldMsg.id, conversationId: _currentConversationId!, text: oldMsg.text, isUserMessage: oldMsg.isUserMessage, timestamp: oldMsg.timestamp, originalQuery: oldMsg.originalQuery);
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

    final userMessage = model.ChatMessage(
      conversationId: _currentConversationId ?? -1,
      text: text,
      isUserMessage: true,
      timestamp: DateTime.now(),
    );
    setState(() { _messages.add(userMessage); _isResponding = true; });
    _scrollToBottom();
    
    // The new, correct code for _handleSubmittedText
    await _ensureConversationExists();

    // After ensuring the conversation exists, we now have a valid _currentConversationId.
    // We create a new ChatMessage object here with the correct ID to save to the database.
    final messageToSave = model.ChatMessage(
        conversationId: _currentConversationId!,
        text: userMessage.text,
        isUserMessage: userMessage.isUserMessage,
        timestamp: userMessage.timestamp);
        
    await _dbHelper.insertMessage(messageToSave);
    
    // Get the raw response from the AI
    final aiResponseText = await _aiChatService.sendMessage(text);
    debugPrint("AI RAW RESPONSE: '$aiResponseText'");
    
    // Create the ChatMessage that will be stored in the database and displayed
    final aiMessage = model.ChatMessage(
      conversationId: _currentConversationId!,
      text: aiResponseText, // Store the FULL, raw response
      isUserMessage: false,
      timestamp: DateTime.now(),
      originalQuery: text, // Store the user's query that prompted this response
    );
    
    // Save the full message to the database
    await _dbHelper.insertMessage(aiMessage);
    
    // Add the exact same message to the UI list and trigger a rebuild
    setState(() {
      _messages.add(aiMessage);
      _isResponding = false;
    });
    _scrollToBottom();
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
    );
    await _dbHelper.insertFlashcard(flashcard);
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
      appBar: AppBar(title: Text(appBarTitle, overflow: TextOverflow.ellipsis), backgroundColor: primaryColor, foregroundColor: Colors.white, actions: [
        IconButton(
          icon: const Icon(Icons.history),
          tooltip: 'Chat History',
          onPressed: () async {
            final selectedId = await Navigator.push<int?>(context, MaterialPageRoute(builder: (context) => const ChatHistoryScreen()));
            if (selectedId != null && selectedId != _currentConversationId) {
              _currentConversationId = selectedId;
              _loadConversationAndMessages(selectedId);
            }
          },
        ),
      ]),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(children: [
        Expanded(child: ListView.builder(controller: _scrollController, padding: const EdgeInsets.all(16), itemCount: _messages.length, itemBuilder: (_, index) => _buildChatBubble(_messages[index]))),
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
            onSubmitted: (_) => _handleSubmittedText(),
            textInputAction: TextInputAction.send,
            decoration: InputDecoration(
              hintText: 'Ask Lingo anything...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(25.0), borderSide: BorderSide.none),
              filled: true,
              fillColor: Colors.grey[100],
              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            ),
            enabled: !_isResponding,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(onPressed: _isResponding ? null : _handleSubmittedText, icon: Icon(Icons.send_rounded, color: primaryColor), tooltip: 'Send'),
      ])),
    );
  }

  // In lib/screens/chat_screen.dart, inside _ChatScreenState

 // In lib/screens/chat_screen.dart, inside _ChatScreenState
// REPLACE your _buildChatBubble function with this:

  Widget _buildChatBubble(model.ChatMessage message) {
    final bool isUser = message.isUserMessage;
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

    // 3️⃣ Fallback “The Spanish word for X is **Y**.”
    final visSentence = RegExp(
      r'The Spanish (?:word|translation) for .*?["“]?([^"”]+?)["”]? .*?\*\*(.+?)\*\*',
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