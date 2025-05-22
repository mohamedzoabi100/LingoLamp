//lib/services/phrase_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

class PhraseModel {
  final String id;
  final String english;
  final String spanish;
  final String category;
  final String difficulty;
  final DateTime createdAt;

  PhraseModel({
    required this.id,
    required this.english,
    required this.spanish,
    required this.category,
    required this.difficulty,
    required this.createdAt,
  });

  factory PhraseModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return PhraseModel(
      id: doc.id,
      english: data['english'] ?? '',
      spanish: data['spanish'] ?? '',
      category: data['category'] ?? '',
      difficulty: data['difficulty'] ?? 'beginner',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'english': english,
      'spanish': spanish,
      'category': category,
      'difficulty': difficulty,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }
}

class PhraseService {
  static final PhraseService _instance = PhraseService._internal();
  factory PhraseService() => _instance;
  PhraseService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'phrases';

  // Get phrases by category
  Stream<List<PhraseModel>> getPhrasesForCategory(String category) {
    return _firestore
        .collection(_collection)
        .where('category', isEqualTo: category)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PhraseModel.fromFirestore(doc))
            .toList()
            ..sort((a, b) => a.english.compareTo(b.english))); // Sort in app
  }

  // Get all phrases for search
  Stream<List<PhraseModel>> getAllPhrases() {
    return _firestore
        .collection(_collection)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PhraseModel.fromFirestore(doc))
            .toList()
            ..sort((a, b) => a.category.compareTo(b.category))); // Sort by category first
  }

  // Search phrases
  Stream<List<PhraseModel>> searchPhrases(String query) {
    if (query.isEmpty) return Stream.value([]);
    
    return getAllPhrases().map((phrases) => phrases
        .where((phrase) =>
            phrase.english.toLowerCase().contains(query.toLowerCase()) ||
            phrase.spanish.toLowerCase().contains(query.toLowerCase()))
        .toList()
        ..sort((a, b) => a.english.compareTo(b.english))); // Sort results alphabetically
  }

  // Add a new phrase (for admin use)
  Future<void> addPhrase(PhraseModel phrase) async {
    await _firestore.collection(_collection).add(phrase.toFirestore());
  }

  // Auto-sync CSV data with Firebase
  Future<void> initializeSampleData() async {
    try {
      // Always load CSV file
      final csvString = await rootBundle.loadString('assets/data/phrases.csv');
      final List<List<String>> csvData = csvString
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .map((line) => line.split(','))
          .toList();

      print('Found ${csvData.length - 1} phrases in CSV');

      // Get existing phrases from Firebase
      final snapshot = await _firestore.collection(_collection).get();
      final existingPhrases = <String, PhraseModel>{};
      
      for (var doc in snapshot.docs) {
        final phrase = PhraseModel.fromFirestore(doc);
        // Create unique key from english + category
        final key = '${phrase.english.toLowerCase()}_${phrase.category.toLowerCase()}';
        existingPhrases[key] = phrase;
      }

      print('Found ${existingPhrases.length} existing phrases in Firebase');

      int addedCount = 0;
      int updatedCount = 0;

      // Process CSV data (skip header row)
      for (int i = 1; i < csvData.length; i++) {
        final row = csvData[i];
        if (row.length >= 4) {
          final englishText = row[0].trim();
          final spanishText = row[1].trim();
          final categoryText = row[2].trim();
          final difficultyText = row[3].trim();
          
          final key = '${englishText.toLowerCase()}_${categoryText.toLowerCase()}';
          
          if (existingPhrases.containsKey(key)) {
            // Check if phrase needs updating
            final existing = existingPhrases[key]!;
            if (existing.spanish != spanishText || 
                existing.difficulty != difficultyText) {
              // Update existing phrase
              await _firestore.collection(_collection).doc(existing.id).update({
                'spanish': spanishText,
                'difficulty': difficultyText,
              });
              updatedCount++;
            }
          } else {
            // Add new phrase
            final newPhrase = PhraseModel(
              id: '',
              english: englishText,
              spanish: spanishText,
              category: categoryText,
              difficulty: difficultyText,
              createdAt: DateTime.now(),
            );
            await addPhrase(newPhrase);
            addedCount++;
          }
        }
      }

      print('CSV sync complete: $addedCount added, $updatedCount updated');

    } catch (e) {
      print('Error syncing CSV with Firebase: $e');
      // Fallback to basic phrases if CSV fails
      await _initializeBasicPhrases();
    }
  }

  // Fallback basic phrases
  Future<void> _initializeBasicPhrases() async {
    final snapshot = await _firestore.collection(_collection).limit(1).get();
    if (snapshot.docs.isNotEmpty) return;

    final basicPhrases = [
      PhraseModel(id: '', english: 'Hello', spanish: 'Hola', category: 'Greetings', difficulty: 'beginner', createdAt: DateTime.now()),
      PhraseModel(id: '', english: 'Thank you', spanish: 'Gracias', category: 'Greetings', difficulty: 'beginner', createdAt: DateTime.now()),
      PhraseModel(id: '', english: 'Help!', spanish: '¡Ayuda!', category: 'Emergencies', difficulty: 'beginner', createdAt: DateTime.now()),
    ];

    for (var phrase in basicPhrases) {
      await addPhrase(phrase);
    }
    print('Basic fallback phrases added');
  }
}