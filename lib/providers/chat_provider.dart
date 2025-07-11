import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_message_model.dart';
import '../models/conversation_model.dart';
import '../services/ai_chat_service.dart';

class ChatProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AiChatService _aiService = AiChatService();

  // State
  List<Conversation> _conversations = [];
  List<ChatMessage> _currentMessages = [];
  Conversation? _currentConversation;
  bool _isLoading = false;
  bool _isSending = false;
  String? _error;
  bool _hasMoreMessages = true;
  bool _isLoadingMore = false;

  // Getters
  List<Conversation> get conversations => _conversations;
  List<ChatMessage> get currentMessages => _currentMessages;
  Conversation? get currentConversation => _currentConversation;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get error => _error;
  bool get hasMoreMessages => _hasMoreMessages;
  bool get isLoadingMore => _isLoadingMore;

  // Initialize provider
  Future<void> initialize() async {
    if (_auth.currentUser == null) return;
    
    _setLoading(true);
    try {
      await _loadConversations();
      _clearError();
    } catch (e) {
      _setError('Failed to load conversations: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Load conversations
  Future<void> _loadConversations() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('conversations')
        .where('isDeleted', isEqualTo: false)
        .orderBy('updatedAt', descending: true)
        .get();

    _conversations = snapshot.docs
        .map((doc) {
          final data = doc.data();
          return Conversation.fromMap({...data, 'id': doc.id});
        })
        .toList();
    
    notifyListeners();
  }

  // Create new conversation
  Future<Conversation> createConversation({String? initialTitle}) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    final conversation = Conversation(
      id: '', // Will be set by Firestore
      title: initialTitle ?? 'New Conversation',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final docRef = await _firestore
        .collection('users')
        .doc(userId)
        .collection('conversations')
        .add(conversation.toMap());

    final newConversation = Conversation(
      id: docRef.id,
      title: conversation.title,
      createdAt: conversation.createdAt,
      updatedAt: conversation.updatedAt,
    );

    _conversations.insert(0, newConversation);
    notifyListeners();

    return newConversation;
  }

  // Load conversation messages
  Future<void> loadConversation(String conversationId) async {
    if (_currentConversation?.id == conversationId) return;

    _setLoading(true);
    try {
      final conversation = _conversations.firstWhere((c) => c.id == conversationId);
      _currentConversation = conversation;
      _currentMessages = [];
      _hasMoreMessages = true;

      await _loadMessages(conversationId);
      _clearError();
    } catch (e) {
      _setError('Failed to load conversation: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Load messages for a conversation
  Future<void> _loadMessages(String conversationId, {int limit = 50}) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    final messages = snapshot.docs
        .map((doc) {
          final data = doc.data();
          return ChatMessage.fromMap({...data, 'id': doc.id});
        })
        .toList();

    // Reverse to show oldest first
    messages.reversed.toList();
    
    _currentMessages = messages;
    _hasMoreMessages = messages.length >= limit;
    notifyListeners();
  }

  // Load more messages (pagination)
  Future<void> loadMoreMessages() async {
    if (!_hasMoreMessages || _isLoadingMore || _currentConversation == null) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final lastMessage = _currentMessages.isNotEmpty ? _currentMessages.first : null;
      
      Query query = _firestore
          .collection('users')
          .doc(userId)
          .collection('conversations')
          .doc(_currentConversation!.id)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(20);

      if (lastMessage != null) {
        query = query.startAfter([lastMessage.timestamp]);
      }

      final snapshot = await query.get();
      final newMessages = snapshot.docs
          .map((doc) {
            final data = doc.data();
            if (data == null) return null;
            final mapData = data as Map<String, dynamic>;
            return ChatMessage.fromMap({...mapData, 'id': doc.id});
          })
          .where((message) => message != null)
          .cast<ChatMessage>()
          .toList();

      if (newMessages.isNotEmpty) {
        _currentMessages.insertAll(0, newMessages.reversed);
        _hasMoreMessages = newMessages.length >= 20;
      } else {
        _hasMoreMessages = false;
      }

      notifyListeners();
    } catch (e) {
      _setError('Failed to load more messages: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  // Send message
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || _isSending) return;

    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _setSending(true);
    _clearError();

    try {
      // Create conversation if none exists
      if (_currentConversation == null) {
        _currentConversation = await createConversation();
      }

      // Add user message
      final userMessage = await _addMessage(
        conversationId: _currentConversation!.id,
        text: text.trim(),
      );

      // Get AI response
      final aiResponse = await _aiService.sendMessage(text.trim());
      
      // Add AI message
      final aiMessage = await _addMessage(
        conversationId: _currentConversation!.id,
        text: aiResponse,
      );

      // Update conversation title if it's the first exchange
      if (_currentMessages.length <= 2) {
        await _updateConversationTitle(_currentConversation!.id, text.trim());
      }

      // Update conversation timestamp
      await _updateConversationTimestamp(_currentConversation!.id);

    } catch (e) {
      _setError('Failed to send message: $e');
    } finally {
      _setSending(false);
    }
  }

  // Add message to Firestore
  Future<ChatMessage> _addMessage({
    required String conversationId,
    required String text,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    final message = ChatMessage(
      id: '',
      conversationId: conversationId,
      isUserMessage: true,
      text: text,
      timestamp: DateTime.now(),
    );

    final docRef = await _firestore
        .collection('users')
        .doc(userId)
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .add(message.toMap());

    final newMessage = ChatMessage(
      id: docRef.id,
      conversationId: conversationId,
      isUserMessage: true,
      text: text,
      timestamp: message.timestamp,
    );

    _currentMessages.add(newMessage);
    notifyListeners();

    return newMessage;
  }

  // Update conversation title
  Future<void> _updateConversationTitle(String conversationId, String title) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final newTitle = title.length > 30 ? '${title.substring(0, 30)}...' : title;
    
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('conversations')
        .doc(conversationId)
        .update({'title': newTitle});

    // Update local state
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      _conversations[index] = Conversation(
        id: _conversations[index].id,
        title: newTitle,
        createdAt: _conversations[index].createdAt,
        updatedAt: DateTime.now(),
      );
      
      if (_currentConversation?.id == conversationId) {
        _currentConversation = _conversations[index];
      }
      
      notifyListeners();
    }
  }

  // Update conversation timestamp
  Future<void> _updateConversationTimestamp(String conversationId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('conversations')
        .doc(conversationId)
        .update({'updatedAt': DateTime.now().toIso8601String()});

    // Update local state
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      _conversations[index] = Conversation(
        id: _conversations[index].id,
        title: _conversations[index].title,
        createdAt: _conversations[index].createdAt,
        updatedAt: DateTime.now(),
      );
      
      // Move to top
      final conversation = _conversations.removeAt(index);
      _conversations.insert(0, conversation);
      
      notifyListeners();
    }
  }

  // Rename conversation
  Future<void> renameConversation(String conversationId, String newTitle) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('conversations')
        .doc(conversationId)
        .update({'title': newTitle});

    // Update local state
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      _conversations[index] = Conversation(
        id: _conversations[index].id,
        title: newTitle,
        createdAt: _conversations[index].createdAt,
        updatedAt: DateTime.now(),
      );
      
      if (_currentConversation?.id == conversationId) {
        _currentConversation = _conversations[index];
      }
      
      notifyListeners();
    }
  }

  // Delete conversation
  Future<void> deleteConversation(String conversationId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('conversations')
        .doc(conversationId)
        .update({'isDeleted': true});

    // Remove from local state
    _conversations.removeWhere((c) => c.id == conversationId);
    
    if (_currentConversation?.id == conversationId) {
      _currentConversation = null;
      _currentMessages = [];
    }
    
    notifyListeners();
  }

  // Clear current conversation
  void clearCurrentConversation() {
    _currentConversation = null;
    _currentMessages = [];
    notifyListeners();
  }

  // State setters
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setSending(bool sending) {
    _isSending = sending;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  // Clear all data (for sign out)
  void clearAllData() {
    _conversations = [];
    _currentMessages = [];
    _currentConversation = null;
    _isLoading = false;
    _isSending = false;
    _error = null;
    _hasMoreMessages = true;
    _isLoadingMore = false;
    notifyListeners();
  }
} 