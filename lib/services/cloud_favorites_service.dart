import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CloudFavoritesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Returns the collection reference for the current user's favorites for a given language.
  CollectionReference<Map<String, dynamic>> _favoritesCollection(String languageCode) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('User not logged in');
    }
    return _firestore.collection('users').doc(uid).collection('favorites').doc(languageCode).collection('items');
  }

  /// Get all favorites for the current user and language.
  Future<List<Map<String, dynamic>>> getFavorites(String languageCode) async {
    final snapshot = await _favoritesCollection(languageCode).get();
    return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
  }

  /// Listen to favorites changes for the current user and language.
  Stream<List<Map<String, dynamic>>> listenToFavorites(String languageCode) {
    return _favoritesCollection(languageCode).snapshots().map((snapshot) =>
      snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList()
    );
  }

  /// Add a favorite (phraseId or phrase data) for the current user and language.
  Future<void> addFavorite(String languageCode, Map<String, dynamic> favoriteData) async {
    await _favoritesCollection(languageCode).add({
      ...favoriteData,
      'addedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Remove a favorite by its document ID for the current user and language.
  Future<void> removeFavorite(String languageCode, String favoriteId) async {
    await _favoritesCollection(languageCode).doc(favoriteId).delete();
  }

  /// Remove all favorites for a language (optional, for account/data deletion)
  Future<void> clearFavorites(String languageCode) async {
    final batch = _firestore.batch();
    final snapshot = await _favoritesCollection(languageCode).get();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
} 