//lib/services/user_data_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'phrase_service.dart';
import '../utils/database_helper.dart';
import '../models/flashcard_model.dart';

class UserDataService {
  static final UserDataService _instance = UserDataService._internal();
  factory UserDataService() => _instance;
  UserDataService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final PhraseService _phraseService = PhraseService();

  // Get current user
  User? get currentUser => _auth.currentUser;
  bool get isAuthenticated => currentUser != null;
  String? get userId => currentUser?.uid;

  // === FIXED GUEST DATA MANAGEMENT ===
  
  // Save LATEST guest data EVERY TIME before user logs in
  Future<void> _saveLatestGuestData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      print('🔄 Saving LATEST guest data before login...');
      
      // Save current favorites as LATEST guest favorites
      final currentFavorites = prefs.getStringList('favorite_phrases') ?? [];
      await prefs.setStringList('latest_guest_favorite_phrases', currentFavorites);
      print('💾 Saved ${currentFavorites.length} guest favorites');
      
      // Save current conversations as LATEST guest conversations
      final currentConversations = prefs.getString('conversations');
      if (currentConversations != null) {
        await prefs.setString('latest_guest_conversations', currentConversations);
        final convData = json.decode(currentConversations);
        final convCount = convData is Map ? convData.length : 0;
        print('💾 Saved $convCount guest conversations');
      } else {
        await prefs.remove('latest_guest_conversations');
        print('💾 No guest conversations to save');
      }
      
      // Save current AI phrases as LATEST guest AI phrases
      final currentAiPhrases = prefs.getStringList('ai_phrases') ?? [];
      await prefs.setStringList('latest_guest_ai_phrases', currentAiPhrases);
      print('💾 Saved ${currentAiPhrases.length} guest AI phrases');
      
      // Save current flashcards as LATEST guest flashcards
      final flashcards = await _dbHelper.getAllFlashcards();
      final flashcardsJson = flashcards.map((f) => json.encode({
        'originalText': f.originalText,
        'translatedText': f.translatedText,
        'sourceLanguage': f.sourceLanguage,
        'targetLanguage': f.targetLanguage,
        'difficulty': f.difficulty,
        'createdAt': f.createdAt.toIso8601String(),
        'lastStudied': f.lastStudied.toIso8601String(),
        'timesStudied': f.timesStudied,
        'isFavorite': f.isFavorite,
      })).toList();
      await prefs.setStringList('latest_guest_flashcards', flashcardsJson);
      print('💾 Saved ${flashcards.length} guest flashcards');
      
