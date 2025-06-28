import 'package:flutter/foundation.dart';

@immutable
class RecommendedFlashcard {
  final int? id;
  final String term; // the word or short phrase being suggested
  final String context; // snippet that triggered the recommendation
  final String source; // e.g. "chat", "favorite"
  final double weight; // ranking score (higher = stronger suggestion)
  final DateTime createdAt;
  final DateTime updatedAt;

  const RecommendedFlashcard({
    this.id,
    required this.term,
    required this.context,
    required this.source,
    required this.weight,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RecommendedFlashcard.fromMap(Map<String, dynamic> map) {
    return RecommendedFlashcard(
      id: map['id'] as int?,
      term: map['term'] as String,
      context: map['context'] as String,
      source: map['source'] as String,
      weight: (map['weight'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'term': term,
      'context': context,
      'source': source,
      'weight': weight,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  RecommendedFlashcard copyWith({
    int? id,
    String? term,
    String? context,
    String? source,
    double? weight,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RecommendedFlashcard(
      id: id ?? this.id,
      term: term ?? this.term,
      context: context ?? this.context,
      source: source ?? this.source,
      weight: weight ?? this.weight,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
} 