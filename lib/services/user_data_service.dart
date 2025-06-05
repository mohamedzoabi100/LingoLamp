import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/flashcard_model.dart';
import '../utils/database_helper.dart';
import '../services/phrase_service.dart';

class UserDataService {
  static final UserDataService _instance = UserDataService._internal();
  factory UserDataService() => _instance;
  UserDataService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final PhraseService _phraseService = PhraseService();

  // Current user getter
  User? get currentUser => _auth.currentUser;
  String? get userId => currentUser?.uid;

  // Check if user is authenticated
  bool get isAuthenticated => currentUser != null;

  // === FLASHCARDS SYNC ===

  // Sync local flashcards to Firestore
  Future<void> syncFlashcardsToCloud() async {
    if (!isAuthenticated) return;
    
    try {
      final localFlashcards = await _dbHelper.getAllFlashcards();
      final batch = _firestore.batch();
      
      for (final flashcard in localFlashcards) {
        final docRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('flashcards')
            .doc('${flashcard.originalText}_${flashcard.translatedText}'.hashCode.toString());
        
        batch.set(docRef, {
          'originalText': flashcard.originalText,
          'translatedText': flashcard.translatedText,
          'sourceLanguage': flashcard.sourceLanguage,
          'targetLanguage': flashcard.targetLanguage,
          'createdAt': flashcard.createdAt.toIso8601String(),
          'lastStudied': flashcard.lastStudied.toIso8601String(),
          'timesStudied': flashcard.timesStudied,
          'difficulty': flashcard.difficulty,
          'isFavorite': flashcard.isFavorite,
          'lastModified': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      
      await batch.commit();
      print('Successfully synced ${localFlashcards.length} flashcards to cloud');
    } catch (e) {
      print('Error syncing flashcards to cloud: $e');
      rethrow;
    }
  }

  // Load flashcards from Firestore and merge with local
  Future<void> syncFlashcardsFromCloud() async {
    if (!isAuthenticated) return;
    
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('flashcards')
          .get();
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final flashcard = Flashcard(
          originalText: data['originalText'],
          translatedText: data['translatedText'],
          sourceLanguage: data['sourceLanguage'],
          targetLanguage: data['targetLanguage'],
          createdAt: DateTime.parse(data['createdAt']),
          lastStudied: DateTime.parse(data['lastStudied']),
          timesStudied: data['timesStudied'] ?? 0,
          difficulty: data['difficulty'] ?? 2,
          isFavorite: data['isFavorite'] ?? false,
        );
        
        // Check if flashcard already exists locally
        final exists = await _dbHelper.flashcardExists(
          flashcard.originalText, 
          flashcard.translatedText
        );
        
        if (!exists) {
          await _dbHelper.insertFlashcard(flashcard);
        }
      }
      
      print('Successfully synced ${snapshot.docs.length} flashcards from cloud');
    } catch (e) {
      print('Error syncing flashcards from cloud: $e');
      rethrow;
    }
  }

  // Add a new flashcard and sync to cloud
  Future<void> addFlashcard(Flashcard flashcard) async {
    // Add to local database first
    await _dbHelper.insertFlashcard(flashcard);
    
    // Sync to cloud if user is authenticated
    if (isAuthenticated) {
      try {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('flashcards')
            .doc('${flashcard.originalText}_${flashcard.translatedText}'.hashCode.toString())
            .set({
          'originalText': flashcard.originalText,
          'translatedText': flashcard.translatedText,
          'sourceLanguage': flashcard.sourceLanguage,
          'targetLanguage': flashcard.targetLanguage,
          'createdAt': flashcard.createdAt.toIso8601String(),
          'lastStudied': flashcard.lastStudied.toIso8601String(),
          'timesStudied': flashcard.timesStudied,
          'difficulty': flashcard.difficulty,
          'isFavorite': flashcard.isFavorite,
          'lastModified': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        print('Error adding flashcard to cloud: $e');
        // Continue even if cloud sync fails
      }
    }
  }

  // Update flashcard and sync to cloud
  Future<void> updateFlashcard(Flashcard flashcard) async {
    // Update local database first
    await _dbHelper.updateFlashcard(flashcard);
    
    // Sync to cloud if user is authenticated
    if (isAuthenticated) {
      try {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('flashcards')
            .doc('${flashcard.originalText}_${flashcard.translatedText}'.hashCode.toString())
            .update({
          'lastStudied': flashcard.lastStudied.toIso8601String(),
          'timesStudied': flashcard.timesStudied,
          'difficulty': flashcard.difficulty,
          'isFavorite': flashcard.isFavorite,
          'lastModified': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        print('Error updating flashcard in cloud: $e');
        // Continue even if cloud sync fails
      }
    }
  }

  // Delete flashcard and remove from cloud
  Future<void> deleteFlashcard(Flashcard flashcard) async {
    // Delete from local database first
    if (flashcard.id != null) {
      await _dbHelper.deleteFlashcard(flashcard.id!);
    }
    
    // Remove from cloud if user is authenticated
    if (isAuthenticated) {
      try {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('flashcards')
            .doc('${flashcard.originalText}_${flashcard.translatedText}'.hashCode.toString())
            .delete();
      } catch (e) {
        print('Error deleting flashcard from cloud: $e');
        // Continue even if cloud sync fails
      }
    }
  }

  // === FAVORITES SYNC ===

  // Sync local favorites to Firestore
  Future<void> syncFavoritesToCloud() async {
    if (!isAuthenticated) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesList = prefs.getStringList('favorite_phrases') ?? [];
      
      await _firestore
          .collection('users')
          .doc(userId)
          .set({
        'favorites': favoritesList,
        'lastModified': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      print('Successfully synced ${favoritesList.length} favorites to cloud');
    } catch (e) {
      print('Error syncing favorites to cloud: $e');
      rethrow;
    }
  }

  // Load favorites from Firestore and merge with local
  Future<void> syncFavoritesFromCloud() async {
    if (!isAuthenticated) return;
    
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      
      if (doc.exists && doc.data()!.containsKey('favorites')) {
        final cloudFavorites = List<String>.from(doc.data()!['favorites'] ?? []);
        
        // Get local favorites
        final prefs = await SharedPreferences.getInstance();
        final localFavorites = prefs.getStringList('favorite_phrases') ?? [];
        
        // Merge favorites (cloud takes precedence for new items)
        final mergedFavorites = <String>{};
        mergedFavorites.addAll(localFavorites);
        mergedFavorites.addAll(cloudFavorites);
        
        // Save merged favorites locally
        await prefs.setStringList('favorite_phrases', mergedFavorites.toList());
        
        // Update phrase service favorites
        await _phraseService.initializeSampleData();
        
        print('Successfully synced ${cloudFavorites.length} favorites from cloud');
      }
    } catch (e) {
      print('Error syncing favorites from cloud: $e');
      rethrow;
    }
  }

  // Add favorite and sync to cloud
  Future<void> addFavorite(String phraseId) async {
    // Add to local storage first
    await _phraseService.toggleFavorite(phraseId);
    
    // Sync to cloud if user is authenticated
    if (isAuthenticated) {
      await syncFavoritesToCloud();
    }
  }

  // Remove favorite and sync to cloud
  Future<void> removeFavorite(String phraseId) async {
    // Remove from local storage first
    await _phraseService.toggleFavorite(phraseId);
    
    // Sync to cloud if user is authenticated
    if (isAuthenticated) {
      await syncFavoritesToCloud();
    }
  }

  // === USER PROFILE DATA ===

  // Save user profile data
  Future<void> saveUserProfile({
    String? displayName,
    String? preferredLanguage,
    Map<String, dynamic>? settings,
  }) async {
    if (!isAuthenticated) return;
    
    try {
      final profileData = <String, dynamic>{
        'email': currentUser!.email,
        'lastLogin': FieldValue.serverTimestamp(),
      };
      
      if (displayName != null) profileData['displayName'] = displayName;
      if (preferredLanguage != null) profileData['preferredLanguage'] = preferredLanguage;
      if (settings != null) profileData['settings'] = settings;
      
      await _firestore
          .collection('users')
          .doc(userId)
          .set(profileData, SetOptions(merge: true));
      
      print('User profile saved successfully');
    } catch (e) {
      print('Error saving user profile: $e');
      rethrow;
    }
  }

  // Get user profile data
  Future<Map<String, dynamic>?> getUserProfile() async {
    if (!isAuthenticated) return null;
    
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      
      return doc.exists ? doc.data() : null;
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  // === COMPREHENSIVE SYNC ===

  // Perform full sync when user logs in
  Future<void> performFullSync() async {
    if (!isAuthenticated) return;
    
    try {
      print('Starting full user data sync...');
      
      // Update user profile with login timestamp
      await saveUserProfile();
      
      // Sync data in parallel for better performance
      await Future.wait([
        syncFlashcardsFromCloud(),
        syncFavoritesFromCloud(),
      ]);
      
      // Then push any local changes to cloud
      await Future.wait([
        syncFlashcardsToCloud(),
        syncFavoritesToCloud(),
      ]);
      
      print('Full user data sync completed successfully');
    } catch (e) {
      print('Error during full sync: $e');
      rethrow;
    }
  }

  // Clear local data when user logs out
  Future<void> clearLocalData() async {
    try {
      // Clear shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('favorite_phrases');
      
      // Note: We don't clear the local database completely as it might contain
      // data from when the user was using the app as a guest
      
      print('Local user data cleared');
    } catch (e) {
      print('Error clearing local data: $e');
    }
  }

  // Listen to auth state changes and sync accordingly
  void setupAuthListener() {
    _auth.authStateChanges().listen((User? user) async {
      if (user != null) {
        // User logged in - perform full sync
        print('User logged in: ${user.email}');
        await performFullSync();
      } else {
        // User logged out - clear local data
        print('User logged out');
        await clearLocalData();
      }
    });
  }
} 