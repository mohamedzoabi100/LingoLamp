import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/flashcard_model.dart';

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
  Future<List<Flashcard>> getFlashcards(String languageCode) async {
    final snapshot = await _flashcardsCollection(languageCode).get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      // Use the document ID as the UUID (since we're using UUID as document ID)
      data['uuid'] = doc.id;
      data['languageCode'] = languageCode;
      return Flashcard.fromMap(data);
    }).toList();
  }

  /// Listen to flashcards changes for the current user and language.
  Stream<List<Flashcard>> listenToFlashcards(String languageCode) {
    return _flashcardsCollection(languageCode).snapshots().map((snapshot) =>
      snapshot.docs.map((doc) {
        final data = doc.data();
        // Use the document ID as the UUID (since we're using UUID as document ID)
        data['uuid'] = doc.id;
        data['languageCode'] = languageCode;
        return Flashcard.fromMap(data);
      }).toList()
    );
  }

  /// Add a flashcard for the current user and language.
  Future<void> addFlashcard(String languageCode, Flashcard flashcard) async {
    await _flashcardsCollection(languageCode).doc(flashcard.uuid).set({
      ...flashcard.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'lastModified': FieldValue.serverTimestamp(),
    });
  }

  /// Update a flashcard for the current user and language.
  Future<void> updateFlashcard(String languageCode, Flashcard flashcard) async {
    await _flashcardsCollection(languageCode).doc(flashcard.uuid).update({
      ...flashcard.toMap(),
      'lastModified': FieldValue.serverTimestamp(),
    });
  }

  /// Remove a flashcard by its UUID for the current user and language.
  Future<void> removeFlashcard(String languageCode, String flashcardUuid) async {
    await _flashcardsCollection(languageCode).doc(flashcardUuid).delete();
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

  /// Get all flashcards across all languages for the current user.
  Future<List<Flashcard>> getAllFlashcards() async {
    final List<Flashcard> allFlashcards = [];
    
    // Get all language documents
    final languagesSnapshot = await _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .collection('flashcards')
        .get();
    
    for (final languageDoc in languagesSnapshot.docs) {
      final languageCode = languageDoc.id;
      
      // Get all flashcards for this language
      final flashcardsSnapshot = await languageDoc.reference
          .collection('items')
          .get();
      
      for (final flashcardDoc in flashcardsSnapshot.docs) {
        try {
          final data = flashcardDoc.data();
          // Use the document ID as the UUID (since we're using UUID as document ID)
          data['uuid'] = flashcardDoc.id;
          data['languageCode'] = languageCode;
          allFlashcards.add(Flashcard.fromMap(data));
        } catch (e) {
          print('⚠️ Error parsing cloud flashcard: $e');
        }
      }
    }
    
    return allFlashcards;
  }
} 