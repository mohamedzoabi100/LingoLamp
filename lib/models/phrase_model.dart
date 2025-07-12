import 'package:flutter/foundation.dart';

@immutable
class PhraseModel {
  final String id;
  final String english;
  final String translation; // was 'spanish', now generic
  final String category;
  final String difficulty;
  final DateTime createdAt;
  final bool isFavorite;
  final bool isAiGenerated;
  final String languageCode; // NEW

  const PhraseModel({
    required this.id,
    required this.english,
    required this.translation,
    required this.category,
    required this.difficulty,
    required this.createdAt,
    this.isFavorite = false,
    this.isAiGenerated = false,
    this.languageCode = 'es',
  });

  PhraseModel copyWith({
    String? id,
    String? english,
    String? translation,
    String? category,
    String? difficulty,
    DateTime? createdAt,
    bool? isFavorite,
    bool? isAiGenerated,
    String? languageCode,
  }) {
    return PhraseModel(
      id: id ?? this.id,
      english: english ?? this.english,
      translation: translation ?? this.translation,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      createdAt: createdAt ?? this.createdAt,
      isFavorite: isFavorite ?? this.isFavorite,
      isAiGenerated: isAiGenerated ?? this.isAiGenerated,
      languageCode: languageCode ?? this.languageCode,
    );
  }

  factory PhraseModel.fromJson(Map<String, dynamic> json) {
    return PhraseModel(
      id: json['id'],
      english: json['english'],
      translation: json['translation'] ?? json['spanish'],
      category: json['category'],
      difficulty: json['difficulty'],
      createdAt: DateTime.parse(json['createdAt']),
      isFavorite: json['isFavorite'] ?? false,
      isAiGenerated: json['isAiGenerated'] ?? false,
      languageCode: json['languageCode'] ?? 'es',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'english': english,
      'translation': translation,
      'category': category,
      'difficulty': difficulty,
      'createdAt': createdAt.toIso8601String(),
      'isFavorite': isFavorite,
      'isAiGenerated': isAiGenerated,
      'languageCode': languageCode,
    };
  }

  String get spanish => translation;
} 