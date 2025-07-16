import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'phrase_service.dart';
import 'sync_status_service.dart';
import '../utils/database_helper.dart';
import '../models/flashcard_model.dart';
import '../models/spaced_repetition_model.dart';
import 'package:hive/hive.dart';

class UserDataService {
  static final UserDataService _instance = UserDataService._internal();
  factory UserDataService() => _instance;
  UserDataService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final PhraseService _phraseService = PhraseService();
  final SyncStatusService _syncStatusService = SyncStatusService();

  // 🚀 AUTO-SYNC & CLOUD POLLING - NO CIRCULAR DEPENDENCIES
  Timer? _syncMonitorTimer;
  Timer? _cloudPollTimer;
  bool _isMonitoring = false;

  // Get current user
  User? get currentUser => _auth.currentUser;
  bool get isAuthenticated => currentUser != null;
  String? get userId => currentUser?.uid;

  // 🚀 START FULL MONITORING (sync + cloud polling)
  void startSyncMonitoring() {
    if (_isMonitoring) return;
    
    _isMonitoring = true;
    
    // 🆕 REMOVED: Aggressive auto-sync timer - now only syncs on user actions
    // Sync happens automatically when user performs actions (add flashcard, complete review, etc.)
  }

  // 🛑 STOP ALL MONITORING
  void stopSyncMonitoring() {
    _syncMonitorTimer?.cancel();
    _cloudPollTimer?.cancel();
    _syncMonitorTimer = null;
    _cloudPollTimer = null;
    _isMonitoring = false;
  }

  // 🔍 CHECK FOR SYNC FLAGS AND PUSH TO CLOUD
  Future<void> _checkAndPerformAutoSync() async {
    if (!isAuthenticated) return;
    
    try {
      // Check network connectivity first
      try {
        final result = await InternetAddress.lookup('google.com');
        if (result.isEmpty || result[0].rawAddress.isEmpty) {
          return; // Skip sync if no internet
        }
      } catch (e) {
        return; // Skip sync if no internet
      }
      
      final prefs = await SharedPreferences.getInstance();
      
      // Check if favorites need sync
      final favoritesNeedSync = prefs.getBool('favorites_need_sync') ?? false;
      if (favoritesNeedSync) {
        print('🔄 Auto-syncing favorites to cloud...');
        await syncFavoritesToCloud();
        await prefs.setBool('favorites_need_sync', false); // Clear flag
        print('✅ Auto-synced favorites to cloud');
      }
      
      // Check if AI phrases need sync
      final aiPhrasesNeedSync = prefs.getBool('ai_phrases_need_sync') ?? false;
      if (aiPhrasesNeedSync) {
        print('🔄 Auto-syncing AI phrases to cloud...');
        await syncAiPhrasesToCloud();
        await prefs.setBool('ai_phrases_need_sync', false); // Clear flag
        print('✅ Auto-synced AI phrases to cloud');
      }
      
      // Check if we need to poll cloud for updates
      final needCloudPoll = prefs.getBool('need_cloud_poll') ?? false;
      if (needCloudPoll) {
        await prefs.setBool('need_cloud_poll', false); // Clear flag
        // Don't poll immediately, let the cloud poll timer handle it
      }
    } catch (e) {
      print('❌ Error in auto-sync monitoring: $e');
    }
  }

  // 🆕 POLL CLOUD FOR UPDATES FROM OTHER DEVICES
  Future<void> _pollCloudForUpdates() async {
    if (!isAuthenticated) return;
    
    try {
      // Check network connectivity first
      try {
        final result = await InternetAddress.lookup('google.com');
        if (result.isEmpty || result[0].rawAddress.isEmpty) {
          print('🌐 No internet connection - skipping cloud poll');
          return;
        }
      } catch (e) {
        print('🌐 No internet connection - skipping cloud poll');
        return;
      }
      
      print('🔍 Polling cloud for updates from other devices...');
      
      // Add timeout to prevent hanging - reduced from 5 to 3 seconds
      final doc = await _firestore.collection('users').doc(userId).get().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          print('⏰ Cloud polling timed out - skipping this cycle');
          throw TimeoutException('Cloud polling timed out');
        },
      );
      
      if (!doc.exists) {
        print('📭 No cloud data found');
        return;
      }
      
      final cloudData = doc.data()!;
      final prefs = await SharedPreferences.getInstance();
      
      // Check cloud timestamps vs local timestamps
      bool hasUpdates = false;
      
      // Check favorites timestamp
      if (cloudData.containsKey('favoritesLastModified') && cloudData['favoritesLastModified'] != null) {
        final cloudFavoritesTime = (cloudData['favoritesLastModified'] as Timestamp).millisecondsSinceEpoch;
        final localFavoritesTime = prefs.getInt('favorites_last_modified') ?? 0;
        
        if (cloudFavoritesTime > localFavoritesTime) {
          print('🔄 Cloud has newer favorites (cloud: $cloudFavoritesTime > local: $localFavoritesTime)');
          await _pullFavoritesFromCloud(cloudData);
          await prefs.setInt('favorites_last_modified', cloudFavoritesTime);
          hasUpdates = true;
        }
      }
      
