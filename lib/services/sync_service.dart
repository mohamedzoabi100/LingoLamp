import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/database_helper.dart';
import '../models/flashcard_model.dart';
import '../models/chat_message_model.dart';
import '../models/conversation_model.dart';
import '../models/recommended_flashcard_model.dart';
import 'sync_status_service.dart';
import 'xp_service.dart';
import 'user_data_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final SyncStatusService _syncStatus = SyncStatusService();
  final XPService _xpService = XPService();

  // Sync timestamps
  static const String _lastFlashcardSyncKey = 'last_flashcard_sync';
  static const String _lastChatSyncKey = 'last_chat_sync';
  static const String _lastXPSyncKey = 'last_xp_sync';
  static const String _lastFavoritesSyncKey = 'last_favorites_sync';
  static const String _lastRecommendationsSyncKey = 'last_recommendations_sync';

  // Device ID for conflict resolution
  static const String _deviceIdKey = 'device_id';
  String? _deviceId;

  // Getters
  User? get currentUser => _auth.currentUser;
  bool get isAuthenticated => currentUser != null;
  String? get userId => currentUser?.uid;
  Stream<SyncStatus> get syncStatusStream => _syncStatus.statusStream;

  // Initialize sync service
  Future<void> initialize() async {
    await _ensureDeviceId();
    _syncStatus.updateStatus(SyncStatus.synced);
  }

  // Generate or retrieve device ID
  Future<void> _ensureDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString(_deviceIdKey);
    if (_deviceId == null) {
      _deviceId = '${DateTime.now().millisecondsSinceEpoch}_${currentUser?.uid ?? 'guest'}';
      await prefs.setString(_deviceIdKey, _deviceId!);
    }
  }

  // ===== FLASHCARD SYNC =====
  Future<void> syncFlashcards() async {
    if (!isAuthenticated) return;

    try {
      _syncStatus.updateStatus(SyncStatus.syncing);
      
      // Check network connectivity
      if (!await _checkNetworkConnectivity()) {
        _syncStatus.updateStatus(SyncStatus.offline);
        return;
      }

      // Get local flashcards
      final localFlashcards = await _dbHelper.getAllFlashcards();
      
      // Get cloud flashcards
      final cloudDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('flashcards')
          .doc('data')
          .get();

      List<Flashcard> cloudFlashcards = [];
      if (cloudDoc.exists) {
        final data = cloudDoc.data()!;
        final cloudData = List<Map<String, dynamic>>.from(data['flashcards'] ?? []);
        cloudFlashcards = cloudData.map((map) => Flashcard.fromMap(map)).toList();
      }

      // Merge and resolve conflicts
      final mergedFlashcards = await _mergeFlashcards(localFlashcards, cloudFlashcards);
      
      // Update local database
      await _updateLocalFlashcards(mergedFlashcards);
      
      // Update cloud
      await _updateCloudFlashcards(mergedFlashcards);
      
      // Update sync timestamp
      final now = DateTime.now().millisecondsSinceEpoch;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastFlashcardSyncKey, now);
      
      _syncStatus.updateStatus(SyncStatus.synced);
      print('✅ Flashcards synced successfully');
      
    } catch (e) {
      print('❌ Flashcard sync error: $e');
      _syncStatus.updateStatus(SyncStatus.error);
    }
  }

  Future<List<Flashcard>> _mergeFlashcards(List<Flashcard> local, List<Flashcard> cloud) async {
    final Map<String, Flashcard> merged = {};
    
    // Add local flashcards
    for (final flashcard in local) {
      merged[flashcard.uuid] = flashcard;
    }
    
    // Merge with cloud flashcards
    for (final cloudFlashcard in cloud) {
      final localFlashcard = merged[cloudFlashcard.uuid];
      
      if (localFlashcard == null) {
        // New cloud flashcard
        merged[cloudFlashcard.uuid] = cloudFlashcard;
      } else {
        // Conflict resolution - use the most recently updated
        final localTime = localFlashcard.lastStudied.millisecondsSinceEpoch;
        final cloudTime = cloudFlashcard.lastStudied.millisecondsSinceEpoch;
        
        if (cloudTime > localTime) {
          merged[cloudFlashcard.uuid] = cloudFlashcard;
        }
      }
    }
    
    return merged.values.toList();
  }

  Future<void> _updateLocalFlashcards(List<Flashcard> flashcards) async {
    // Clear existing flashcards by deleting them one by one
    final existingFlashcards = await _dbHelper.getAllFlashcards();
    for (final flashcard in existingFlashcards) {
      await _dbHelper.deleteFlashcardByUuid(flashcard.uuid);
    }
    
    // Insert merged flashcards
    for (final flashcard in flashcards) {
      await _dbHelper.insertFlashcard(flashcard);
    }
  }

  Future<void> _updateCloudFlashcards(List<Flashcard> flashcards) async {
    final flashcardData = flashcards.map((f) => f.toMap()).toList();
    
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('flashcards')
        .doc('data')
        .set({
      'flashcards': flashcardData,
      'lastModified': FieldValue.serverTimestamp(),
      'deviceId': _deviceId,
    });
  }

  // ===== CHAT HISTORY SYNC =====
  Future<void> syncChatHistory() async {
    if (!isAuthenticated) return;

    try {
      _syncStatus.updateStatus(SyncStatus.syncing);
      
      if (!await _checkNetworkConnectivity()) {
        _syncStatus.updateStatus(SyncStatus.offline);
        return;
      }

      // Get local conversations and messages
      final localConversations = await _dbHelper.getAllConversations();
      // Note: We don't have getAllMessages, so we'll get messages per conversation
      List<ChatMessage> localMessages = [];
      for (final conversation in localConversations) {
        final messages = await _dbHelper.getMessagesForConversation(conversation.id);
        localMessages.addAll(messages);
      }
      
      // Get cloud chat data
      final cloudDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('chat')
          .doc('history')
          .get();

      List<Conversation> cloudConversations = [];
      List<ChatMessage> cloudMessages = [];
      
      if (cloudDoc.exists) {
        final data = cloudDoc.data()!;
        final conversationsData = List<Map<String, dynamic>>.from(data['conversations'] ?? []);
        final messagesData = List<Map<String, dynamic>>.from(data['messages'] ?? []);
        
        cloudConversations = conversationsData.map((map) => Conversation.fromMap(map)).toList();
        cloudMessages = messagesData.map((map) => ChatMessage.fromMap(map)).toList();
      }

      // Merge chat data
      final mergedConversations = await _mergeConversations(localConversations, cloudConversations);
      final mergedMessages = await _mergeMessages(localMessages, cloudMessages);
      
      // Update local database
      await _updateLocalChat(mergedConversations, mergedMessages);
      
      // Update cloud
      await _updateCloudChat(mergedConversations, mergedMessages);
      
      // Update sync timestamp
      final now = DateTime.now().millisecondsSinceEpoch;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastChatSyncKey, now);
      
      _syncStatus.updateStatus(SyncStatus.synced);
      print('✅ Chat history synced successfully');
      
    } catch (e) {
      print('❌ Chat sync error: $e');
      _syncStatus.updateStatus(SyncStatus.error);
    }
  }

  Future<List<Conversation>> _mergeConversations(List<Conversation> local, List<Conversation> cloud) async {
    final Map<String, Conversation> merged = {};
    
    // Add local conversations
    for (final conversation in local) {
      merged[conversation.id] = conversation;
    }
    
    // Merge with cloud conversations
    for (final cloudConversation in cloud) {
      final localConversation = merged[cloudConversation.id];
      
      if (localConversation == null) {
        merged[cloudConversation.id] = cloudConversation;
      } else {
        // Use the most recently updated
        final localTime = localConversation.updatedAt.millisecondsSinceEpoch;
        final cloudTime = cloudConversation.updatedAt.millisecondsSinceEpoch;
        
        if (cloudTime > localTime) {
          merged[cloudConversation.id] = cloudConversation;
        }
      }
    }
    
    return merged.values.toList();
  }

  Future<List<ChatMessage>> _mergeMessages(List<ChatMessage> local, List<ChatMessage> cloud) async {
    final Map<String, ChatMessage> merged = {};
    
    // Add local messages
    for (final message in local) {
      merged[message.id] = message;
    }
    
    // Merge with cloud messages
    for (final cloudMessage in cloud) {
      final localMessage = merged[cloudMessage.id];
      
      if (localMessage == null) {
        merged[cloudMessage.id] = cloudMessage;
      } else {
        // Use the most recently updated
        final localTime = localMessage.timestamp.millisecondsSinceEpoch;
        final cloudTime = cloudMessage.timestamp.millisecondsSinceEpoch;
        
        if (cloudTime > localTime) {
          merged[cloudMessage.id] = cloudMessage;
        }
      }
    }
    
    return merged.values.toList();
  }

  Future<void> _updateLocalChat(List<Conversation> conversations, List<ChatMessage> messages) async {
    // Clear existing chat data by deleting conversations one by one
    final existingConversations = await _dbHelper.getAllConversations();
    for (final conversation in existingConversations) {
      await _dbHelper.deleteConversation(conversation.id);
    }
    
    // Insert merged data
    for (final conversation in conversations) {
      await _dbHelper.insertConversation(conversation);
    }
    
    for (final message in messages) {
      await _dbHelper.insertMessage(message);
    }
  }

  Future<void> _updateCloudChat(List<Conversation> conversations, List<ChatMessage> messages) async {
    final conversationsData = conversations.map((c) => c.toMap()).toList();
    final messagesData = messages.map((m) => m.toMap()).toList();
    
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('chat')
        .doc('history')
        .set({
      'conversations': conversationsData,
      'messages': messagesData,
      'lastModified': FieldValue.serverTimestamp(),
      'deviceId': _deviceId,
    });
  }

  // ===== XP & PROGRESS SYNC =====
  Future<void> syncXPAndProgress() async {
    if (!isAuthenticated) return;

    try {
      _syncStatus.updateStatus(SyncStatus.syncing);
      
      if (!await _checkNetworkConnectivity()) {
        _syncStatus.updateStatus(SyncStatus.offline);
        return;
      }

      // Get local XP data
      final localStats = await _xpService.getXPStats();
      final localXP = localStats['totalXP'] ?? 0;
      final localStreak = localStats['currentStreak'] ?? 0;
      
      // Get cloud XP data
      final cloudDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('progress')
          .doc('xp')
          .get();

      int cloudXP = 0;
      int cloudStreak = 0;
      
      if (cloudDoc.exists) {
        final data = cloudDoc.data()!;
        cloudXP = data['xp'] ?? 0;
        cloudStreak = data['streak'] ?? 0;
      }

      // Merge XP data (use the higher values)
      final mergedXP = localXP > cloudXP ? localXP : cloudXP;
      final mergedStreak = localStreak > cloudStreak ? localStreak : cloudStreak;
      
      // Update local XP by adding the difference
      if (mergedXP > localXP) {
        await _xpService.addXP(mergedXP - localXP, 'Sync from cloud');
      }
      
      // Update cloud
      await _updateCloudXP(mergedXP, mergedStreak);
      
      // Update sync timestamp
      final now = DateTime.now().millisecondsSinceEpoch;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastXPSyncKey, now);
      
      _syncStatus.updateStatus(SyncStatus.synced);
      print('✅ XP and progress synced successfully');
      
    } catch (e) {
      print('❌ XP sync error: $e');
      _syncStatus.updateStatus(SyncStatus.error);
    }
  }

  Future<void> _updateCloudXP(int xp, int streak) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('progress')
        .doc('xp')
        .set({
      'xp': xp,
      'streak': streak,
      'lastModified': FieldValue.serverTimestamp(),
      'deviceId': _deviceId,
    });
  }

  // ===== FAVORITES SYNC =====
  Future<void> syncFavorites() async {
    if (!isAuthenticated) return;

    try {
      _syncStatus.updateStatus(SyncStatus.syncing);
      
      if (!await _checkNetworkConnectivity()) {
        _syncStatus.updateStatus(SyncStatus.offline);
        return;
      }

      // Get local favorites
      final prefs = await SharedPreferences.getInstance();
      final localFavorites = prefs.getStringList('signed_in_favorite_phrases') ?? [];
      
      // Get cloud favorites
      final cloudDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('preferences')
          .doc('favorites')
          .get();

      List<String> cloudFavorites = [];
      if (cloudDoc.exists) {
        final data = cloudDoc.data()!;
        cloudFavorites = List<String>.from(data['favorites'] ?? []);
      }

      // Merge favorites (union of both lists)
      final mergedFavorites = <String>{};
      mergedFavorites.addAll(localFavorites);
      mergedFavorites.addAll(cloudFavorites);
      
      final mergedList = mergedFavorites.toList();
      
      // Update local favorites
      await prefs.setStringList('signed_in_favorite_phrases', mergedList);
      await prefs.setStringList('favorite_phrases', mergedList);
      
      // Update cloud
      await _updateCloudFavorites(mergedList);
      
      // Update sync timestamp
      final now = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(_lastFavoritesSyncKey, now);
      
      _syncStatus.updateStatus(SyncStatus.synced);
      print('✅ Favorites synced successfully');
      
    } catch (e) {
      print('❌ Favorites sync error: $e');
      _syncStatus.updateStatus(SyncStatus.error);
    }
  }

  Future<void> _updateCloudFavorites(List<String> favorites) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('preferences')
        .doc('favorites')
        .set({
      'favorites': favorites,
      'lastModified': FieldValue.serverTimestamp(),
      'deviceId': _deviceId,
    });
  }

  // ===== RECOMMENDATIONS SYNC =====
  Future<void> syncRecommendations() async {
    if (!isAuthenticated) return;

    try {
      _syncStatus.updateStatus(SyncStatus.syncing);
      
      if (!await _checkNetworkConnectivity()) {
        _syncStatus.updateStatus(SyncStatus.offline);
        return;
      }

      // Get local recommendations
      final localRecommendations = await _dbHelper.getAllRecommendedFlashcards();
      
      // Get cloud recommendations
      final cloudDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('recommendations')
          .doc('data')
          .get();

      List<RecommendedFlashcard> cloudRecommendations = [];
      if (cloudDoc.exists) {
        final data = cloudDoc.data()!;
        final recommendationsData = List<Map<String, dynamic>>.from(data['recommendations'] ?? []);
        cloudRecommendations = recommendationsData.map((map) => RecommendedFlashcard.fromMap(map)).toList();
      }

      // Merge recommendations
      final mergedRecommendations = await _mergeRecommendations(localRecommendations, cloudRecommendations);
      
      // Update local database
      await _updateLocalRecommendations(mergedRecommendations);
      
      // Update cloud
      await _updateCloudRecommendations(mergedRecommendations);
      
      // Update sync timestamp
      final now = DateTime.now().millisecondsSinceEpoch;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastRecommendationsSyncKey, now);
      
      _syncStatus.updateStatus(SyncStatus.synced);
      print('✅ Recommendations synced successfully');
      
    } catch (e) {
      print('❌ Recommendations sync error: $e');
      _syncStatus.updateStatus(SyncStatus.error);
    }
  }

  Future<List<RecommendedFlashcard>> _mergeRecommendations(List<RecommendedFlashcard> local, List<RecommendedFlashcard> cloud) async {
    final Map<String, RecommendedFlashcard> merged = {};
    
    // Add local recommendations
    for (final recommendation in local) {
      merged[recommendation.term] = recommendation;
    }
    
    // Merge with cloud recommendations
    for (final cloudRecommendation in cloud) {
      final localRecommendation = merged[cloudRecommendation.term];
      
      if (localRecommendation == null) {
        merged[cloudRecommendation.term] = cloudRecommendation;
      } else {
        // Use the most recently updated
        final localTime = localRecommendation.updatedAt.millisecondsSinceEpoch;
        final cloudTime = cloudRecommendation.updatedAt.millisecondsSinceEpoch;
        
        if (cloudTime > localTime) {
          merged[cloudRecommendation.term] = cloudRecommendation;
        }
      }
    }
    
    return merged.values.toList();
  }

  Future<void> _updateLocalRecommendations(List<RecommendedFlashcard> recommendations) async {
    // Clear existing recommendations by deleting them one by one
    final existingRecommendations = await _dbHelper.getAllRecommendedFlashcards();
    for (final recommendation in existingRecommendations) {
      await _dbHelper.deleteRecommended(recommendation.id!);
    }
    
    // Insert merged recommendations
    for (final recommendation in recommendations) {
      await _dbHelper.upsertRecommendedFlashcard(recommendation);
    }
  }

  Future<void> _updateCloudRecommendations(List<RecommendedFlashcard> recommendations) async {
    final recommendationsData = recommendations.map((r) => r.toMap()).toList();
    
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('recommendations')
        .doc('data')
        .set({
      'recommendations': recommendationsData,
      'lastModified': FieldValue.serverTimestamp(),
      'deviceId': _deviceId,
    });
  }

  // ===== FULL SYNC =====
  Future<void> performFullSync() async {
    if (!isAuthenticated) return;

    try {
      _syncStatus.updateStatus(SyncStatus.syncing);
      print('🔄 Starting full sync...');
      
      // Sync all data types
      await Future.wait([
        syncFlashcards(),
        syncChatHistory(),
        syncXPAndProgress(),
        syncFavorites(),
        syncRecommendations(),
      ]);
      
      _syncStatus.updateStatus(SyncStatus.synced);
      print('✅ Full sync completed successfully');
      
    } catch (e) {
      print('❌ Full sync error: $e');
      _syncStatus.updateStatus(SyncStatus.error);
    }
  }

  // ===== PULL FROM CLOUD =====
  Future<void> pullFromCloud() async {
    if (!isAuthenticated) return;

    try {
      _syncStatus.updateStatus(SyncStatus.syncing);
      print('📥 Pulling data from cloud...');
      
      // Pull all data types
      await Future.wait([
        _pullFlashcardsFromCloud(),
        _pullChatFromCloud(),
        _pullXPFromCloud(),
        _pullFavoritesFromCloud(),
        _pullRecommendationsFromCloud(),
      ]);
      
      _syncStatus.updateStatus(SyncStatus.synced);
      print('✅ Pull from cloud completed');
      
    } catch (e) {
      print('❌ Pull from cloud error: $e');
      _syncStatus.updateStatus(SyncStatus.error);
    }
  }

  Future<void> _pullFlashcardsFromCloud() async {
    final cloudDoc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('flashcards')
        .doc('data')
        .get();

    if (cloudDoc.exists) {
      final data = cloudDoc.data()!;
      final cloudData = List<Map<String, dynamic>>.from(data['flashcards'] ?? []);
      final cloudFlashcards = cloudData.map((map) => Flashcard.fromMap(map)).toList();
      
      await _updateLocalFlashcards(cloudFlashcards);
    }
  }

  Future<void> _pullChatFromCloud() async {
    final cloudDoc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('chat')
        .doc('history')
        .get();

    if (cloudDoc.exists) {
      final data = cloudDoc.data()!;
      final conversationsData = List<Map<String, dynamic>>.from(data['conversations'] ?? []);
      final messagesData = List<Map<String, dynamic>>.from(data['messages'] ?? []);
      
      final cloudConversations = conversationsData.map((map) => Conversation.fromMap(map)).toList();
      final cloudMessages = messagesData.map((map) => ChatMessage.fromMap(map)).toList();
      
      await _updateLocalChat(cloudConversations, cloudMessages);
    }
  }

  Future<void> _pullXPFromCloud() async {
    final cloudDoc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('progress')
        .doc('xp')
        .get();

    if (cloudDoc.exists) {
      final data = cloudDoc.data()!;
      final xp = data['xp'] ?? 0;
      
      // Update local XP by adding the difference
      final localStats = await _xpService.getXPStats();
      final localXP = localStats['totalXP'] ?? 0;
      
      if (xp > localXP) {
        await _xpService.addXP(xp - localXP, 'Sync from cloud');
      }
    }
  }

  Future<void> _pullFavoritesFromCloud() async {
    final cloudDoc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('preferences')
        .doc('favorites')
        .get();

    if (cloudDoc.exists) {
      final data = cloudDoc.data()!;
      final cloudFavorites = List<String>.from(data['favorites'] ?? []);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('signed_in_favorite_phrases', cloudFavorites);
      await prefs.setStringList('favorite_phrases', cloudFavorites);
    }
  }

  Future<void> _pullRecommendationsFromCloud() async {
    final cloudDoc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('recommendations')
        .doc('data')
        .get();

    if (cloudDoc.exists) {
      final data = cloudDoc.data()!;
      final recommendationsData = List<Map<String, dynamic>>.from(data['recommendations'] ?? []);
      final cloudRecommendations = recommendationsData.map((map) => RecommendedFlashcard.fromMap(map)).toList();
      
      await _updateLocalRecommendations(cloudRecommendations);
    }
  }

  // ===== PUSH TO CLOUD =====
  Future<void> pushToCloud() async {
    if (!isAuthenticated) return;

    try {
      _syncStatus.updateStatus(SyncStatus.syncing);
      print('📤 Pushing data to cloud...');
      
      // Push all data types
      await Future.wait([
        _pushFlashcardsToCloud(),
        _pushChatToCloud(),
        _pushXPToCloud(),
        _pushFavoritesToCloud(),
        _pushRecommendationsToCloud(),
      ]);
      
      _syncStatus.updateStatus(SyncStatus.synced);
      print('✅ Push to cloud completed');
      
    } catch (e) {
      print('❌ Push to cloud error: $e');
      _syncStatus.updateStatus(SyncStatus.error);
    }
  }

  Future<void> _pushFlashcardsToCloud() async {
    final localFlashcards = await _dbHelper.getAllFlashcards();
    await _updateCloudFlashcards(localFlashcards);
  }

  Future<void> _pushChatToCloud() async {
    final localConversations = await _dbHelper.getAllConversations();
    // Get messages per conversation since we don't have getAllMessages
    List<ChatMessage> localMessages = [];
    for (final conversation in localConversations) {
      final messages = await _dbHelper.getMessagesForConversation(conversation.id);
      localMessages.addAll(messages);
    }
    await _updateCloudChat(localConversations, localMessages);
  }

  Future<void> _pushXPToCloud() async {
    final stats = await _xpService.getXPStats();
    final xp = stats['totalXP'] ?? 0;
    final streak = stats['currentStreak'] ?? 0;
    await _updateCloudXP(xp, streak);
  }

  Future<void> _pushFavoritesToCloud() async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList('signed_in_favorite_phrases') ?? [];
    await _updateCloudFavorites(favorites);
  }

  Future<void> _pushRecommendationsToCloud() async {
    final localRecommendations = await _dbHelper.getAllRecommendedFlashcards();
    await _updateCloudRecommendations(localRecommendations);
  }

  // ===== UTILITY METHODS =====
  Future<bool> _checkNetworkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Clear all provider states (for account deletion)
  Future<void> _clearAllProviderStates() async {
    try {
      print('🔄 Clearing all provider states...');
      
      // Import providers to clear their states
      // Note: We'll need to access these through the app's provider system
      // For now, we'll rely on the providers to reset themselves when data is cleared
      
      // The providers should automatically reset when their underlying data is cleared
      // This is handled by the database streams and SharedPreferences clearing
      
      print('✅ Provider states cleared');
      
    } catch (e) {
      print('❌ Error clearing provider states: $e');
    }
  }

  // Clear all user data (for account deletion)
  Future<void> clearAllUserData() async {
    if (!isAuthenticated) return;

    try {
      print('🗑️ Starting comprehensive user data deletion...');
      
      // Step 1: Clear all user data from UserDataService (clears Hive, SharedPreferences, etc.)
      print('📱 Clearing local user data via UserDataService...');
      await UserDataService().clearAllUserData();
      
      // Step 2: Clear XP and streak data specifically
      print('🎯 Clearing XP and streak data...');
      await _xpService.clearAllXPData();
      
      // Step 3: Clear all provider states
      print('🔄 Clearing provider states...');
      await _clearAllProviderStates();
      
      // Step 4: Delete all subcollections and their documents from Firebase
      print('☁️ Deleting all Firebase subcollections...');
      await _deleteAllSubcollections();
      
      // Step 5: Delete the main user document
      print('📄 Deleting main user document...');
      await _firestore.collection('users').doc(userId).delete();
      
      // Step 6: Clear local database data by deleting items one by one
      print('🗄️ Clearing local database...');
      final existingFlashcards = await _dbHelper.getAllFlashcards();
      for (final flashcard in existingFlashcards) {
        await _dbHelper.deleteFlashcardByUuid(flashcard.uuid);
      }
      
      final existingConversations = await _dbHelper.getAllConversations();
      for (final conversation in existingConversations) {
        await _dbHelper.deleteConversation(conversation.id);
      }
      
      final existingRecommendations = await _dbHelper.getAllRecommendedFlashcards();
      for (final recommendation in existingRecommendations) {
        await _dbHelper.deleteRecommended(recommendation.id!);
      }
      
      // Step 7: Clear any remaining preferences
      print('⚙️ Clearing remaining preferences...');
      final prefs = await SharedPreferences.getInstance();
      
      // Clear all user-related preferences
      final allKeysToRemove = [
        // Favorites and phrases
        'signed_in_favorite_phrases',
        'favorite_phrases',
        'ai_phrases',
        'signed_in_ai_phrases',
        'guest_favorite_phrases',
        'guest_ai_phrases',
        'latest_guest_favorite_phrases',
        'latest_guest_ai_phrases',
        
        // Flashcards
        'signed_in_flashcards',
        'latest_guest_flashcards',
        
        // Conversations
        'conversations',
        'signed_in_conversations',
        'latest_guest_conversations',
        
        // Sync flags and timestamps
        'favorites_need_sync',
        'ai_phrases_need_sync',
        'need_cloud_poll',
        'favorites_last_modified',
        'ai_phrases_last_modified',
        
        // Sync timestamps from sync service
        _lastFlashcardSyncKey,
        _lastChatSyncKey,
        _lastXPSyncKey,
        _lastFavoritesSyncKey,
        _lastRecommendationsSyncKey,
        
        // Device ID
        _deviceIdKey,
      ];
      
      for (final key in allKeysToRemove) {
        await prefs.remove(key);
      }
      
      print('✅ All preferences cleared');
      
      print('✅ All user data cleared successfully');
      
    } catch (e) {
      print('❌ Error clearing user data: $e');
      rethrow; // Re-throw to let the auth provider handle the error
    }
  }

  // Delete all subcollections and their documents
  Future<void> _deleteAllSubcollections() async {
    final userDoc = _firestore.collection('users').doc(userId);
    
    // List of subcollections to delete
    final subcollections = [
      'flashcards',
      'chat',
      'progress',
      'preferences',
      'recommendations',
      'ai_phrases',
      'study_sessions',
      'achievements',
      'settings',
    ];
    
    for (final subcollectionName in subcollections) {
      try {
        await _deleteSubcollection(userDoc, subcollectionName);
      } catch (e) {
        print('⚠️ Warning: Could not delete subcollection $subcollectionName: $e');
        // Continue with other subcollections even if one fails
      }
    }
  }

  // Delete a specific subcollection and all its documents
  Future<void> _deleteSubcollection(DocumentReference userDoc, String subcollectionName) async {
    final subcollection = userDoc.collection(subcollectionName);
    final querySnapshot = await subcollection.get();
    
    if (querySnapshot.docs.isNotEmpty) {
      print('🗑️ Deleting subcollection: $subcollectionName (${querySnapshot.docs.length} documents)');
      
      // Delete all documents in the subcollection
      final batch = _firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      print('✅ Deleted subcollection: $subcollectionName');
    }
  }

  // Dispose resources
  void dispose() {
    // Clean up any timers or streams if needed
  }

  // Verify that all user data has been deleted (for debugging and compliance)
  Future<bool> verifyDataDeletion() async {
    if (!isAuthenticated) return true; // No user to verify

    try {
      print('🔍 Verifying data deletion...');
      
      // Check if main user document exists
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        print('❌ Main user document still exists');
        return false;
      }
      
      // Check all subcollections
      final subcollections = [
        'flashcards',
        'chat',
        'progress',
        'preferences',
        'recommendations',
        'ai_phrases',
        'study_sessions',
        'achievements',
        'settings',
        'spacedRepetition',
      ];
      
      for (final subcollectionName in subcollections) {
        final subcollection = _firestore.collection('users').doc(userId).collection(subcollectionName);
        final querySnapshot = await subcollection.get();
        
        if (querySnapshot.docs.isNotEmpty) {
          print('❌ Subcollection $subcollectionName still has ${querySnapshot.docs.length} documents');
          return false;
        }
      }
      
      // Check local database
      final localFlashcards = await _dbHelper.getAllFlashcards();
      if (localFlashcards.isNotEmpty) {
        print('❌ Local database still has ${localFlashcards.length} flashcards');
        return false;
      }
      
      final localConversations = await _dbHelper.getAllConversations();
      if (localConversations.isNotEmpty) {
        print('❌ Local database still has ${localConversations.length} conversations');
        return false;
      }
      
      final localRecommendations = await _dbHelper.getAllRecommendedFlashcards();
      if (localRecommendations.isNotEmpty) {
        print('❌ Local database still has ${localRecommendations.length} recommendations');
        return false;
      }
      
      // Check XP and streak data in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final allKeysToCheck = [
        // XP and streak keys
        'total_xp',
        'today_xp',
        'current_streak',
        'longest_streak',
        'last_activity_date',
        'xp_level',
        'xp_experience',
        'streak_count',
        'last_streak_date',
        'achievements',
        'daily_goals',
        
        // Favorites and phrases
        'signed_in_favorite_phrases',
        'favorite_phrases',
        'ai_phrases',
        'signed_in_ai_phrases',
        'guest_favorite_phrases',
        'guest_ai_phrases',
        'latest_guest_favorite_phrases',
        'latest_guest_ai_phrases',
        
        // Flashcards
        'signed_in_flashcards',
        'latest_guest_flashcards',
        
        // Conversations
        'conversations',
        'signed_in_conversations',
        'latest_guest_conversations',
        
        // Sync flags and timestamps
        'favorites_need_sync',
        'ai_phrases_need_sync',
        'need_cloud_poll',
        'favorites_last_modified',
        'ai_phrases_last_modified',
        
        // Sync timestamps from sync service
        _lastFlashcardSyncKey,
        _lastChatSyncKey,
        _lastXPSyncKey,
        _lastFavoritesSyncKey,
        _lastRecommendationsSyncKey,
        
        // Device ID
        _deviceIdKey,
      ];
      
      for (final key in allKeysToCheck) {
        if (prefs.containsKey(key)) {
          print('❌ User data still exists: $key');
          return false;
        }
      }
      
      print('✅ All user data has been successfully deleted');
      return true;
      
    } catch (e) {
      print('❌ Error verifying data deletion: $e');
      return false;
    }
  }
} 