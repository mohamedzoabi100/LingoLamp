import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CloudFlashcardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Returns the collection reference for the current user's flashcards for a given language.
  CollectionReference<Map<String, dynamic>> _flashcardsCollection(String languageCode) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('User not logged in');
    }
    return _firestore.collection('users').doc(uid).collection('flashcards').doc(languageCode).collection('items');
  }

  /// Get all flashcards for the current user and language.
  Future<List<Map<String, dynamic>>> getFlashcards(String languageCode) async {
    final snapshot = await _flashcardsCollection(languageCode).get();
    return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
  }

  /// Listen to flashcards changes for the current user and language.
  Stream<List<Map<String, dynamic>>> listenToFlashcards(String languageCode) {
    return _flashcardsCollection(languageCode).snapshots().map((snapshot) =>
      snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList()
    );
  }

  /// Add a flashcard for the current user and language.
  Future<void> addFlashcard(String languageCode, Map<String, dynamic> flashcardData) async {
    await _flashcardsCollection(languageCode).add({
      ...flashcardData,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Update a flashcard by its document ID for the current user and language.
  Future<void> updateFlashcard(String languageCode, String flashcardId, Map<String, dynamic> flashcardData) async {
    await _flashcardsCollection(languageCode).doc(flashcardId).update(flashcardData);
  }

  /// Remove a flashcard by its document ID for the current user and language.
  Future<void> removeFlashcard(String languageCode, String flashcardId) async {
    await _flashcardsCollection(languageCode).doc(flashcardId).delete();
  }

  /// Remove all flashcards for a language (optional, for account/data deletion)
  Future<void> clearFlashcards(String languageCode) async {
    final batch = _firestore.batch();
    final snapshot = await _flashcardsCollection(languageCode).get();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
} 