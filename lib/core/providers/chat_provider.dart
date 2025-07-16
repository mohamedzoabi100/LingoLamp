import 'package:flutter/foundation.dart';
import '../../services/cloud_chat_service.dart';
import '../providers/auth_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String text;
  final bool isUserMessage;
  final DateTime timestamp;
  final String? conversationId;
  final List<String> suggestedFlashcards;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUserMessage,
    required this.timestamp,
    this.conversationId,
    this.suggestedFlashcards = const [],
  });

  ChatMessage copyWith({
    String? id,
    String? text,
    bool? isUserMessage,
    DateTime? timestamp,
    String? conversationId,
    List<String>? suggestedFlashcards,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      isUserMessage: isUserMessage ?? this.isUserMessage,
      timestamp: timestamp ?? this.timestamp,
      conversationId: conversationId ?? this.conversationId,
      suggestedFlashcards: suggestedFlashcards ?? this.suggestedFlashcards,
    );
  }
}

class Conversation {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime lastMessageTimestamp;

  Conversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.lastMessageTimestamp,
  });

  Conversation copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? lastMessageTimestamp,
  }) {
    return Conversation(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      lastMessageTimestamp: lastMessageTimestamp ?? this.lastMessageTimestamp,
    );
  }
}

class ChatProvider extends ChangeNotifier {
  final CloudChatService _cloudChatService = CloudChatService();
  List<ChatMessage> _messages = [];
  List<Conversation> _conversations = [];
  Conversation? _currentConversation;
  bool _isLoading = false;
  bool _isResponding = false;
  String? _errorMessage;
  bool _isGuest = false;
  String _currentLanguage = 'es';
  Stream<List<Map<String, dynamic>>>? _conversationsStream;
  Stream<List<Map<String, dynamic>>>? _messagesStream;

  // Getters
  List<ChatMessage> get messages => _messages;
  List<Conversation> get conversations => _conversations;
  Conversation? get currentConversation => _currentConversation;
  bool get isLoading => _isLoading;
  bool get isResponding => _isResponding;
  String? get errorMessage => _errorMessage;

  // Context-aware init
  Future<void> init({String? languageCode, required BuildContext context}) async {
    if (languageCode != null) _currentLanguage = languageCode;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _isGuest = authProvider.isGuest;
    if (!_isGuest) {
      _listenToConversationsCloud();
    }
  }

  void _listenToConversationsCloud() {
    _conversationsStream?.drain();
    _conversationsStream = _cloudChatService.listenToConversations();
    _conversationsStream!.listen((cloudConvos) {
      _conversations = cloudConvos.map((c) => Conversation(
        id: c['id'],
        title: c['title'],
        createdAt: (c['createdAt'] as Timestamp).toDate(),
        lastMessageTimestamp: (c['lastMessageTimestamp'] as Timestamp).toDate(),
      )).toList();
      notifyListeners();
    });
  }

  void _listenToMessagesCloud(String conversationId) {
    _messagesStream?.drain();
    _messagesStream = _cloudChatService.listenToMessages(conversationId);
    _messagesStream!.listen((cloudMsgs) {
      _messages = cloudMsgs.map((m) => ChatMessage(
        id: m['id'],
        text: m['text'],
        isUserMessage: m['isUserMessage'],
        timestamp: (m['timestamp'] as Timestamp).toDate(),
        conversationId: m['conversationId'],
        suggestedFlashcards: List<String>.from(m['suggestedFlashcards'] ?? []),
      )).toList();
      notifyListeners();
    });
  }

