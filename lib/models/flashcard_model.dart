import 'package:uuid/uuid.dart';

class Flashcard {
  final int? id;
  final String uuid;
  final String originalText;
  final String translatedText;
  final String sourceLanguage;
  final String targetLanguage;
  final String languageCode;
  final DateTime createdAt;
  final DateTime lastStudied;
  final int timesStudied;
  final int difficulty; // 1 = easy, 2 = medium, 3 = hard
  final bool isFavorite;
  final String? category; // For organizing cards into decks
  final List<String> tags; // For filtering and organizing
  final DateTime? nextReview;
  final int interval;
  final double easeFactor;
  final int repetitions;

  Flashcard({
    this.id,
    String? uuid,
    required this.originalText,
    required this.translatedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    this.languageCode = 'es',
    required this.createdAt,
    required this.lastStudied,
    this.timesStudied = 0,
    this.difficulty = 2,
    this.isFavorite = false,
    this.category,
    this.tags = const [],
    this.nextReview,
    this.interval = 1,
    this.easeFactor = 2.5,
    this.repetitions = 0,
  }) : uuid = uuid ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uuid': uuid,
      'original_text': originalText,
      'translated_text': translatedText,
      'source_language': sourceLanguage,
      'target_language': targetLanguage,
      'language_code': languageCode,
      'created_at': createdAt.toIso8601String(),
      'last_studied': lastStudied.toIso8601String(),
      'times_studied': timesStudied,
      'difficulty': difficulty,
      'is_favorite': isFavorite ? 1 : 0,
      'category': category,
      'tags': tags.join(','), // Store tags as comma-separated string
    };
  }

  static Flashcard fromMap(Map<String, dynamic> map) {
    return Flashcard(
      id: map['id'],
      uuid: map['uuid'],
      originalText: map['original_text'],
      translatedText: map['translated_text'],
      sourceLanguage: map['source_language'],
      targetLanguage: map['target_language'],
      languageCode: map['language_code'] ?? 'es',
      createdAt: DateTime.parse(map['created_at']),
      lastStudied: DateTime.parse(map['last_studied']),
      timesStudied: map['times_studied'] ?? 0,
      difficulty: map['difficulty'] ?? 2,
      isFavorite: map['is_favorite'] == 1,
      category: map['category'],
      tags: map['tags'] != null
          ? (map['tags'] is String
              ? (map['tags'] as String).split(',').where((tag) => tag.isNotEmpty).toList()
              : (map['tags'] is List
                  ? List<String>.from(map['tags']).where((tag) => tag.isNotEmpty).toList()
                  : []))
          : [],
    );
  }

  Flashcard copyWith({
    int? id,
    String? uuid,
    String? originalText,
    String? translatedText,
    String? sourceLanguage,
    String? targetLanguage,
    String? languageCode,
    DateTime? createdAt,
    DateTime? lastStudied,
    int? timesStudied,
    int? difficulty,
    bool? isFavorite,
    String? category,
    List<String>? tags,
    DateTime? nextReview,
    int? interval,
    double? easeFactor,
    int? repetitions,
  }) {
    return Flashcard(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      originalText: originalText ?? this.originalText,
      translatedText: translatedText ?? this.translatedText,
      sourceLanguage: sourceLanguage ?? this.sourceLanguage,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      languageCode: languageCode ?? this.languageCode,
      createdAt: createdAt ?? this.createdAt,
      lastStudied: lastStudied ?? this.lastStudied,
      timesStudied: timesStudied ?? this.timesStudied,
      difficulty: difficulty ?? this.difficulty,
      isFavorite: isFavorite ?? this.isFavorite,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      nextReview: nextReview ?? this.nextReview,
      interval: interval ?? this.interval,
      easeFactor: easeFactor ?? this.easeFactor,
      repetitions: repetitions ?? this.repetitions,
    );
  }

  /// Check if the card has a specific tag
  bool hasTag(String tag) {
    return tags.contains(tag);
  }

  /// Add a tag to the card
  Flashcard addTag(String tag) {
    if (hasTag(tag)) return this;
    return copyWith(tags: [...tags, tag]);
  }

  /// Remove a tag from the card
  Flashcard removeTag(String tag) {
    if (!hasTag(tag)) return this;
    return copyWith(tags: tags.where((t) => t != tag).toList());
  }

  /// Update the last studied time and increment study count
  Flashcard markAsStudied() {
    return copyWith(
      lastStudied: DateTime.now(),
      timesStudied: timesStudied + 1,
    );
  }
} 