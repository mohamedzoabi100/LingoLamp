// lib/screens/chat_screen.dart
// ** HEAVILY MODIFIED / REWRITTEN **

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as gen_ai;
import 'package:flutter_markdown/flutter_markdown.dart';

import '../services/ai_chat_service.dart';
import '../utils/database_helper.dart';
import '../models/chat_message_model.dart' as model;
import '../models/conversation_model.dart';
import '../models/flashcard_model.dart';
import 'chat_history_screen.dart';

// Constants for TTS
const sourceLangCode = 'en-US';
const targetLangCode = 'es-ES';

class ChatScreen extends StatefulWidget {
  final int? conversationId;

  const ChatScreen({super.key, this.conversationId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
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
      // Start with a greeting from the AI for a new chat
      _messages.add(
        model.ChatMessage(
          conversationId: -1, // Temporary ID
          text: "¡Hola! I'm Lingo, your personal Spanish tutor. How can I help you practice today? You can ask for translations, check grammar, or just chat!",
          isUserMessage: false,
          timestamp: DateTime.now(),
        ),
      );
    }
  }
  
  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<void> _initTts() async {
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  Future<void> _loadConversationAndMessages(int conversationId) async {
    _currentConversation = await _dbHelper.getConversation(conversationId);
    if (_currentConversation == null) {
      if (mounted) Navigator.pop(context); // Invalid conversation, go back
      return;
    }

    final dbMessages = await _dbHelper.getMessagesForConversation(conversationId);
    setState(() {
      _messages.clear();
      _messages.addAll(dbMessages);
    });

    // Rebuild the AI's conversation history from the database
    final history = <gen_ai.Content>[];
    for (var msg in _messages) {
      history.add(
        msg.isUserMessage ? gen_ai.Content.text(msg.text) : gen_ai.Content.model([gen_ai.TextPart(msg.text)])
      );
    }
    _aiChatService.startChat(history: history);

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

      // Update messages with the new conversation ID
      for (int i = 0; i < _messages.length; i++) {
        if (_messages[i].conversationId == -1) {
          final oldMsg = _messages[i];
          final newMsg = model.ChatMessage(
            id: oldMsg.id,
            conversationId: _currentConversationId!,
            text: oldMsg.text,
            isUserMessage: oldMsg.isUserMessage,
            timestamp: oldMsg.timestamp,
            originalQuery: oldMsg.originalQuery,
          );
          _messages[i] = newMsg;
          await _dbHelper.insertMessage(newMsg);
        }
      }
    }
  }

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

    setState(() {
      _messages.add(userMessage);
      _isResponding = true;
    });
    _scrollToBottom();

    await _ensureConversationExists();
    
    // Create a new message object with the correct conversation ID to save
    final messageToSave = model.ChatMessage(
      conversationId: _currentConversationId!,
      text: userMessage.text,
      isUserMessage: userMessage.isUserMessage,
      timestamp: userMessage.timestamp,
    );
    await _dbHelper.insertMessage(messageToSave);

    final aiResponseText = await _aiChatService.sendMessage(text);

    final aiMessage = model.ChatMessage(
      conversationId: _currentConversationId!,
      text: aiResponseText,
      isUserMessage: false,
      timestamp: DateTime.now(),
      originalQuery: text, // Store the user's query
    );

    await _dbHelper.insertMessage(aiMessage);
    setState(() {
      _messages.add(aiMessage);
      _isResponding = false;
    });
    _scrollToBottom();
  }

  Future<void> _addToFlashcards(String originalText, String translatedText) async {
    try {
      if (await _dbHelper.flashcardExists(originalText, translatedText)) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This flashcard already exists!'), backgroundColor: Colors.orange));
        return;
      }
      final flashcard = Flashcard(
        originalText: originalText,
        translatedText: translatedText,
        sourceLanguage: sourceLangCode,
        targetLanguage: targetLangCode,
        createdAt: DateTime.now(),
        lastStudied: DateTime.now(),
      );
      await _dbHelper.insertFlashcard(flashcard);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to flashcards! 📚'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding to flashcards: $e'), backgroundColor: Colors.red));
    }
  }

  void _scrollToBottom({int milliseconds = 300}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: milliseconds),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    String appBarTitle = _currentConversation?.title ?? 'AI Language Tutor';

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle, overflow: TextOverflow.ellipsis),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Chat History',
            onPressed: () async {
              final selectedId = await Navigator.push<int?>(
                context,
                MaterialPageRoute(builder: (context) => const ChatHistoryScreen()),
              );
              if (selectedId != null && selectedId != _currentConversationId) {
                _currentConversationId = selectedId;
                _loadConversationAndMessages(selectedId);
              }
            },
          ),
        ],
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (_, index) {
                return _buildChatBubble(_messages[index]);
              },
            ),
          ),
          if (_isResponding)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              child: Row(
                children: [
                  SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor)),
                  const SizedBox(width: 12),
                  Text("Lingo is typing...", style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          _buildInputRow(primaryColor),
        ],
      ),
    );
  }

  Widget _buildInputRow(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), spreadRadius: 1, blurRadius: 8, offset: const Offset(0, -3))],
      ),
      child: SafeArea(
        child: Row(
          children: [
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
            IconButton(
              onPressed: _isResponding ? null : _handleSubmittedText,
              icon: Icon(Icons.send_rounded, color: primaryColor),
              tooltip: 'Send',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBubble(model.ChatMessage message) {
  final bool isUser = message.isUserMessage;
  final primaryColor = Theme.of(context).colorScheme.primary;

  // Define the text style for the markdown renderer
  final MarkdownStyleSheet styleSheet = MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
    p: Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: isUser ? Colors.white : Theme.of(context).colorScheme.onSurface,
      fontSize: 15, // Match your desired text size
    ),
    strong: Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: isUser ? Colors.white : Theme.of(context).colorScheme.onSurface,
      fontWeight: FontWeight.bold,
      fontSize: 15,
    ),
  );

  return Align(
    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isUser ? primaryColor : Colors.grey.shade200,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: isUser ? const Radius.circular(18) : const Radius.circular(4),
          bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(18),
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 3, offset: const Offset(0, 1))],
      ),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // MODIFICATION: Replaced Text with MarkdownBody for rich text rendering
          MarkdownBody(
            data: message.text,
            selectable: true,
            styleSheet: styleSheet,
            softLineBreak: true,
          ),
          if (!isUser) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildBubbleButton(Icons.volume_up_rounded, 'Listen', () async {
                  await _tts.setLanguage(targetLangCode);
                  _tts.speak(message.text.replaceAll('*', '')); // Remove asterisks for cleaner speech
                }),
                if (message.originalQuery != null)
                  _buildBubbleButton(Icons.library_add_rounded, 'Save', () {
                    _addToFlashcards(
                      message.originalQuery!,
                      // Clean the response of markdown for saving
                      message.text.replaceAll(RegExp(r'(\*\*|__|[*_])'), '')
                    );
                  }),
              ],
            )
          ],
        ],
      ),
    ),
  );
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
          children: [
            Icon(icon, size: 16, color: primaryColor),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, color: primaryColor, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}