  Future<void> loadConversations() async {
    if (_isGuest) {
      _isLoading = true;
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 300));
      _conversations = [
        Conversation(
          id: '1',
          title: 'Basic Greetings',
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
          lastMessageTimestamp: DateTime.now().subtract(const Duration(hours: 1)),
        ),
        Conversation(
          id: '2',
          title: 'Food & Dining',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          lastMessageTimestamp: DateTime.now().subtract(const Duration(minutes: 30)),
        ),
      ];
      _isLoading = false;
      notifyListeners();
    } // else: Firestore listener handles updates
  }

  Future<void> loadConversation(String conversationId) async {
    if (_isGuest) {
      _isLoading = true;
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 300));
      _currentConversation = _conversations.firstWhere(
        (conv) => conv.id == conversationId,
        orElse: () => Conversation(
          id: conversationId,
          title: 'New Conversation',
          createdAt: DateTime.now(),
          lastMessageTimestamp: DateTime.now(),
        ),
      );
      _messages = [
        ChatMessage(
          id: '1',
          text: 'Hello! How can I help you learn Spanish today?',
          isUserMessage: false,
          timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
          conversationId: conversationId,
        ),
      ];
      _isLoading = false;
      notifyListeners();
    } else {
      _currentConversation = _conversations.firstWhere(
        (c) => c.id == conversationId,
        orElse: () => Conversation(
          id: conversationId,
          title: 'New Conversation',
          createdAt: DateTime.now(),
          lastMessageTimestamp: DateTime.now(),
        ),
      );
      if (_currentConversation != null) {
        _listenToMessagesCloud(conversationId);
      }
    }
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    if (_isGuest) {
      final userMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        isUserMessage: true,
        timestamp: DateTime.now(),
        conversationId: _currentConversation?.id,
      );
      _messages.add(userMessage);
      notifyListeners();
      _isResponding = true;
      notifyListeners();
      await Future.delayed(const Duration(seconds: 2));
      final aiMessage = ChatMessage(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        text: 'This is a simulated AI response to: "$text"',
        isUserMessage: false,
        timestamp: DateTime.now(),
        conversationId: _currentConversation?.id,
        suggestedFlashcards: ['Hello', 'Goodbye'],
      );
      _messages.add(aiMessage);
      _isResponding = false;
      notifyListeners();
    } else {
      _isResponding = true;
      notifyListeners();
      await _cloudChatService.addMessage(_currentConversation!.id, {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'text': text,
        'isUserMessage': true,
        'timestamp': DateTime.now(),
        'conversationId': _currentConversation!.id,
        'suggestedFlashcards': [],
      });
      _isResponding = false;
      notifyListeners();
    }
  }

  Future<void> createNewConversation() async {
    if (_isGuest) {
      final newConversation = Conversation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'New Conversation',
        createdAt: DateTime.now(),
        lastMessageTimestamp: DateTime.now(),
      );
      _currentConversation = newConversation;
      _conversations.insert(0, newConversation);
      _messages.clear();
      notifyListeners();
    } else {
      final convoId = DateTime.now().millisecondsSinceEpoch.toString();
      await _cloudChatService.addConversation({
        'id': convoId,
        'title': 'New Conversation',
        'createdAt': DateTime.now(),
        'lastMessageTimestamp': DateTime.now(),
      });
      // Firestore listener will update state
    }
  }

  Future<void> deleteConversation(String conversationId) async {
    if (_isGuest) {
      _conversations.removeWhere((conv) => conv.id == conversationId);
      if (_currentConversation?.id == conversationId) {
        _currentConversation = null;
        _messages.clear();
      }
      notifyListeners();
    } else {
      await _cloudChatService.deleteConversation(conversationId);
      // Firestore listener will update state
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Clear all in-memory data when switching accounts
  void clear() {
    _messages.clear();
    _conversations.clear();
    _currentConversation = null;
    _isLoading = false;
    _isResponding = false;
    _errorMessage = null;
    
    // Stop listening to cloud streams
    _conversationsStream?.drain();
    _messagesStream?.drain();
    _conversationsStream = null;
    _messagesStream = null;
    
    notifyListeners();
  }

  @override
  void dispose() {
    _conversationsStream = null;
    _messagesStream = null;
    super.dispose();
  }
} 