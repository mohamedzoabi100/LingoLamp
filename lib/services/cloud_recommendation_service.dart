import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/recommended_flashcard_model.dart';

class CloudRecommendationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Returns the collection reference for the current user's recommendations for a given language.
  CollectionReference<Map<String, dynamic>> _recommendationsCollection(String languageCode) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('User not logged in');
    }
    return _firestore.collection('users').doc(uid).collection('recommendations').doc(languageCode).collection('items');
  }

  /// Get all recommendations for the current user and language.
  Future<List<RecommendedFlashcard>> getRecommendations(String languageCode) async {
    final snapshot = await _recommendationsCollection(languageCode).get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      // Use the document ID as the ID (since we're using ID as document ID)
      // Handle null or invalid IDs
      try {
        data['id'] = int.parse(doc.id);
      } catch (e) {
        print('⚠️ [CloudRecommendationService] Invalid document ID: ${doc.id}, skipping');
        return null;
      }
      data['languageCode'] = languageCode;
      return RecommendedFlashcard.fromMap(data);
    }).where((rec) => rec != null).cast<RecommendedFlashcard>().toList();
  }

  /// Listen to recommendations changes for the current user and language.
  Stream<List<RecommendedFlashcard>> listenToRecommendations(String languageCode) {
    return _recommendationsCollection(languageCode).snapshots().map((snapshot) =>
      snapshot.docs.map((doc) {
        final data = doc.data();
        // Use the document ID as the ID (since we're using ID as document ID)
        // Handle null or invalid IDs
        try {
          data['id'] = int.parse(doc.id);
        } catch (e) {
          print('⚠️ [CloudRecommendationService] Invalid document ID: ${doc.id}, skipping');
          return null;
        }
        data['languageCode'] = languageCode;
        return RecommendedFlashcard.fromMap(data);
      }).where((rec) => rec != null).cast<RecommendedFlashcard>().toList()
    );
  }

  /// Add a recommendation for the current user and language.
  Future<void> addRecommendation(String languageCode, RecommendedFlashcard recommendation) async {
    // Use a consistent document ID based on term and language to avoid duplicates
    final documentId = '${recommendation.term}_${languageCode}'.hashCode.toString();
    
    await _recommendationsCollection(languageCode).doc(documentId).set({
      ...recommendation.toMap(),
      'id': int.parse(documentId), // Ensure the ID matches the document ID
      'createdAt': FieldValue.serverTimestamp(),
      'lastModified': FieldValue.serverTimestamp(),
    });
  }

  /// Update a recommendation for the current user and language.
  Future<void> updateRecommendation(String languageCode, RecommendedFlashcard recommendation) async {
    if (recommendation.id == null) {
      throw Exception('Cannot update recommendation without ID');
    }
    
    await _recommendationsCollection(languageCode).doc(recommendation.id.toString()).update({
      ...recommendation.toMap(),
      'lastModified': FieldValue.serverTimestamp(),
    });
  }

  /// Remove a recommendation by its term for the current user and language.
  Future<void> removeRecommendation(String languageCode, int recommendationId) async {
    // Try to find the document by ID first
    final snapshot = await _recommendationsCollection(languageCode).where('id', isEqualTo: recommendationId).get();
    if (snapshot.docs.isNotEmpty) {
      await snapshot.docs.first.reference.delete();
    } else {
      // Fallback: try to delete by document ID
      await _recommendationsCollection(languageCode).doc(recommendationId.toString()).delete();
    }
  }

  /// Remove a recommendation by its term for the current user and language.
  Future<void> removeRecommendationByTerm(String languageCode, String term) async {
    final documentId = '${term}_${languageCode}'.hashCode.toString();
    await _recommendationsCollection(languageCode).doc(documentId).delete();
  }

  /// Remove all recommendations for a language (optional, for account/data deletion)
  Future<void> clearRecommendations(String languageCode) async {
    final batch = _firestore.batch();
    final snapshot = await _recommendationsCollection(languageCode).get();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// Clean up null or invalid document IDs (for fixing existing data)
  Future<void> cleanupInvalidIds(String languageCode) async {
    final batch = _firestore.batch();
    final snapshot = await _recommendationsCollection(languageCode).get();
    
    for (final doc in snapshot.docs) {
      try {
        // Try to parse the document ID as an integer
        int.parse(doc.id);
      } catch (e) {
        // If parsing fails, delete the document
        print('🗑️ [CloudRecommendationService] Deleting invalid document ID: ${doc.id}');
        batch.delete(doc.reference);
      }
    }
    
    await batch.commit();
    print('✅ [CloudRecommendationService] Cleaned up invalid document IDs');
  }

  /// Clean up duplicate recommendations (for fixing existing data)
  Future<void> cleanupDuplicates(String languageCode) async {
    final snapshot = await _recommendationsCollection(languageCode).get();
    final Map<String, List<DocumentSnapshot>> termGroups = {};
    
    // Group documents by term
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final term = data['term'] as String?;
      if (term != null) {
        termGroups.putIfAbsent(term, () => []).add(doc);
      }
    }
    
    // Remove duplicates, keeping only the first one
    final batch = _firestore.batch();
    for (final entry in termGroups.entries) {
      final term = entry.key;
      final docs = entry.value;
      
      if (docs.length > 1) {
        print('🗑️ [CloudRecommendationService] Found ${docs.length} duplicates for term "$term", keeping first one');
        
        // Keep the first document, delete the rest
        for (int i = 1; i < docs.length; i++) {
          batch.delete(docs[i].reference);
        }
      }
    }
    
    await batch.commit();
    print('✅ [CloudRecommendationService] Cleaned up duplicate recommendations');
  }

  /// Get all recommendations across all languages for the current user.
  Future<List<RecommendedFlashcard>> getAllRecommendations() async {
    final List<RecommendedFlashcard> allRecommendations = [];
    
    // Get all language documents
    final languagesSnapshot = await _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .collection('recommendations')
        .get();
    
    for (final languageDoc in languagesSnapshot.docs) {
      final languageCode = languageDoc.id;
      
      // Get all recommendations for this language
      final recommendationsSnapshot = await languageDoc.reference
          .collection('items')
          .get();
      
      for (final recommendationDoc in recommendationsSnapshot.docs) {
        try {
          final data = recommendationDoc.data();
          // Use the document ID as the ID (since we're using ID as document ID)
          // Handle null or invalid IDs
          try {
            data['id'] = int.parse(recommendationDoc.id);
          } catch (e) {
            print('⚠️ [CloudRecommendationService] Invalid document ID: ${recommendationDoc.id}, skipping');
            continue;
          }
          data['languageCode'] = languageCode;
          allRecommendations.add(RecommendedFlashcard.fromMap(data));
        } catch (e) {
          print('⚠️ Error parsing cloud recommendation: $e');
        }
      }
    }
    
    return allRecommendations;
  }
} 