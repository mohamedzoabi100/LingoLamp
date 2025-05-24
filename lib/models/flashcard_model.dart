class Flashcard {
  final int? id;
  final String originalText;
  final String translatedText;
  final String sourceLanguage;
  final String targetLanguage;
  final DateTime createdAt;
  final DateTime lastStudied;
  final int timesStudied;
  final int difficulty; // 1 = easy, 2 = medium, 3 = hard
  final bool isFavorite;

  Flashcard({
    this.id,
    required this.originalText,
    required this.translatedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.createdAt,
    required this.lastStudied,
    this.timesStudied = 0,
    this.difficulty = 2,
    this.isFavorite = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'original_text': originalText,
      'translated_text': translatedText,
      'source_language': sourceLanguage,
      'target_language': targetLanguage,
      'created_at': createdAt.toIso8601String(),
      'last_studied': lastStudied.toIso8601String(),
      'times_studied': timesStudied,
      'difficulty': difficulty,
      'is_favorite': isFavorite ? 1 : 0,
    };
  }

  static Flashcard fromMap(Map<String, dynamic> map) {
    return Flashcard(
      id: map['id'],
      originalText: map['original_text'],
      translatedText: map['translated_text'],
      sourceLanguage: map['source_language'],
      targetLanguage: map['target_language'],
      createdAt: DateTime.parse(map['created_at']),
      lastStudied: DateTime.parse(map['last_studied']),
      timesStudied: map['times_studied'] ?? 0,
      difficulty: map['difficulty'] ?? 2,
      isFavorite: map['is_favorite'] == 1,
    );
  }

  Flashcard copyWith({
    int? id,
    String? originalText,
    String? translatedText,
    String? sourceLanguage,
    String? targetLanguage,
    DateTime? createdAt,
    DateTime? lastStudied,
    int? timesStudied,
    int? difficulty,
    bool? isFavorite,
  }) {
    return Flashcard(
      id: id ?? this.id,
      originalText: originalText ?? this.originalText,
      translatedText: translatedText ?? this.translatedText,
      sourceLanguage: sourceLanguage ?? this.sourceLanguage,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      createdAt: createdAt ?? this.createdAt,
      lastStudied: lastStudied ?? this.lastStudied,
      timesStudied: timesStudied ?? this.timesStudied,
      difficulty: difficulty ?? this.difficulty,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
} 