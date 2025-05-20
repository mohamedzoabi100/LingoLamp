//lib/models/chat_message_model.dart
class ChatMessage {
  final int? id;
  final int conversationId;
  final String text;
  final bool isUserMessage;
  final DateTime timestamp;
  final String? translatedText; 

  ChatMessage({
    this.id,
    required this.conversationId,
    required this.text,
    required this.isUserMessage,
    required this.timestamp,
    this.translatedText,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'text': text,
      'is_user_message': isUserMessage ? 1 : 0,
      'timestamp': timestamp.toIso8601String(),
      'translated_text': translatedText,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as int?,
      conversationId: map['conversation_id'] as int,
      text: map['text'] as String,
      isUserMessage: (map['is_user_message'] as int) == 1,
      timestamp: DateTime.parse(map['timestamp'] as String),
      translatedText: map['translated_text'] as String?,
    );
  }
}