      print('✅ Saved LATEST guest data successfully');
    } catch (e) {
      print('❌ Error saving latest guest data: $e');
    }
  }
  
  // Restore LATEST guest data when user logs out
  Future<void> _restoreLatestGuestData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      print('🔄 Restoring LATEST guest data...');
      
      // FORCE restore LATEST guest favorites (overwrite any signed-in changes)
      final latestGuestFavorites = prefs.getStringList('latest_guest_favorite_phrases') ?? [];
      await prefs.setStringList('favorite_phrases', latestGuestFavorites);
      print('📱 FORCE restored ${latestGuestFavorites.length} guest favorites');
      
      // FORCE restore LATEST guest conversations (overwrite any signed-in changes)
      final latestGuestConversations = prefs.getString('latest_guest_conversations');
      if (latestGuestConversations != null) {
        await prefs.setString('conversations', latestGuestConversations);
        final convData = json.decode(latestGuestConversations);
        final convCount = convData is Map ? convData.length : 0;
        print('📱 FORCE restored $convCount guest conversations');
      } else {
        await prefs.remove('conversations');
        print('📱 FORCE cleared conversations (no guest conversations to restore)');
      }
      
      // FORCE restore LATEST guest AI phrases (overwrite any signed-in changes)
      final latestGuestAiPhrases = prefs.getStringList('latest_guest_ai_phrases') ?? [];
      await prefs.setStringList('ai_phrases', latestGuestAiPhrases);
      print('📱 FORCE restored ${latestGuestAiPhrases.length} guest AI phrases');
      
      // FORCE restore LATEST guest flashcards to database (overwrite any signed-in changes)
      await _dbHelper.clearAllFlashcards(); // Clear ALL current flashcards
      final latestGuestFlashcardsJson = prefs.getStringList('latest_guest_flashcards') ?? [];
      for (final flashcardJson in latestGuestFlashcardsJson) {
        try {
          final data = json.decode(flashcardJson);
          final flashcard = Flashcard(
            originalText: data['originalText'],
            translatedText: data['translatedText'],
            sourceLanguage: data['sourceLanguage'] ?? 'en-US',
            targetLanguage: data['targetLanguage'] ?? 'es-ES',
            createdAt: DateTime.parse(data['createdAt']),
            lastStudied: DateTime.parse(data['lastStudied']),
            timesStudied: data['timesStudied'] ?? 0,
            difficulty: data['difficulty'] ?? 2,
            isFavorite: data['isFavorite'] ?? false,
          );
          await _dbHelper.insertFlashcard(flashcard);
        } catch (e) {
          print('Error restoring latest guest flashcard: $e');
        }
      }
      print('📱 FORCE restored ${latestGuestFlashcardsJson.length} guest flashcards');
      
      // NUCLEAR OPTION: Clear ALL conversations and messages from database
      await _clearAllConversationsAndMessages();
      
      // Smart restore guest conversations (don't clear everything)
      await _restoreGuestConversationsSmartly();
      
      // FORCE clear any signed-in specific storage
      await prefs.remove('signed_in_favorite_phrases');
      await prefs.remove('signed_in_conversations');
      await prefs.remove('signed_in_ai_phrases');
      await prefs.remove('signed_in_flashcards');
      print('🧹 Cleared signed-in specific storage');
      
      // Update phrase service to refresh favorites
      await _phraseService.initializeSampleData();
      
      print('✅ FORCE restored LATEST guest data successfully');
    } catch (e) {
      print('❌ Error restoring latest guest data: $e');
    }
  }

  // NUCLEAR OPTION: Clear all conversations and messages from database
  Future<void> _clearAllConversationsAndMessages() async {
    try {
      final db = await _dbHelper.database;
      
      // Delete all messages
      await db.delete('messages');
      print('🗑️ Cleared all messages from database');
      
      // Delete all conversations
      await db.delete('conversations');
      print('🗑️ Cleared all conversations from database');
      
    } catch (e) {
      print('❌ Error clearing conversations and messages: $e');
    }
  }

  // Smart restore: Only restore guest conversations, filter out signed-in ones
  Future<void> _restoreGuestConversationsSmartly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get saved guest conversations
      final savedGuestConversations = prefs.getString('latest_guest_conversations');
      
      if (savedGuestConversations != null) {
        // Directly restore the saved guest conversations
        await prefs.setString('conversations', savedGuestConversations);
        final convData = json.decode(savedGuestConversations);
        final convCount = convData is Map ? convData.length : 0;
        print('✅ Smart restored $convCount guest conversations only');
      } else {
        // No guest conversations to restore
        await prefs.remove('conversations');
        print('ℹ️ No guest conversations to restore - cleared conversations');
      }
    } catch (e) {
      print('❌ Error in smart conversation restore: $e');
    }
  }

  // === CLOUD SYNC METHODS ===

  // Sync flashcards to cloud
  Future<void> syncFlashcardsToCloud() async {
    if (!isAuthenticated) return;
    
    try {
      final flashcards = await _dbHelper.getAllFlashcards();
      final batch = _firestore.batch();
      
      // Clear existing flashcards in cloud
      final collection = _firestore
          .collection('users')
          .doc(userId)
          .collection('flashcards');
      
      final existingDocs = await collection.get();
      for (final doc in existingDocs.docs) {
        batch.delete(doc.reference);
      }
      
      // Add current flashcards to cloud
      for (final flashcard in flashcards) {
        final docRef = collection.doc();
        batch.set(docRef, {
          'originalText': flashcard.originalText,
          'translatedText': flashcard.translatedText,
          'sourceLanguage': flashcard.sourceLanguage,
          'targetLanguage': flashcard.targetLanguage,
          'createdAt': flashcard.createdAt,
          'lastStudied': flashcard.lastStudied,
          'timesStudied': flashcard.timesStudied,
          'difficulty': flashcard.difficulty,
          'isFavorite': flashcard.isFavorite,
        });
      }
      
      await batch.commit();
      print('Successfully synced ${flashcards.length} flashcards to cloud');
    } catch (e) {
      print('Error syncing flashcards to cloud: $e');
    }
  }

  // UNION: Merge guest flashcards with cloud flashcards (no duplicates)
  Future<void> syncFlashcardsFromCloud() async {
    if (!isAuthenticated) return;
    
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('flashcards')
          .get();
      
      final cloudFlashcards = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return Flashcard(
          originalText: data['originalText'],
          translatedText: data['translatedText'],
          sourceLanguage: data['sourceLanguage'] ?? 'en-US',
          targetLanguage: data['targetLanguage'] ?? 'es-ES',
          createdAt: (data['createdAt'] as Timestamp).toDate(),
          lastStudied: (data['lastStudied'] as Timestamp).toDate(),
          timesStudied: data['timesStudied'] ?? 0,
          difficulty: data['difficulty'] ?? 2,
          isFavorite: data['isFavorite'] ?? false,
        );
      }).toList();
      
      // Get saved guest flashcards (not current flashcards)
      final prefs = await SharedPreferences.getInstance();
      final savedGuestFlashcardsJson = prefs.getStringList('latest_guest_flashcards') ?? [];
      final savedGuestFlashcards = <Flashcard>[];
      
      for (final flashcardJson in savedGuestFlashcardsJson) {
        try {
          final data = json.decode(flashcardJson);
          final flashcard = Flashcard(
            originalText: data['originalText'],
            translatedText: data['translatedText'],
            sourceLanguage: data['sourceLanguage'] ?? 'en-US',
            targetLanguage: data['targetLanguage'] ?? 'es-ES',
            createdAt: DateTime.parse(data['createdAt']),
            lastStudied: DateTime.parse(data['lastStudied']),
            timesStudied: data['timesStudied'] ?? 0,
            difficulty: data['difficulty'] ?? 2,
            isFavorite: data['isFavorite'] ?? false,
          );
          savedGuestFlashcards.add(flashcard);
        } catch (e) {
          print('Error parsing saved guest flashcard: $e');
        }
      }
      
      // UNION: Combine saved guest + cloud data (no duplicates)
      final unionFlashcards = <String, Flashcard>{};
      
      // Add saved guest flashcards first
      for (final flashcard in savedGuestFlashcards) {
        final key = '${flashcard.originalText}_${flashcard.translatedText}';
        unionFlashcards[key] = flashcard;
      }
      
      // Add cloud flashcards (they take precedence if duplicate)
      for (final flashcard in cloudFlashcards) {
        final key = '${flashcard.originalText}_${flashcard.translatedText}';
        unionFlashcards[key] = flashcard;
      }
      
      // Clear database and insert union (this is the combined data for signed-in mode)
      await _dbHelper.clearAllFlashcards();
      for (final flashcard in unionFlashcards.values) {
        await _dbHelper.insertFlashcard(flashcard);
      }
      
      print('✅ UNION: Combined ${savedGuestFlashcards.length} saved guest + ${cloudFlashcards.length} cloud flashcards = ${unionFlashcards.length} total');
    } catch (e) {
      print('Error syncing flashcards from cloud: $e');
    }
  }

  // Sync favorites to cloud
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
    }
  }

  // UNION: Merge guest favorites with cloud favorites (no duplicates)
  Future<void> syncFavoritesFromCloud() async {
    if (!isAuthenticated) return;
    
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      
      if (doc.exists && doc.data()!.containsKey('favorites')) {
        final cloudFavorites = List<String>.from(doc.data()!['favorites'] ?? []);
        
        // Get local favorites (guest data) - use the SAVED guest data, not current
        final prefs = await SharedPreferences.getInstance();
        final savedGuestFavorites = prefs.getStringList('latest_guest_favorite_phrases') ?? [];
        
        // UNION: Combine saved guest + cloud favorites (no duplicates)
        final unionFavorites = <String>{};
        unionFavorites.addAll(savedGuestFavorites);  // Add saved guest favorites
        unionFavorites.addAll(cloudFavorites);        // Add cloud favorites
        
        // Save union locally (this is the combined data for signed-in mode)
        await prefs.setStringList('favorite_phrases', unionFavorites.toList());
        
        print('✅ UNION: Combined ${savedGuestFavorites.length} saved guest + ${cloudFavorites.length} cloud favorites = ${unionFavorites.length} total');
      }
    } catch (e) {
      print('Error syncing favorites from cloud: $e');
    }
  }

  // Sync chat history to cloud
  Future<void> syncChatHistoryToCloud() async {
    if (!isAuthenticated) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final conversationsString = prefs.getString('conversations');
      
      if (conversationsString != null) {
        final conversationsData = json.decode(conversationsString);
        
        await _firestore
            .collection('users')
            .doc(userId)
            .set({
          'chatHistory': conversationsData,
          'lastModified': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        
        print('Successfully synced chat history to cloud');
      }
    } catch (e) {
      print('Error syncing chat history to cloud: $e');
    }
  }

  // UNION: Merge guest chat history with cloud chat history
  Future<void> syncChatHistoryFromCloud() async {
    if (!isAuthenticated) return;
    
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      
      if (doc.exists && doc.data()!.containsKey('chatHistory')) {
        final cloudChatHistory = doc.data()!['chatHistory'];
        
        // Get saved guest chat history (not current chat history)
        final prefs = await SharedPreferences.getInstance();
        final savedGuestConversationsString = prefs.getString('latest_guest_conversations');
        
        Map<String, dynamic> unionConversations = {};
        
        // Add saved guest conversations first
        if (savedGuestConversationsString != null) {
          try {
            final savedGuestConversations = json.decode(savedGuestConversationsString);
            if (savedGuestConversations is Map) {
              unionConversations.addAll(Map<String, dynamic>.from(savedGuestConversations));
            }
          } catch (e) {
            print('Error parsing saved guest conversations: $e');
          }
        }
        
        // Add cloud conversations (they don't overwrite guest conversations)
        if (cloudChatHistory != null && cloudChatHistory is Map) {
          for (final entry in cloudChatHistory.entries) {
            if (!unionConversations.containsKey(entry.key)) {
              unionConversations[entry.key] = entry.value;
            }
          }
        }
        
        // Save union locally (this is the combined data for signed-in mode)
        await prefs.setString('conversations', json.encode(unionConversations));
        
        final savedGuestCount = savedGuestConversationsString != null ? (json.decode(savedGuestConversationsString) as Map).length : 0;
        final cloudCount = cloudChatHistory is Map ? cloudChatHistory.length : 0;
        print('✅ UNION: Combined $savedGuestCount saved guest + $cloudCount cloud conversations = ${unionConversations.length} total');
      }
    } catch (e) {
      print('Error syncing chat history from cloud: $e');
    }
  }

  // === COMPREHENSIVE SYNC ===

  // Perform full sync when user logs in (UNION guest + cloud data)
  Future<void> performFullSync() async {
    if (!isAuthenticated) return;
    
    try {
      print('🔄 Starting full user data sync with UNION logic...');
      
      // STEP 1: Save LATEST guest data EVERY TIME before login
      await _saveLatestGuestData();
      
      // STEP 2: UNION guest data with cloud data
      await Future.wait([
        saveUserProfile(),
        syncFlashcardsFromCloud(),  // UNION guest + cloud flashcards
        syncFavoritesFromCloud(),   // UNION guest + cloud favorites
        syncChatHistoryFromCloud(), // UNION guest + cloud conversations
      ]).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('⏰ Sync from cloud timed out after 15 seconds, continuing...');
          return <void>[];
        },
      );
      
      // STEP 3: Save the merged data back to cloud
      await Future.wait([
        syncFlashcardsToCloud(),
        syncFavoritesToCloud(),
        syncChatHistoryToCloud(),
      ]).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('⏰ Sync to cloud timed out after 15 seconds, continuing...');
          return <void>[];
        },
      );
      
      // STEP 4: IMPORTANT - Save current union data as "signed_in" data
      await _saveSignedInData();
      
      // Update phrase service to reflect new favorites
      await _phraseService.initializeSampleData();
      
      print('✅ Full user data sync completed with UNION logic');
    } catch (e) {
      print('❌ Error during full sync: $e');
    }
  }

  // Save the current union data as "signed_in" data (separate from guest)
  Future<void> _saveSignedInData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save current union data to signed-in keys
      final currentFavorites = prefs.getStringList('favorite_phrases') ?? [];
      await prefs.setStringList('signed_in_favorite_phrases', currentFavorites);
      
      final currentConversations = prefs.getString('conversations');
      if (currentConversations != null) {
        await prefs.setString('signed_in_conversations', currentConversations);
      }
      
      final currentAiPhrases = prefs.getStringList('ai_phrases') ?? [];
      await prefs.setStringList('signed_in_ai_phrases', currentAiPhrases);
      
      // Save current flashcards to signed-in storage
      final flashcards = await _dbHelper.getAllFlashcards();
      final flashcardsJson = flashcards.map((f) => json.encode({
        'originalText': f.originalText,
        'translatedText': f.translatedText,
        'sourceLanguage': f.sourceLanguage,
        'targetLanguage': f.targetLanguage,
        'difficulty': f.difficulty,
        'createdAt': f.createdAt.toIso8601String(),
        'lastStudied': f.lastStudied.toIso8601String(),
        'timesStudied': f.timesStudied,
        'isFavorite': f.isFavorite,
      })).toList();
      await prefs.setStringList('signed_in_flashcards', flashcardsJson);
      
      print('💾 Saved union data as signed-in data');
    } catch (e) {
      print('❌ Error saving signed-in data: $e');
    }
  }

  // Restore LATEST guest data when user logs out
  Future<void> clearUserDataAndRestoreGuest() async {
    try {
      print('🔄 Clearing user data and restoring LATEST guest data...');
      
      // Restore the LATEST guest data (ignoring anything added while signed in)
      await _restoreLatestGuestData();
      
      print('✅ User data cleared and LATEST guest data restored');
    } catch (e) {
      print('❌ Error clearing user data and restoring guest: $e');
    }
  }

  // === AUTH LISTENER ===

  void setupAuthListener() {
    _auth.authStateChanges().listen((User? user) async {
      if (user != null) {
        // User logged in - UNION guest + cloud data
        print('👤 User logged in: ${user.email}');
        await performFullSync();
      } else {
        // User logged out - restore LATEST guest data
        print('👋 User logged out - restoring LATEST guest data');
        await clearUserDataAndRestoreGuest();
      }
    });
  }

  // === USER PROFILE DATA ===

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
    }
  }

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

  // === USER STATISTICS ===

  Future<Map<String, dynamic>> getUserStats() async {
    try {
      final stats = <String, dynamic>{
        'currentStreak': 0,
        'longestStreak': 0,
        'flashcardsCount': 0,
        'favoritesCount': 0,
        'chatsCount': 0,
      };

      // Get flashcards count
      final flashcards = await _dbHelper.getAllFlashcards();
      stats['flashcardsCount'] = flashcards.length;

      // Get favorites count
      final prefs = await SharedPreferences.getInstance();
      final favoritesList = prefs.getStringList('favorite_phrases') ?? [];
      stats['favoritesCount'] = favoritesList.length;

      // Get chats count
      final conversationsString = prefs.getString('conversations');
      if (conversationsString != null) {
        try {
          final conversationsData = json.decode(conversationsString);
          if (conversationsData is Map) {
            stats['chatsCount'] = conversationsData.length;
          }
        } catch (e) {
          print('Error parsing conversations: $e');
          stats['chatsCount'] = 0;
        }
      }

      // Get streak data from cloud if authenticated
      if (isAuthenticated) {
        try {
          final doc = await _firestore
              .collection('users')
              .doc(userId)
              .get();
          
          if (doc.exists) {
            final data = doc.data()!;
            stats['currentStreak'] = data['currentStreak'] ?? 0;
            stats['longestStreak'] = data['longestStreak'] ?? 0;
          }
        } catch (e) {
          print('Error getting streak data: $e');
        }
      }

      return stats;
    } catch (e) {
      print('Error getting user stats: $e');
      return {
        'currentStreak': 0,
        'longestStreak': 0,
        'flashcardsCount': 0,
        'favoritesCount': 0,
        'chatsCount': 0,
      };
    }
  }

  // === HELPER METHODS FOR OTHER SERVICES ===

  Future<void> addFavorite(String phraseId) async {
    if (isAuthenticated) {
      // When signed in, update current but don't save as guest data
      final prefs = await SharedPreferences.getInstance();
      final currentFavorites = prefs.getStringList('favorite_phrases') ?? [];
      if (!currentFavorites.contains(phraseId)) {
        currentFavorites.add(phraseId);
        await prefs.setStringList('favorite_phrases', currentFavorites);
      }
      
      // Force phrase service to reload favorites
      await _phraseService.initializeSampleData();
      await syncFavoritesToCloud();
      print('🔒 Signed-in user added favorite (will NOT affect guest data)');
    } else {
      // Guest mode - normal behavior
      await _phraseService.toggleFavorite(phraseId);
      print('👤 Guest user added favorite');
    }
  }

  Future<void> removeFavorite(String phraseId) async {
    if (isAuthenticated) {
      // When signed in, update current but don't save as guest data
      final prefs = await SharedPreferences.getInstance();
      final currentFavorites = prefs.getStringList('favorite_phrases') ?? [];
      currentFavorites.remove(phraseId);
      await prefs.setStringList('favorite_phrases', currentFavorites);
      
      // Force phrase service to reload favorites
      await _phraseService.initializeSampleData();
      await syncFavoritesToCloud();
      print('🔒 Signed-in user removed favorite (will NOT affect guest data)');
    } else {
      // Guest mode - normal behavior
      await _phraseService.toggleFavorite(phraseId);
      print('👤 Guest user removed favorite');
    }
  }

  // Wrapper for PhraseService toggleFavorite that handles authentication
  Future<void> toggleFavorite(String phraseId) async {
    final prefs = await SharedPreferences.getInstance();
    final currentFavorites = prefs.getStringList('favorite_phrases') ?? [];
    
    if (currentFavorites.contains(phraseId)) {
      await removeFavorite(phraseId);
    } else {
      await addFavorite(phraseId);
    }
  }

  Future<void> addFlashcard(Flashcard flashcard) async {
    await _dbHelper.insertFlashcard(flashcard);
    
    if (isAuthenticated) {
      // When signed in, also save to cloud AND update signed-in storage
      await syncFlashcardsToCloud();
      await _updateSignedInFlashcards();
    }
    // If guest mode, data will be automatically saved as latest guest data on next login
  }

  Future<void> updateFlashcard(Flashcard flashcard) async {
    await _dbHelper.updateFlashcard(flashcard);
    
    if (isAuthenticated) {
      // When signed in, also save to cloud AND update signed-in storage
      await syncFlashcardsToCloud();
      await _updateSignedInFlashcards();
    }
    // If guest mode, data will be automatically saved as latest guest data on next login
  }

  Future<void> removeFlashcard(Flashcard flashcard) async {
    if (flashcard.id != null) {
      await _dbHelper.deleteFlashcardById(flashcard.id!);
    } else {
      await _dbHelper.deleteFlashcard(flashcard.originalText, flashcard.translatedText);
    }
    
    if (isAuthenticated) {
      // When signed in, also save to cloud AND update signed-in storage
      await syncFlashcardsToCloud();
      await _updateSignedInFlashcards();
    }
    // If guest mode, data will be automatically saved as latest guest data on next login
  }

  Future<void> deleteFlashcard(Flashcard flashcard) async {
    await removeFlashcard(flashcard);
  }

  // Update signed-in storage when favorites change
  Future<void> _updateSignedInFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentFavorites = prefs.getStringList('favorite_phrases') ?? [];
      await prefs.setStringList('signed_in_favorite_phrases', currentFavorites);
      print('💾 Updated signed-in favorites storage');
    } catch (e) {
      print('❌ Error updating signed-in favorites: $e');
    }
  }

  // Update signed-in storage when flashcards change
  Future<void> _updateSignedInFlashcards() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final flashcards = await _dbHelper.getAllFlashcards();
      final flashcardsJson = flashcards.map((f) => json.encode({
        'originalText': f.originalText,
        'translatedText': f.translatedText,
        'sourceLanguage': f.sourceLanguage,
        'targetLanguage': f.targetLanguage,
        'difficulty': f.difficulty,
        'createdAt': f.createdAt.toIso8601String(),
        'lastStudied': f.lastStudied.toIso8601String(),
        'timesStudied': f.timesStudied,
        'isFavorite': f.isFavorite,
      })).toList();
      await prefs.setStringList('signed_in_flashcards', flashcardsJson);
      print('💾 Updated signed-in flashcards storage');
    } catch (e) {
      print('❌ Error updating signed-in flashcards: $e');
    }
  }
}