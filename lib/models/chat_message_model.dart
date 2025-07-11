// lib/models/chat_message_model.dart
// ** MODIFIED FILE **

class ChatMessage {
  final String id;
  final String conversationId;
  final String sender; // 'user' or 'ai'
  final String text;
  final DateTime timestamp;
  final bool isFavorite;
  final bool isFlashcard;
  final Map<String, dynamic>? extra;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.isFavorite = false,
    this.isFlashcard = false,
    this.extra,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
    id: map['id'],
    conversationId: map['conversationId'],
    sender: map['sender'],
    text: map['text'],
    timestamp: DateTime.parse(map['timestamp']),
    isFavorite: map['isFavorite'] ?? false,
    isFlashcard: map['isFlashcard'] ?? false,
    extra: map['extra'],
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'conversationId': conversationId,
    'sender': sender,
    'text': text,
    'timestamp': timestamp.toIso8601String(),
    'isFavorite': isFavorite,
    'isFlashcard': isFlashcard,
    'extra': extra,
  };
}