      // 🎯 FIXED: Check AI phrases timestamp
      if (cloudData.containsKey('aiPhrasesLastModified') && cloudData['aiPhrasesLastModified'] != null) {
        final cloudAiPhrasesTime = (cloudData['aiPhrasesLastModified'] as Timestamp).millisecondsSinceEpoch;
        final localAiPhrasesTime = prefs.getInt('ai_phrases_last_modified') ?? 0;
        
        if (cloudAiPhrasesTime > localAiPhrasesTime) {
          print('🔄 Cloud has newer AI phrases (cloud: $cloudAiPhrasesTime > local: $localAiPhrasesTime)');
          await _pullAiPhrasesFromCloud(cloudData);
          await prefs.setInt('ai_phrases_last_modified', cloudAiPhrasesTime);
          hasUpdates = true;
        }
      }
      
      if (hasUpdates) {
        // Refresh phrase service to reflect cloud updates
        await _phraseService.forceRefreshFromDisk();
        print('✅ Applied cloud updates to local data');
      } else {
        print('✅ Local data is up to date');
      }
      
    } on TimeoutException {
      print('⏰ Cloud polling timed out - will retry later');
    } catch (e) {
      print('❌ Error polling cloud for updates: $e');
      // Don't let network errors crash the app - just log and continue
    }
  }

  // 🆕 PULL FAVORITES FROM CLOUD (when cloud has newer data)
  Future<void> _pullFavoritesFromCloud(Map<String, dynamic> cloudData) async {
    try {
      if (cloudData.containsKey('favorites')) {
        final cloudFavorites = List<String>.from(cloudData['favorites'] ?? []);
        final prefs = await SharedPreferences.getInstance();
        
        // Update active favorites (don't merge, just replace with cloud data)
        await prefs.setStringList('favorite_phrases', cloudFavorites);
        await prefs.setStringList('signed_in_favorite_phrases', cloudFavorites);
        
        print('📥 Pulled ${cloudFavorites.length} favorites from cloud');
      }
    } catch (e) {
      print('❌ Error pulling favorites from cloud: $e');
    }
  }

  // 🎯 FIXED: PULL FULL AI PHRASE OBJECTS FROM CLOUD (not just IDs)
  Future<void> _pullAiPhrasesFromCloud(Map<String, dynamic> cloudData) async {
    try {
      if (cloudData.containsKey('aiPhrases')) {
        final cloudAiPhrasesData = List<Map<String, dynamic>>.from(cloudData['aiPhrases'] ?? []);
        
        // Convert cloud data to JSON strings (format expected by phrase service)
        final cloudAiPhrasesJson = cloudAiPhrasesData.map((phraseData) => json.encode(phraseData)).toList();
        
        final prefs = await SharedPreferences.getInstance();
        
        // Update active AI phrases (replace with cloud data)
        await prefs.setStringList('ai_phrases', cloudAiPhrasesJson);
        await prefs.setStringList('signed_in_ai_phrases', cloudAiPhrasesJson);
        
        // 🎯 CRITICAL: Update phrase service with cloud AI phrases
        await _phraseService.updateAiPhrasesFromSync(cloudAiPhrasesJson);
        
        print('📥 Pulled ${cloudAiPhrasesJson.length} full AI phrase objects from cloud');
      }
    } catch (e) {
      print('❌ Error pulling AI phrases from cloud: $e');
    }
  }

  // 🆕 STARTUP CLOUD SYNC - Pull latest data when app starts
  Future<void> performStartupCloudSync() async {
    if (!isAuthenticated) return;
    
    try {
      print('🚀 Performing startup cloud sync...');
      
      // Check network connectivity first
      try {
        final result = await InternetAddress.lookup('google.com');
        if (result.isEmpty || result[0].rawAddress.isEmpty) {
          print('🌐 No internet - skipping startup cloud sync');
          return;
        }
      } catch (_) {
        print('🌐 No internet - skipping startup cloud sync');
        return;
      }
      
      // Add timeout to prevent hanging on startup
      final doc = await _firestore.collection('users').doc(userId).get().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          print('⏰ Startup cloud sync timed out - continuing without cloud data');
          throw TimeoutException('Startup cloud sync timed out');
        },
      );
      
      if (!doc.exists) {
        print('📭 No cloud data found on startup');
        return;
      }
      
      final cloudData = doc.data()!;
      
      // Always pull latest data from cloud on startup
      await _pullFavoritesFromCloud(cloudData);
      await _pullAiPhrasesFromCloud(cloudData);
      
      // Update local timestamps
      final prefs = await SharedPreferences.getInstance();
      if (cloudData.containsKey('favoritesLastModified') && cloudData['favoritesLastModified'] != null) {
        final cloudFavoritesTime = (cloudData['favoritesLastModified'] as Timestamp).millisecondsSinceEpoch;
        await prefs.setInt('favorites_last_modified', cloudFavoritesTime);
      }
      if (cloudData.containsKey('aiPhrasesLastModified') && cloudData['aiPhrasesLastModified'] != null) {
        final cloudAiPhrasesTime = (cloudData['aiPhrasesLastModified'] as Timestamp).millisecondsSinceEpoch;
        await prefs.setInt('ai_phrases_last_modified', cloudAiPhrasesTime);
      }
      
      // Refresh phrase service
      await _phraseService.forceRefreshFromDisk();
      
      print('✅ Startup cloud sync completed');
    } on TimeoutException {
      print('⏰ Startup cloud sync timed out - app will continue with local data');
    } catch (e) {
      print('❌ Error in startup cloud sync: $e');
      // Don't let cloud sync errors prevent app startup
    }
  }

  // === 🔧 CONTEXT SWITCHING (FIXED SHARED FAVORITES ISSUE) ===
  
  /// Switch to guest context - makes guest favorites active
  Future<void> _switchToGuestContext() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // If signed-in, save current signed-in data first
      if (isAuthenticated) {
        final currentFavorites = prefs.getStringList('favorite_phrases') ?? [];
        await prefs.setStringList('signed_in_favorite_phrases', currentFavorites);
        print('💾 Saved signed-in favorites before switching to guest context');
        
        final currentAiPhrases = prefs.getStringList('ai_phrases') ?? [];
        await prefs.setStringList('signed_in_ai_phrases', currentAiPhrases);
        print('💾 Saved signed-in AI phrases before switching to guest context');
      }
      
      // Load guest data and make them active
      final guestFavorites = prefs.getStringList('guest_favorite_phrases') ?? [];
      await prefs.setStringList('favorite_phrases', guestFavorites);
      
      final guestAiPhrases = prefs.getStringList('guest_ai_phrases') ?? [];
      await prefs.setStringList('ai_phrases', guestAiPhrases);
      
      // Force phrase service to reload with guest data
      await _phraseService.forceRefreshFromDisk();
      
      print('👤 Switched to GUEST context with ${guestFavorites.length} favorites and ${guestAiPhrases.length} AI phrases');
    } catch (e) {
      print('❌ Error switching to guest context: $e');
    }
  }
  
  /// Switch to signed-in context - makes signed-in data active
  Future<void> _switchToSignedInContext() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save current guest data first
      final currentFavorites = prefs.getStringList('favorite_phrases') ?? [];
      await prefs.setStringList('guest_favorite_phrases', currentFavorites);
      print('💾 Saved guest favorites before switching to signed-in context');
      
      final currentAiPhrases = prefs.getStringList('ai_phrases') ?? [];
      await prefs.setStringList('guest_ai_phrases', currentAiPhrases);
      print('💾 Saved guest AI phrases before switching to signed-in context');
      
      // Load signed-in data and make them active
      final signedInFavorites = prefs.getStringList('signed_in_favorite_phrases') ?? [];
      await prefs.setStringList('favorite_phrases', signedInFavorites);
      
      final signedInAiPhrases = prefs.getStringList('signed_in_ai_phrases') ?? [];
      await prefs.setStringList('ai_phrases', signedInAiPhrases);
      
      // Force phrase service to reload with signed-in data
      await _phraseService.forceRefreshFromDisk();
      
      print('🔒 Switched to SIGNED-IN context with ${signedInFavorites.length} favorites and ${signedInAiPhrases.length} AI phrases');
    } catch (e) {
      print('❌ Error switching to signed-in context: $e');
    }
  }

  // === 🔧 GUEST DATA MANAGEMENT (PRESERVED WORKING LOGIC) ===
  
  // Save LATEST guest data EVERY TIME before user logs in
  Future<void> _saveLatestGuestData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      print('🔄 Saving LATEST guest data before login...');
      
      // Save current favorites as LATEST guest favorites
      final currentFavorites = prefs.getStringList('guest_favorite_phrases') ?? [];
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
      
      // Save current AI phrases as LATEST guest data
      final currentAiPhrases = prefs.getStringList('guest_ai_phrases') ?? [];
      await prefs.setStringList('latest_guest_ai_phrases', currentAiPhrases);
      print('💾 Saved ${currentAiPhrases.length} guest AI phrases');
      
      // Save current flashcards as LATEST guest flashcards
      final flashcards = await _dbHelper.getAllFlashcards();
      final flashcardsJson = flashcards.map((f) => json.encode({
        'uuid': f.uuid,
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
      await prefs.setStringList('guest_favorite_phrases', latestGuestFavorites);
      await prefs.setStringList('favorite_phrases', latestGuestFavorites); // Make active
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
      await prefs.setStringList('guest_ai_phrases', latestGuestAiPhrases);
      await prefs.setStringList('ai_phrases', latestGuestAiPhrases); // Make active
      print('📱 FORCE restored ${latestGuestAiPhrases.length} guest AI phrases');
      
      // FORCE restore LATEST guest flashcards to database (overwrite any signed-in changes)
      await _dbHelper.clearAllFlashcards(); // Clear ALL current flashcards
      final latestGuestFlashcardsJson = prefs.getStringList('latest_guest_flashcards') ?? [];
      for (final flashcardJson in latestGuestFlashcardsJson) {
        try {
          final data = json.decode(flashcardJson);
          final flashcard = Flashcard(
            uuid: data['uuid'],
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
      await _phraseService.forceRefreshFromDisk();
      
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

  // === ☁️ CLOUD SYNC METHODS (PRESERVED WORKING FLASHCARD BEHAVIOR) ===

  // Sync flashcards to cloud (PRESERVED EXACTLY AS WORKING)
  Future<void> syncFlashcardsToCloud() async {
    if (!isAuthenticated) return;
    _syncStatusService.updateStatus(SyncStatus.syncing);
    try {
      final localFlashcards = await _dbHelper.getAllFlashcards();
      final collection =
          _firestore.collection('users').doc(userId).collection('flashcards');

      // Get all cloud flashcard UUIDs first
      final cloudQuery = await collection.get();
      final cloudFlashcardUuids = cloudQuery.docs.map((doc) => doc.id).toSet();

      final batch = _firestore.batch();
      final localFlashcardUuids = <String>{};

      // Batch write all local flashcards to the cloud using UUID as document ID
      for (final flashcard in localFlashcards) {
        localFlashcardUuids.add(flashcard.uuid);
        final docRef = collection.doc(flashcard.uuid);
        batch.set(docRef, flashcard.toMap());
      }

      // Find UUIDs that are in the cloud but not locally, and delete them
      final uuidsToDelete = cloudFlashcardUuids.difference(localFlashcardUuids);
      for (final uuid in uuidsToDelete) {
        final docRef = collection.doc(uuid);
        batch.delete(docRef);
      }

      await batch.commit();
      _syncStatusService.updateStatus(SyncStatus.synced);
      print('☁️ Synced ${localFlashcards.length} flashcards to cloud. Deleted ${uuidsToDelete.length} stale cards.');
    } catch (e) {
      _syncStatusService.updateStatus(SyncStatus.error);
      print('❌ Error syncing flashcards to cloud: $e');
    }
  }

  // UNION: Merge guest flashcards with cloud flashcards (PRESERVED EXACTLY AS WORKING)
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
          uuid: doc.id,
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
            uuid: data['uuid'],
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
        unionFlashcards[flashcard.uuid] = flashcard;
      }
      
      // Add cloud flashcards (they take precedence if duplicate)
      for (final flashcard in cloudFlashcards) {
        unionFlashcards[flashcard.uuid] = flashcard;
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

  // 🎯 FIXED: Sync favorites to cloud with timestamp
  Future<void> syncFavoritesToCloud() async {
    if (!isAuthenticated) return;
    _syncStatusService.updateStatus(SyncStatus.syncing);
    try {
      final prefs = await SharedPreferences.getInstance();
      final signedInFavorites = prefs.getStringList('signed_in_favorite_phrases') ?? [];
      
      await _firestore
          .collection('users')
          .doc(userId)
          .set({
        'favorites': signedInFavorites,
        'favoritesLastModified': FieldValue.serverTimestamp(),
        'lastModified': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      _syncStatusService.updateStatus(SyncStatus.synced);
      print('☁️ Synced ${signedInFavorites.length} SIGNED-IN favorites to cloud with timestamp');
    } catch (e) {
      _syncStatusService.updateStatus(SyncStatus.error);
      print('❌ Error syncing favorites to cloud: $e');
    }
  }

  // 🎯 FIXED: Load favorites from cloud (SIGNED-IN CONTEXT ONLY)
  Future<void> syncFavoritesFromCloud() async {
    if (!isAuthenticated) return;
    
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      
      if (doc.exists && doc.data()!.containsKey('favorites')) {
        final cloudFavorites = List<String>.from(doc.data()!['favorites'] ?? []);
        
        // Get saved guest favorites (for UNION)
        final prefs = await SharedPreferences.getInstance();
        final savedGuestFavorites = prefs.getStringList('latest_guest_favorite_phrases') ?? [];
        
        // UNION: Combine saved guest + cloud favorites (no duplicates)
        final unionFavorites = <String>{};
        unionFavorites.addAll(savedGuestFavorites);  // Add saved guest favorites
        unionFavorites.addAll(cloudFavorites);        // Add cloud favorites
        
        // Store as signed-in favorites (separate from guest)
        await prefs.setStringList('signed_in_favorite_phrases', unionFavorites.toList());
        await prefs.setStringList('favorite_phrases', unionFavorites.toList()); // Make active
        
        print('✅ UNION: Combined ${savedGuestFavorites.length} saved guest + ${cloudFavorites.length} cloud favorites = ${unionFavorites.length} total SIGNED-IN favorites');
      } else {
        print('ℹ️ No cloud favorites found');
      }
    } catch (e) {
      print('❌ Error loading favorites from cloud: $e');
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

  // 🎯 FIXED: Sync FULL AI phrase objects to cloud (not just IDs)
  Future<void> syncAiPhrasesToCloud() async {
    if (!isAuthenticated) return;
    _syncStatusService.updateStatus(SyncStatus.syncing);
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get full AI phrase objects (JSON strings)
      final signedInAiPhrasesJson = prefs.getStringList('signed_in_ai_phrases') ?? [];
      
      // Convert JSON strings to objects for cloud storage
      final signedInAiPhrasesData = signedInAiPhrasesJson.map((phraseJson) {
        try {
          return json.decode(phraseJson) as Map<String, dynamic>;
        } catch (e) {
          print('Error parsing AI phrase for cloud sync: $e');
          return null;
        }
      }).where((data) => data != null).cast<Map<String, dynamic>>().toList();
      
      await _firestore
          .collection('users')
          .doc(userId)
          .set({
        'aiPhrases': signedInAiPhrasesData, // Store full objects
        'aiPhrasesLastModified': FieldValue.serverTimestamp(),
        'lastModified': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      _syncStatusService.updateStatus(SyncStatus.synced);
      print('☁️ Synced ${signedInAiPhrasesData.length} full AI phrase objects to cloud with timestamp');
    } catch (e) {
      _syncStatusService.updateStatus(SyncStatus.error);
      print('❌ Error syncing AI phrases to cloud: $e');
    }
  }

  // 🎯 FIXED: Load FULL AI phrase objects from cloud (not just IDs)
  Future<void> syncAiPhrasesFromCloud() async {
    if (!isAuthenticated) return;
    
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      
      if (doc.exists && doc.data()!.containsKey('aiPhrases')) {
        final cloudAiPhrasesData = List<Map<String, dynamic>>.from(doc.data()!['aiPhrases'] ?? []);
        
        // Get saved guest AI phrases (for UNION)
        final prefs = await SharedPreferences.getInstance();
        final savedGuestAiPhrasesJson = prefs.getStringList('latest_guest_ai_phrases') ?? [];
        
        // Convert cloud data to JSON strings for consistency
        final cloudAiPhrasesJson = cloudAiPhrasesData.map((phraseData) => json.encode(phraseData)).toList();
        
        // UNION: Combine saved guest + cloud AI phrases (no duplicates by ID)
        final unionAiPhrasesMap = <String, String>{}; // Map of ID -> JSON
        
        // Add saved guest AI phrases first
        for (final phraseJson in savedGuestAiPhrasesJson) {
          try {
            final phraseData = json.decode(phraseJson);
            final phraseId = phraseData['id'];
            if (phraseId != null) {
              unionAiPhrasesMap[phraseId] = phraseJson;
            }
          } catch (e) {
            print('Error parsing guest AI phrase: $e');
          }
        }
        
        // Add cloud AI phrases (they take precedence if duplicate ID)
        for (final phraseJson in cloudAiPhrasesJson) {
          try {
            final phraseData = json.decode(phraseJson);
            final phraseId = phraseData['id'];
            if (phraseId != null) {
              unionAiPhrasesMap[phraseId] = phraseJson;
            }
          } catch (e) {
            print('Error parsing cloud AI phrase: $e');
          }
        }
        
        final unionAiPhrasesJson = unionAiPhrasesMap.values.toList();
        
        // Store as signed-in AI phrases (separate from guest)
        await prefs.setStringList('signed_in_ai_phrases', unionAiPhrasesJson);
        await prefs.setStringList('ai_phrases', unionAiPhrasesJson); // Make active
        
        // Update phrase service with union data
        await _phraseService.updateAiPhrasesFromSync(unionAiPhrasesJson);
        
        print('✅ UNION: Combined ${savedGuestAiPhrasesJson.length} guest + ${cloudAiPhrasesJson.length} cloud AI phrases = ${unionAiPhrasesJson.length} total');
      } else {
        print('ℹ️ No cloud AI phrases found');
      }
    } catch (e) {
      print('❌ Error loading AI phrases from cloud: $e');
    }
  }

  // === 🔄 COMPREHENSIVE SYNC ===

  // Perform full sync when user logs in (UNION guest + cloud data)
  Future<void> performFullSync() async {
    if (!isAuthenticated) return;
    _syncStatusService.updateStatus(SyncStatus.syncing);
    try {
      print('🔄 Starting full user data sync with UNION logic...');
      
      // STEP 1: Save LATEST guest data EVERY TIME before login
      await _saveLatestGuestData();
      
      // STEP 2: Switch to signed-in context
      await _switchToSignedInContext();
      
      // STEP 3: UNION guest data with cloud data (with timeout)
      try {
        await Future.wait([
          saveUserProfile(),
          syncFlashcardsFromCloud(),  // UNION guest + cloud flashcards
          syncFavoritesFromCloud(),   // UNION guest + cloud favorites
          syncAiPhrasesFromCloud(),   // UNION guest + cloud AI phrases
          syncChatHistoryFromCloud(), // UNION guest + cloud conversations
        ]).timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            print('⏰ Sync from cloud timed out after 15 seconds, continuing...');
            return <void>[];
          },
        );
      } catch (e) {
        print('⚠️ Cloud sync failed, continuing with local data: $e');
      }
      
      // STEP 4: Save the merged data back to cloud (with timeout)
      try {
        await Future.wait([
          syncFlashcardsToCloud(),
          syncFavoritesToCloud(),
          syncAiPhrasesToCloud(),     // Sync AI phrases to cloud
          syncChatHistoryToCloud(),
        ]).timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            print('⏰ Sync to cloud timed out after 15 seconds, continuing...');
            return <void>[];
          },
        );
      } catch (e) {
        print('⚠️ Cloud sync failed, continuing with local data: $e');
      }
      
      // STEP 5: IMPORTANT - Save current union data as "signed_in" data
      await _saveSignedInData();
      
      // STEP 6: 🚀 Start auto-sync monitoring + cloud polling
      startSyncMonitoring();
      
      // 🆕 REMOVED: Startup cloud sync - app starts immediately with local data
      // Cloud sync happens automatically when user performs actions
      
      // Update phrase service to reflect new favorites
      await _phraseService.forceRefreshFromDisk();
      
      _syncStatusService.updateStatus(SyncStatus.synced);
      print('✅ Full user data sync completed with UNION logic + auto-sync + cloud polling started');
    } catch (e) {
      _syncStatusService.updateStatus(SyncStatus.error);
      print('❌ Error during full sync: $e');
      // Don't let sync errors prevent app from working
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
        'uuid': f.uuid,
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
      
      // 🛑 Stop auto-sync monitoring + cloud polling
      stopSyncMonitoring();
      
      // Restore the LATEST guest data (ignoring anything added while signed in)
      await _restoreLatestGuestData();
      
      // Switch back to guest context
      await _switchToGuestContext();
      
      print('✅ User data cleared and LATEST guest data restored');
    } catch (e) {
      print('❌ Error clearing user data and restoring guest: $e');
    }
  }

  // Central method to clear all user data (future-proof for all features)
  Future<void> clearAllUserData() async {
    print('[UserDataService] Clearing all user data...');
    // Stop background sync/listeners
    stopSyncMonitoring();

    // Clear local storage (Hive, SharedPreferences, etc.)
    try {
      // Clear Hive boxes (add more as needed)
      await Hive.deleteFromDisk();
    } catch (e) {
      print('[UserDataService] Error clearing Hive: $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      print('[UserDataService] Error clearing SharedPreferences: $e');
    }

    // Clear local database
    try {
      await _dbHelper.clearAllFlashcards();
      await _clearAllConversationsAndMessages();
    } catch (e) {
      print('[UserDataService] Error clearing database: $e');
    }

    print('[UserDataService] All user data cleared.');
  }

  // Method to clear provider states (called from auth provider)
  static void clearProviderStates() {
    print('[UserDataService] Clearing provider states...');
    // This will be called by the auth provider to clear in-memory provider states
    // The actual clearing is done in the auth provider where we have access to the provider context
  }

  // === 🔄 AUTH LISTENER ===

  void setupAuthListener() {
    _auth.authStateChanges().listen((User? user) async {
      if (user != null) {
        // User logged in - UNION guest + cloud data + start monitoring + cloud polling
        print('👤 User logged in: ${user.email}');
        await performFullSync();
      } else {
        // User logged out - restore LATEST guest data + stop monitoring
        print('👋 User logged out - restoring LATEST guest data');
        await clearUserDataAndRestoreGuest();
      }
    });
  }

  // === 👤 USER PROFILE DATA ===

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

  // === 📊 USER STATISTICS ===

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
              .get()
              .timeout(
                Duration(seconds: 10),
                onTimeout: () {
                  throw TimeoutException('Failed to fetch user stats from cloud');
                },
              );
          
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
      print('[UserDataService] Error getting user stats: $e');
      return {
        'currentStreak': 0,
        'longestStreak': 0,
        'flashcardsCount': 0,
        'favoritesCount': 0,
        'chatsCount': 0,
      };
    }
  }

  // === 🎯 FIXED FAVORITES MANAGEMENT (SEPARATE CONTEXTS) ===

  Future<void> addFavorite(String phraseId) async {
    if (isAuthenticated) {
      final prefs = await SharedPreferences.getInstance();
      final signedInFavorites = prefs.getStringList('signed_in_favorite_phrases') ?? [];
      if (!signedInFavorites.contains(phraseId)) {
        signedInFavorites.add(phraseId);
        await saveFavoritesLocally(signedInFavorites);
      }
      await _phraseService.forceRefreshFromDisk();
      await prefs.setBool('favorites_need_sync', true);
      print('🔒 Signed-in user added favorite - flagged for sync');
      scheduleFavoritesSync();
      print('[SYNC] Favorites sync scheduled after add');
    } else {
      final prefs = await SharedPreferences.getInstance();
      final guestFavorites = prefs.getStringList('guest_favorite_phrases') ?? [];
      if (!guestFavorites.contains(phraseId)) {
        guestFavorites.add(phraseId);
        await prefs.setStringList('guest_favorite_phrases', guestFavorites);
        await prefs.setStringList('favorite_phrases', guestFavorites);
      }
      await _phraseService.forceRefreshFromDisk();
      print('👤 Guest user added favorite - stays local');
    }
  }

  Future<void> removeFavorite(String phraseId) async {
    if (isAuthenticated) {
      final prefs = await SharedPreferences.getInstance();
      final signedInFavorites = prefs.getStringList('signed_in_favorite_phrases') ?? [];
      signedInFavorites.remove(phraseId);
      await saveFavoritesLocally(signedInFavorites);
      await _phraseService.forceRefreshFromDisk();
      await prefs.setBool('favorites_need_sync', true);
      print('🔒 Signed-in user removed favorite - flagged for sync');
      scheduleFavoritesSync();
      print('[SYNC] Favorites sync scheduled after remove');
    } else {
      final prefs = await SharedPreferences.getInstance();
      final guestFavorites = prefs.getStringList('guest_favorite_phrases') ?? [];
      guestFavorites.remove(phraseId);
      await prefs.setStringList('guest_favorite_phrases', guestFavorites);
      await prefs.setStringList('favorite_phrases', guestFavorites);
      await _phraseService.forceRefreshFromDisk();
      print('👤 Guest user removed favorite - stays local');
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

  // === 🃏 FLASHCARD METHODS (PRESERVED EXACTLY AS WORKING) ===

  Future<void> addFlashcard(Flashcard flashcard) async {
    await _dbHelper.insertFlashcard(flashcard);
    print('[SYNC] addFlashcard called');
    if (isAuthenticated) {
      // When signed in, also save to cloud AND update signed-in storage
      scheduleFlashcardSync();
      await _updateSignedInFlashcards();
      print('[SYNC] Flashcard sync scheduled after add');
    }
    // If guest mode, data will be automatically saved as latest guest data on next login
  }

  Future<void> updateFlashcard(Flashcard flashcard) async {
    await _dbHelper.updateFlashcard(flashcard);
    print('[SYNC] updateFlashcard called');
    if (isAuthenticated) {
      // When signed in, also save to cloud AND update signed-in storage
      scheduleFlashcardSync();
      await _updateSignedInFlashcards();
      print('[SYNC] Flashcard sync scheduled after update');
    }
    // If guest mode, data will be automatically saved as latest guest data on next login
  }

  Future<void> removeFlashcard(Flashcard flashcard) async {
    if (flashcard.id != null) {
      await _dbHelper.deleteFlashcardById(flashcard.id!);
    } else {
      await _dbHelper.deleteFlashcardByUuid(flashcard.uuid);
    }
    print('[SYNC] removeFlashcard called');
    if (isAuthenticated) {
      // When signed in, also save to cloud AND update signed-in storage
      scheduleFlashcardSync();
      await _updateSignedInFlashcards();
      print('[SYNC] Flashcard sync scheduled after remove');
    }
    // If guest mode, data will be automatically saved as latest guest data on next login
  }

  Future<void> deleteFlashcard(Flashcard flashcard) async {
    await removeFlashcard(flashcard);
  }

  // Update signed-in storage when flashcards change
  Future<void> _updateSignedInFlashcards() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final flashcards = await _dbHelper.getAllFlashcards();
      final flashcardsJson = flashcards.map((f) => json.encode({
        'uuid': f.uuid,
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

  // === NEW: Spaced-repetition sync ===

  Future<void> syncSrsToCloud() async {
    if (!isAuthenticated) return;
    try {
      final spacedCards = await _dbHelper.getAllSpacedRepetitionCards();
      final flashcards = await _dbHelper.getAllFlashcards();
      final uuidById = {for (final f in flashcards) f.id!: f.uuid};

      final col = _firestore.collection('users').doc(userId).collection('spacedRepetition');

      final cloudDocs = await col.get();
      final cloudIds = cloudDocs.docs.map((d) => d.id).toSet();

      final batch = _firestore.batch();
      final localIds = <String>{};

      for (final card in spacedCards) {
        final uuid = uuidById[card.flashcardId];
        if (uuid == null) continue; // Orphan
        localIds.add(uuid);
        batch.set(col.doc(uuid), card.toFirestore());
      }

      for (final id in cloudIds.difference(localIds)) {
        batch.delete(col.doc(id));
      }

      await batch.commit();
    } catch (e) {
      print('❌ Error syncing SRS to cloud: $e');
    }
  }

  Future<void> syncSrsFromCloud() async {
    if (!isAuthenticated) return;
    try {
      final snapshot = await _firestore.collection('users').doc(userId).collection('spacedRepetition').get();
      if (snapshot.docs.isEmpty) return;

      for (final doc in snapshot.docs) {
        final uuid = doc.id;
        final flash = await _dbHelper.getFlashcardByUuid(uuid);
        if (flash == null) continue;
        final srs = SpacedRepetitionCard.fromFirestore(doc.data(), flash.id!);
        await _dbHelper.upsertSpacedRepetitionCard(srs);
      }
    } catch (e) {
      print('❌ Error syncing SRS from cloud: $e');
    }
  }

  Timer? _chatSyncDebounce;
  static const int _maxChatConversations = 20;

  // Call this after any chat change
  void scheduleChatHistorySync() {
    _chatSyncDebounce?.cancel();
    _chatSyncDebounce = Timer(const Duration(seconds: 2), () {
      unawaited(syncChatHistoryToCloud());
    });
  }

  // Overwrite local chat save to keep only latest 20 conversations
  Future<void> saveConversationLocally(Map<String, dynamic> conversations) async {
    // Keep only the latest 20 by timestamp (assuming each conversation has a timestamp field)
    final sorted = Map.fromEntries(
      conversations.entries.toList()
        ..sort((a, b) {
          final aTime = a.value['lastMessageTimestamp'] ?? 0;
          final bTime = b.value['lastMessageTimestamp'] ?? 0;
          return bTime.compareTo(aTime);
        })
    );
    final limited = Map<String, dynamic>.fromEntries(sorted.entries.take(_maxChatConversations));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('conversations', json.encode(limited));
  }

  Timer? _flashcardSyncDebounce;
  static const int _maxFlashcards = 20;

  // Call this after any flashcard change
  void scheduleFlashcardSync() {
    _flashcardSyncDebounce?.cancel();
    _flashcardSyncDebounce = Timer(const Duration(seconds: 2), () {
      unawaited(syncFlashcardsToCloud());
    });
  }

  // Overwrite local flashcard save to keep only latest 20
  Future<void> saveFlashcardsLocally(List<Flashcard> flashcards) async {
    final sorted = List<Flashcard>.from(flashcards)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final limited = sorted.take(_maxFlashcards).toList();
    final prefs = await SharedPreferences.getInstance();
    final flashcardsJson = limited.map((f) => json.encode({
      'uuid': f.uuid,
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
  }

  Timer? _favoritesSyncDebounce;
  Timer? _aiPhrasesSyncDebounce;
  static const int _maxFavorites = 20;
  static const int _maxAiPhrases = 20;

  // Call this after any favorites change
  void scheduleFavoritesSync() {
    _favoritesSyncDebounce?.cancel();
    _favoritesSyncDebounce = Timer(const Duration(seconds: 2), () {
      unawaited(syncFavoritesToCloud());
    });
  }

  // Call this after any AI phrases change
  void scheduleAiPhrasesSync() {
    _aiPhrasesSyncDebounce?.cancel();
    _aiPhrasesSyncDebounce = Timer(const Duration(seconds: 2), () {
      unawaited(syncAiPhrasesToCloud());
    });
  }

  // Overwrite local favorites save to keep only latest 20
  Future<void> saveFavoritesLocally(List<String> favorites) async {
    final limited = favorites.take(_maxFavorites).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('signed_in_favorite_phrases', limited);
    await prefs.setStringList('favorite_phrases', limited);
  }

  // Overwrite local AI phrases save to keep only latest 20
  Future<void> saveAiPhrasesLocally(List<String> aiPhrases) async {
    final limited = aiPhrases.take(_maxAiPhrases).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('signed_in_ai_phrases', limited);
    await prefs.setStringList('ai_phrases', limited);
  }
}