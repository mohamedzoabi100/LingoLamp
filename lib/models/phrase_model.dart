import 'package:flutter/foundation.dart';

@immutable
class PhraseModel {
  final String id;
  final String english;
  final String spanish;
  final String category;
  final String difficulty;
  final DateTime createdAt;
  final bool isFavorite;
  final bool isAiGenerated;

  const PhraseModel({
    required this.id,
    required this.english,
    required this.spanish,
    required this.category,
    required this.difficulty,
    required this.createdAt,
    this.isFavorite = false,
    this.isAiGenerated = false,
  });

  PhraseModel copyWith({
    String? id,
    String? english,
    String? spanish,
    String? category,
    String? difficulty,
    DateTime? createdAt,
    bool? isFavorite,
    bool? isAiGenerated,
  }) {
    return PhraseModel(
      id: id ?? this.id,
      english: english ?? this.english,
      spanish: spanish ?? this.spanish,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      createdAt: createdAt ?? this.createdAt,
      isFavorite: isFavorite ?? this.isFavorite,
      isAiGenerated: isAiGenerated ?? this.isAiGenerated,
    );
  }

  factory PhraseModel.fromJson(Map<String, dynamic> json) {
    return PhraseModel(
      id: json['id'],
      english: json['english'],
      spanish: json['spanish'],
      category: json['category'],
      difficulty: json['difficulty'],
      createdAt: DateTime.parse(json['createdAt']),
      isFavorite: json['isFavorite'] ?? false,
      isAiGenerated: json['isAiGenerated'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'english': english,
      'spanish': spanish,
      'category': category,
      'difficulty': difficulty,
      'createdAt': createdAt.toIso8601String(),
      'isFavorite': isFavorite,
      'isAiGenerated': isAiGenerated,
    };
  }
} 