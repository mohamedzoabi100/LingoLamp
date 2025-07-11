// lib/models/chat_message_model.dart
// ** MODIFIED FILE **

class ChatMessage {
  final String id;
  final String conversationId;
  final String text;
  final bool isUserMessage;
  final DateTime timestamp;
  final String? originalQuery;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.text,
    required this.isUserMessage,
    required this.timestamp,
    this.originalQuery,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'text': text,
      'is_user_message': isUserMessage ? 1 : 0,
      'timestamp': timestamp.toIso8601String(),
      'original_query': originalQuery,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      text: map['text'] as String,
      isUserMessage: (map['is_user_message'] as int) == 1,
      timestamp: DateTime.parse(map['timestamp'] as String),
      originalQuery: map['original_query'] as String?,
    );
  }
}