// lib/screens/chat_screen.dart
// ** UPDATED to work with new String-based database and Spanish-only **

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as gen_ai;
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';

import '../services/ai_chat_service.dart';
import '../services/xp_service.dart';
import '../services/cloud_tts_service.dart';
import '../utils/database_helper.dart';
import '../models/chat_message_model.dart' as model;
import '../models/conversation_model.dart';
import '../models/flashcard_model.dart';
import '../models/recommended_flashcard_model.dart';
import 'chat_history_screen.dart';
import '../services/user_data_service.dart';
import '../services/recommendation_service.dart';
import '../core/providers/language_provider.dart';

class ChatScreen extends StatefulWidget {
  final VoidCallback? onBackToHome;
  final String? conversationId;
  // REMOVED: languageCode parameter since we're Spanish-only

  const ChatScreen({
    Key? key,
    this.conversationId,
    this.onBackToHome,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class FlashcardData {
  final String front;
  final String back;
  FlashcardData({required this.front, required this.back});
}

class _ChatScreenState extends State<ChatScreen> {
  // --- State Variables ---
  final _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final XPService _xpService = XPService();
  final CloudTtsService _cloudTts = CloudTtsService();
  late AiChatService _aiChatService;
  final RecommendationService _recommendationService = RecommendationService();

  final List<model.ChatMessage> _messages = [];
  String? _currentConversationId;
  Conversation? _currentConversation;
  bool _isResponding = false;
  bool _isInitialized = false;

  // --- Spanish-only configuration ---
  static const String _languageCode = 'es';
  static const String _languageTtsCode = 'es-ES';

  String _getLanguageGreeting(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final languageCode = languageProvider.currentLanguage;
    final greetings = {
      'es': '¡Hola! I\'m Lingo, your personal Spanish tutor. How can I help you practice today?',
      'fr': 'Bonjour ! I\'m Lingo, your personal French tutor. How can I help you practice today?',
      'de': 'Hallo! I\'m Lingo, your personal German tutor. How can I help you practice today?',
      'it': 'Ciao! I\'m Lingo, your personal Italian tutor. How can I help you practice today?',
      'pt': 'Olá! I\'m Lingo, your personal Portuguese tutor. How can I help you practice today?',
    };
    return greetings[languageCode] ?? greetings['es']!;
  }

  @override
  void initState() {
    super.initState();
    _currentConversationId = widget.conversationId;
    // Initialization is now deferred to didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _initialize();
      _isInitialized = true;
    }
  }

  Future<void> _initialize() async {
    if (_currentConversationId != null) {
      // Loading an existing conversation
      await _loadConversationAndMessages(_currentConversationId!);
    } else {
      // Creating a new conversation
      _aiChatService = AiChatService();
      _messages.add(model.ChatMessage(
        id: const Uuid().v4(),
        conversationId: '', // Will be set when conversation is created
        text: _getLanguageGreeting(context),
        isUserMessage: false,
        timestamp: DateTime.now(),
      ));
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _speakText(String text, String language) async {
    try {
      // Map language codes to Google Cloud TTS codes
      final ttsLanguageCode = _getTtsLanguageCode(language);
      final voiceName = _getVoiceName(language);
      
      await _cloudTts.speak(
        text: text,
        languageCode: ttsLanguageCode,
        voiceName: voiceName,
        speakingRate: 0.9,
      );
    } catch (e) {
      print('[Chat] ERROR: Failed to speak text: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to play audio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

  Future<void> _loadConversationAndMessages(String conversationId) async {
    _currentConversation = await _dbHelper.getConversation(conversationId);
    if (_currentConversation == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    // Initialize AI service with fresh session and updated system prompt
    _aiChatService = AiChatService();
    
    // Always start with fresh session to ensure latest system prompt is used
    _aiChatService.startChat();
    
    // Ensure the system prompt is sent to establish the AI's behavior
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    await _aiChatService.ensureSystemPrompt(languageProvider.currentLanguage);

    final dbMessages = await _dbHelper.getMessagesForConversation(conversationId);
    setState(() {
      _messages.clear();
      _messages.addAll(dbMessages);
    });
    _scrollToBottom(milliseconds: 100);
  }
  
  Future<void> _ensureConversationExists() async {
    if (_currentConversationId == null && _messages.isNotEmpty) {
      final now = DateTime.now();
      final firstUserMessage = _messages
          .firstWhere((m) => m.isUserMessage, orElse: () => _messages.first)
          .text;
      final convoTitle = firstUserMessage.substring(
          0, firstUserMessage.length > 30 ? 30 : firstUserMessage.length);

      // Get the current language from the provider
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

      // Create conversation with correct languageCode
      Conversation newConvo = Conversation(
        id: const Uuid().v4(),
        title: convoTitle,
        createdAt: now,
        updatedAt: now,
        languageCode: languageProvider.currentLanguage,
      );

      _currentConversationId = await _dbHelper.insertConversation(newConvo);
      _currentConversation = await _dbHelper.getConversation(_currentConversationId!);

      // Update messages with the new conversation ID
      for (int i = 0; i < _messages.length; i++) {
        if (_messages[i].conversationId.isEmpty) {
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
      id: const Uuid().v4(),
      conversationId: _currentConversationId ?? '',
      text: text,
      isUserMessage: true,
      timestamp: DateTime.now(),
    );
    setState(() { 
      _messages.add(userMessage);
      _isResponding = true; 
    });
    _scrollToBottom();
    
    final bool creatingNewConversation = (_currentConversationId == null);
    await _ensureConversationExists();

    if (!creatingNewConversation) {
    final messageToSave = model.ChatMessage(
        id: userMessage.id,
        conversationId: _currentConversationId!,
        text: userMessage.text,
        isUserMessage: userMessage.isUserMessage,
        timestamp: userMessage.timestamp,
      );
    await _dbHelper.insertMessage(messageToSave);
    }
      
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final aiResponseText = await _aiChatService.sendMessage(
      text,
      languageCode: languageProvider.currentLanguage,
    );
    
    // Award XP for sending a chat message
    await _xpService.awardChatMessage();
    
    final aiMessage = model.ChatMessage(
      id: const Uuid().v4(),
      conversationId: _currentConversationId!,
        text: aiResponseText,
      isUserMessage: false,
      timestamp: DateTime.now(),
      originalQuery: text,
    );
    
    await _dbHelper.insertMessage(aiMessage);

    setState(() {
      _messages.add(aiMessage);
      _isResponding = false;
    });
    _scrollToBottom();
  }

  // --- Build Methods ---
  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final primaryColor = Theme.of(context).colorScheme.primary;
    String appBarTitle = _currentConversation?.title ?? 'New Chat';

    return Scaffold(
      appBar: AppBar( 
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(appBarTitle, overflow: TextOverflow.ellipsis),
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
              final selectedId = await Navigator.push<String?>(context, MaterialPageRoute(builder: (context) => const ChatHistoryScreen()));
            if (selectedId != null && selectedId != _currentConversationId) {
              _currentConversationId = selectedId;
              _loadConversationAndMessages(selectedId);
            }
          },
        ),
          // PopupMenuButton removed
        ],
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(children: [
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (_, index) => _buildChatBubble(_messages[index]))),
        if (_isResponding)
          Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Row(children: [
              SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: primaryColor)),
              const SizedBox(width: 12),
              Text("Lingo is typing...",
                  style: TextStyle(
                      color: Colors.grey[600], fontStyle: FontStyle.italic)),
            ]),
          ),
        _buildInputRow(primaryColor),
      ]),
    );
  }

  Widget _buildChatBubble(model.ChatMessage message) {
    final bool isUser = message.isUserMessage;
    final primaryColor = Theme.of(context).colorScheme.primary;

    String textForDisplay;
    FlashcardData? flashcardData;
    if (!isUser) {
      flashcardData = _extractFlashcardData(message.text);
      if (flashcardData != null) {
        textForDisplay =
            "The translation for \"${flashcardData.front}\" is *${flashcardData.back}*.";
        // Add to recommendations if not already a flashcard
        _maybeRecommendFlashcard(flashcardData, message);
      } else {
        textForDisplay = message.text;
      }
    } else {
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
                p: TextStyle(
                    fontSize: 16.0,
                    color: isUser ? Colors.white : Colors.black87),
                strong: TextStyle(
                    fontSize: 16.0,
                    color: isUser ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold),
              ),
            ),
            if (!isUser) ...[
              const SizedBox(height: 8),
              Row(mainAxisSize: MainAxisSize.min, children: [
                _buildBubbleButton(Icons.volume_up_rounded, 'Listen', () async {
                  await _speakText(textForDisplay.replaceAll('*', ''), _languageTtsCode);
                }),
                _buildSmartSaveButton(message),
              ]),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildInputRow(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.08),
                spreadRadius: 1,
                blurRadius: 8,
                offset: const Offset(0, -3))
          ]),
      child: SafeArea(
          child: Row(children: [
        Expanded(
          child: TextField(
            controller: _inputController,
            onSubmitted: (_) => _handleSubmittedText(),
            textInputAction: TextInputAction.send,
            decoration: InputDecoration(
              hintText: 'Ask Lingo anything...',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide.none),
              filled: true,
              fillColor: Colors.grey[100],
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            ),
            enabled: !_isResponding,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
            onPressed: _isResponding ? null : _handleSubmittedText,
            icon: Icon(Icons.send_rounded, color: primaryColor),
            tooltip: 'Send'),
      ])),
    );
  }

  Widget _buildBubbleButton(
      IconData icon, String label, VoidCallback onPressed) {
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
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: primaryColor,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  FlashcardData? _extractFlashcardData(String text) {
  print('🔍 [CHAT] _extractFlashcardData called with text: "${text.substring(0, text.length > 100 ? 100 : text.length)}..."');
  // 1. Hidden payload
  final hidden = RegExp(r'\u200B(\{.*?\})\u200C', dotAll: true).firstMatch(text);
  if (hidden != null) {
    print('✅ [CHAT] Found hidden payload: ${hidden.group(1)}');
    return _parseJson(hidden.group(1)!);
  }
  // 2. Visible JSON
  final visible = RegExp(r'\{"tool":"create_flashcard".*?\}', dotAll: true).firstMatch(text);
  if (visible != null) {
    print('✅ [CHAT] Found visible JSON: ${visible.group(0)}');
    return _parseJson(visible.group(0)!);
  }
  // 3. Fallback Regex - Updated to match AI's actual format
  final visSentence = RegExp(
    'The translation of ["\']?([^"\']+)["\']? in Spanish is ([^.]+)\\.',
    caseSensitive: false,
  ).firstMatch(text);
  if (visSentence != null) {
    print('✅ [CHAT] Found fallback regex match: "${visSentence.group(1)}" -> "${visSentence.group(2)}"');
    return FlashcardData(
      front: visSentence.group(1)!.trim(),
      back: visSentence.group(2)!.trim(),
    );
  }
  print('❌ [CHAT] No flashcard data found in text');
  return null;
}

  // BUG FIX: This method now correctly parses the JSON from the AI.
  FlashcardData? _parseJson(String jsonStr) {
    try {
      print('🔍 [CHAT] _parseJson called with: $jsonStr');
      final m = json.decode(jsonStr);
      if (m['tool'] == 'create_flashcard') {
        final args = m['args'];
        print('✅ [CHAT] Parsed flashcard data: front="${args['front']}", back="${args['back']}"');
        // The key from the AI is always 'back', regardless of language.
        return FlashcardData(front: args['front'], back: args['back']);
      }
    } catch (e) {
      print('❌ [CHAT] JSON parsing error: $e');
    }
    return null;
  }

  Widget _buildSmartSaveButton(model.ChatMessage message) {
    final flashcardData = _extractFlashcardData(message.text);
    if (flashcardData != null) {
      return _buildBubbleButton(
        Icons.library_add_rounded,
        'Save',
        () => _addToFlashcards(flashcardData.front, flashcardData.back),
      );
    }
    return const SizedBox.shrink();
  }

  void _maybeRecommendFlashcard(FlashcardData data, model.ChatMessage message) async {
    // Only add if not already a flashcard
    if (await _dbHelper.flashcardExists(data.front, data.back)) return;
    // Get current language from provider
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final currentLanguage = languageProvider.currentLanguage;
    // Only add if not already in recommendations for this language
    final recs = await _recommendationService.getRecommendations(languageCode: currentLanguage);
    if (recs.any((r) => r.term == data.front)) return;
    // Add to recommendations (context = translation)
    await _recommendationService.addRecommendation(term: data.front, context: data.back, languageCode: currentLanguage);
  }

  Future<void> _addToFlashcards(
      String originalText, String translatedText) async {
    print('🔍 [CHAT] Starting _addToFlashcards with: "$originalText" -> "$translatedText"');
    
    if (await _dbHelper.flashcardExists(originalText, translatedText)) {
      print('⚠️ [CHAT] Flashcard already exists, skipping');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('This flashcard already exists!'),
            backgroundColor: Colors.orange));
      }
      return;
    }
    
    // Get current language from provider
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final currentLanguage = languageProvider.currentLanguage;
    
    final flashcard = Flashcard(
      // id is auto-incremented by DB
      originalText: originalText,
      translatedText: translatedText,
      sourceLanguage: 'en', // Assuming source is always English for now
      targetLanguage: currentLanguage,
      languageCode: currentLanguage, // Set the language code explicitly
      createdAt: DateTime.now(),
      lastStudied: DateTime.now(),
      timesStudied: 0,
      difficulty: 2,
      isFavorite: false,
      category: 'Chat Generated',
      tags: ['chat', 'ai-generated'],
    );
    
    print('💾 [CHAT] Inserting flashcard: ${flashcard.toMap()}');
    final insertedId = await _dbHelper.insertFlashcard(flashcard);
    print('✅ [CHAT] Flashcard inserted with ID: $insertedId');
    
    // Remove from recommendations if present
    final recs = await _recommendationService.getRecommendations(languageCode: currentLanguage);
    RecommendedFlashcard? rec;
    for (final r in recs) {
      if (r.term == originalText) {
        rec = r;
        break;
      }
    }
    if (rec != null && rec.id != null) {
      await _recommendationService.removeRecommendation(rec.id!);
    }
    // Award XP for creating a flashcard from chat
    await _xpService.awardFlashcardCreated();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Added to flashcards! 📚 +10 XP'),
          backgroundColor: Colors.green));
    }
  }

  void _scrollToBottom({int milliseconds = 300}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: milliseconds),
            curve: Curves.easeOut);
      }
    });
  }
}