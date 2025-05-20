//lib/models/conversation_model.dart
class Conversation {
  final int? id; 
  String? title; 
  final DateTime createdAt;
  DateTime lastMessageTimestamp; //To sort conversations

  Conversation({
    this.id,
    this.title,
    required this.createdAt,
    required this.lastMessageTimestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'created_at': createdAt.toIso8601String(),
      'last_message_timestamp': lastMessageTimestamp.toIso8601String(),
    };
  }

  factory Conversation.fromMap(Map<String, dynamic> map) {
    return Conversation(
      id: map['id'] as int?,
      title: map['title'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      lastMessageTimestamp: DateTime.parse(map['last_message_timestamp'] as String),
    );
  }
}