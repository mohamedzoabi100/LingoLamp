import 'package:flutter/foundation.dart';

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
  List<ChatMessage> _messages = [];
  List<Conversation> _conversations = [];
  Conversation? _currentConversation;
  bool _isLoading = false;
  bool _isResponding = false;
  String? _errorMessage;

  // Getters
  List<ChatMessage> get messages => _messages;
  List<Conversation> get conversations => _conversations;
  Conversation? get currentConversation => _currentConversation;
  bool get isLoading => _isLoading;
  bool get isResponding => _isResponding;
  String? get errorMessage => _errorMessage;

  Future<void> loadConversations() async {
    try {
      _isLoading = true;
      notifyListeners();

      // TODO: Load conversations from database
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

      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load conversations: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadConversation(String conversationId) async {
    try {
      _isLoading = true;
      notifyListeners();

      // TODO: Load conversation and messages from database
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

      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load conversation: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    try {
      // Add user message
      final userMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        isUserMessage: true,
        timestamp: DateTime.now(),
        conversationId: _currentConversation?.id,
      );

      _messages.add(userMessage);
      notifyListeners();

      // Simulate AI response
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

    } catch (e) {
      _errorMessage = 'Failed to send message: $e';
      _isResponding = false;
      notifyListeners();
    }
  }

  Future<void> createNewConversation() async {
    try {
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

    } catch (e) {
      _errorMessage = 'Failed to create conversation: $e';
      notifyListeners();
    }
  }

  Future<void> deleteConversation(String conversationId) async {
    try {
      _conversations.removeWhere((conv) => conv.id == conversationId);
      if (_currentConversation?.id == conversationId) {
        _currentConversation = null;
        _messages.clear();
      }
      // TODO: Delete from database if needed
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to delete conversation: $e';
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
} 