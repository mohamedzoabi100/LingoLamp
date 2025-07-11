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
    id: map['id'],
    title: map['title'],
    createdAt: DateTime.parse(map['createdAt']),
    updatedAt: DateTime.parse(map['updatedAt']),
    isArchived: map['isArchived'] ?? false,
    isDeleted: map['isDeleted'] ?? false,
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