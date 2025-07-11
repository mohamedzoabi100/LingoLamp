//lib/models/conversation_model.dart
class Conversation {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;
  final bool isDeleted;
  final Map<String, dynamic>? extra;

  Conversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.isArchived = false,
    this.isDeleted = false,
    this.extra,
  });

  factory Conversation.fromMap(Map<String, dynamic> map) => Conversation(
    id: map['id']?.toString() ?? '',
    title: map['title']?.toString() ?? 'Chat',
    createdAt: DateTime.parse(map['createdAt'] ?? map['created_at']),
    updatedAt: DateTime.parse(map['last_message_timestamp'] ?? map['updatedAt'] ?? map['updated_at'] ?? map['createdAt'] ?? map['created_at']),
    isArchived: map['isArchived'] == true || map['is_archived'] == 1,
    isDeleted: map['isDeleted'] == true || map['is_deleted'] == 1,
    extra: map['extra'],
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isArchived': isArchived,
    'isDeleted': isDeleted,
    'extra': extra,
  };
}