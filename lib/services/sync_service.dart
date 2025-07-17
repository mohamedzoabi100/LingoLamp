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
  
  // Rate limiting for sync operations
  int? _lastChatSyncTime;

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
      print('🔄 [SYNC] Found ${localFlashcards.length} local flashcards');
      
      // Get cloud flashcards from all languages
      final cloudFlashcards = await _getAllCloudFlashcards();
      print('🔄 [SYNC] Found ${cloudFlashcards.length} cloud flashcards');

      // Merge and resolve conflicts
      final mergedFlashcards = await _mergeFlashcards(localFlashcards, cloudFlashcards);
      print('🔄 [SYNC] Merged to ${mergedFlashcards.length} flashcards');
      
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

  Future<List<Flashcard>> _getAllCloudFlashcards() async {
    final List<Flashcard> allFlashcards = [];
    
    // Get all language documents
    final languagesSnapshot = await _firestore
        .collection('users')
        .doc(userId)
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
          // Use the document ID as the UUID (since we're now using UUID as document ID)
          data['uuid'] = flashcardDoc.id;
          data['languageCode'] = languageCode; // Ensure language code is set
          allFlashcards.add(Flashcard.fromMap(data));
          print('📥 [SYNC] Loaded cloud flashcard: ${data['originalText']} -> ${data['translatedText']} (${flashcardDoc.id})');
        } catch (e) {
          print('⚠️ [SYNC] Error parsing cloud flashcard: $e');
        }
      }
    }
    
    print('📊 [SYNC] Total cloud flashcards loaded: ${allFlashcards.length}');
    return allFlashcards;
  }

  Future<List<Flashcard>> _mergeFlashcards(List<Flashcard> local, List<Flashcard> cloud) async {
    print('🔄 [SYNC] _mergeFlashcards called with ${local.length} local and ${cloud.length} cloud flashcards');
    
    final Map<String, Flashcard> merged = {};
    
    // Add local flashcards
    print('📝 [SYNC] Adding local flashcards:');
    for (final flashcard in local) {
      print('  - ${flashcard.originalText} -> ${flashcard.translatedText} (${flashcard.uuid})');
      merged[flashcard.uuid] = flashcard;
    }
    
    // Merge with cloud flashcards
    print('📝 [SYNC] Merging with cloud flashcards:');
    for (final cloudFlashcard in cloud) {
      print('  - ${cloudFlashcard.originalText} -> ${cloudFlashcard.translatedText} (${cloudFlashcard.uuid})');
      final localFlashcard = merged[cloudFlashcard.uuid];
      
      if (localFlashcard == null) {
        // New cloud flashcard
        print('    -> New cloud flashcard, adding');
        merged[cloudFlashcard.uuid] = cloudFlashcard;
      } else {
        // Conflict resolution - use the most recently updated
        final localTime = localFlashcard.lastStudied.millisecondsSinceEpoch;
        final cloudTime = cloudFlashcard.lastStudied.millisecondsSinceEpoch;
        
        print('    -> Conflict detected: local=${localTime}, cloud=${cloudTime}');
        if (cloudTime > localTime) {
          print('    -> Using cloud version (newer)');
          merged[cloudFlashcard.uuid] = cloudFlashcard;
        } else {
          print('    -> Using local version (newer or same)');
        }
      }
    }
    
    final result = merged.values.toList();
    print('✅ [SYNC] _mergeFlashcards completed with ${result.length} merged flashcards');
    return result;
  }

  Future<void> _updateLocalFlashcards(List<Flashcard> flashcards) async {
    print('🔄 [SYNC] _updateLocalFlashcards called with ${flashcards.length} flashcards');
    
    // Get existing flashcards to avoid duplicates (like chat sync does)
    final existingFlashcards = await _dbHelper.getAllFlashcards();
    final existingUuids = existingFlashcards.map((f) => f.uuid).toSet();
    
    print('📊 [SYNC] Found ${existingFlashcards.length} existing flashcards');
    
    // Only insert new flashcards (don't clear existing ones)
    int insertedCount = 0;
    for (final flashcard in flashcards) {
      if (!existingUuids.contains(flashcard.uuid)) {
        print('➕ [SYNC] Inserting new flashcard: ${flashcard.originalText} -> ${flashcard.translatedText} (${flashcard.uuid})');
        try {
          await _dbHelper.insertFlashcard(flashcard);
          insertedCount++;
          print('✅ [SYNC] Successfully inserted flashcard: ${flashcard.originalText}');
        } catch (e) {
          print('❌ [SYNC] Error inserting flashcard: ${flashcard.originalText} - $e');
        }
      } else {
        print('⏭️ [SYNC] Skipping existing flashcard: ${flashcard.originalText} (${flashcard.uuid})');
      }
    }
    
    print('✅ [SYNC] _updateLocalFlashcards completed - inserted $insertedCount new flashcards');
  }

  Future<void> _updateCloudFlashcards(List<Flashcard> flashcards) async {
    print('🔄 [SYNC] _updateCloudFlashcards called with ${flashcards.length} flashcards');
    
    // Group flashcards by language
    final Map<String, List<Flashcard>> flashcardsByLanguage = {};
    for (final flashcard in flashcards) {
      final languageCode = flashcard.languageCode;
      flashcardsByLanguage.putIfAbsent(languageCode, () => []).add(flashcard);
    }
    
    // Update each language collection
    for (final entry in flashcardsByLanguage.entries) {
      final languageCode = entry.key;
      final languageFlashcards = entry.value;
      
      print('📝 [SYNC] Updating cloud flashcards for language: $languageCode');
      
      final languageRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('flashcards')
          .doc(languageCode);
      
      final batch = _firestore.batch();
      
      // Use UUID as document ID (like phrases do) and upsert all flashcards
      int upsertedCount = 0;
      for (final flashcard in languageFlashcards) {
        final docRef = languageRef.collection('items').doc(flashcard.uuid);
        batch.set(docRef, {
          ...flashcard.toMap(),
          'lastModified': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        upsertedCount++;
        print('🔄 [SYNC] Upserting cloud flashcard: ${flashcard.originalText} (${flashcard.uuid})');
      }
      
      if (upsertedCount > 0) {
        await batch.commit();
        print('✅ [SYNC] Upserted $upsertedCount cloud flashcards for $languageCode');
      } else {
        print('⏭️ [SYNC] No cloud flashcards to upsert for $languageCode');
      }
    }
  }

  // ===== CHAT HISTORY SYNC =====
  Future<void> syncChatHistory() async {
    if (!isAuthenticated) return;

    // Add rate limiting to prevent excessive sync operations
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastSyncTime = _lastChatSyncTime;
    if (lastSyncTime != null && (now - lastSyncTime) < 2000) { // 2 second cooldown
      print('⏳ [SYNC] Chat sync skipped - too soon since last sync');
      return;
    }
    _lastChatSyncTime = now;

    try {
      _syncStatus.updateStatus(SyncStatus.syncing);
      
      if (!await _checkNetworkConnectivity()) {
        _syncStatus.updateStatus(SyncStatus.offline);
        return;
      }

      // Get local conversations and messages
      final localConversations = await _dbHelper.getAllConversations();
      print('🔄 [SYNC] Found ${localConversations.length} local conversations');
      
      // Note: We don't have getAllMessages, so we'll get messages per conversation
      List<ChatMessage> localMessages = [];
      for (final conversation in localConversations) {
        final messages = await _dbHelper.getMessagesForConversation(conversation.id);
        localMessages.addAll(messages);
        print('🔄 [SYNC] Conversation ${conversation.title}: ${messages.length} messages');
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
    // Get existing data to avoid duplicates
    final existingConversations = await _dbHelper.getAllConversations();
    final existingConversationIds = existingConversations.map((c) => c.id).toSet();
    
    // Insert only new conversations
    for (final conversation in conversations) {
      if (!existingConversationIds.contains(conversation.id)) {
        await _dbHelper.insertConversation(conversation);
      }
    }
    
    // Get existing messages to avoid duplicates
    final existingMessages = <String>{};
    for (final conversation in conversations) {
      final messages = await _dbHelper.getMessagesForConversation(conversation.id);
      existingMessages.addAll(messages.map((m) => m.id));
    }
    
    // Insert only new messages
    for (final message in messages) {
      if (!existingMessages.contains(message.id)) {
        await _dbHelper.insertMessage(message);
      }
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
      final localRecommendations = await _dbHelper.getAllRecommendations();
      print('🔄 [SYNC] Found ${localRecommendations.length} local recommendations');
      
      // Get cloud recommendations from all languages
      final cloudRecommendations = await _getAllCloudRecommendations();
      print('🔄 [SYNC] Found ${cloudRecommendations.length} cloud recommendations');

      // Merge and resolve conflicts
      final mergedRecommendations = await _mergeRecommendations(localRecommendations, cloudRecommendations);
      print('🔄 [SYNC] Merged to ${mergedRecommendations.length} recommendations');
      
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

  Future<List<RecommendedFlashcard>> _getAllCloudRecommendations() async {
    final List<RecommendedFlashcard> allRecommendations = [];
    
    // Get all language documents
    final languagesSnapshot = await _firestore
        .collection('users')
        .doc(userId)
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
          data['id'] = int.parse(recommendationDoc.id);
          data['languageCode'] = languageCode; // Ensure language code is set
          allRecommendations.add(RecommendedFlashcard.fromMap(data));
          print('📥 [SYNC] Loaded cloud recommendation: ${data['term']} (${recommendationDoc.id})');
        } catch (e) {
          print('⚠️ [SYNC] Error parsing cloud recommendation: $e');
        }
      }
    }
    
    print('📊 [SYNC] Total cloud recommendations loaded: ${allRecommendations.length}');
    return allRecommendations;
  }

  Future<List<RecommendedFlashcard>> _mergeRecommendations(List<RecommendedFlashcard> local, List<RecommendedFlashcard> cloud) async {
    print('🔄 [SYNC] _mergeRecommendations called with ${local.length} local and ${cloud.length} cloud recommendations');
    
    final Map<String, RecommendedFlashcard> merged = {};
    
    // Add local recommendations
    print('📝 [SYNC] Adding local recommendations:');
    for (final recommendation in local) {
      final key = '${recommendation.term}_${recommendation.languageCode}';
      print('  - ${recommendation.term} (${recommendation.languageCode})');
      merged[key] = recommendation;
    }
    
    // Merge with cloud recommendations
    print('📝 [SYNC] Merging with cloud recommendations:');
    for (final cloudRecommendation in cloud) {
      final key = '${cloudRecommendation.term}_${cloudRecommendation.languageCode}';
      print('  - ${cloudRecommendation.term} (${cloudRecommendation.languageCode})');
      final localRecommendation = merged[key];
      
      if (localRecommendation == null) {
        // New cloud recommendation
        print('    -> New cloud recommendation, adding');
        merged[key] = cloudRecommendation;
      } else {
        // Conflict resolution - use the most recently updated
        final localTime = localRecommendation.updatedAt.millisecondsSinceEpoch;
        final cloudTime = cloudRecommendation.updatedAt.millisecondsSinceEpoch;
        
        print('    -> Conflict detected: local=${localTime}, cloud=${cloudTime}');
        if (cloudTime > localTime) {
          print('    -> Using cloud version (newer)');
          merged[key] = cloudRecommendation;
        } else {
          print('    -> Using local version (newer or same)');
        }
      }
    }
    
    final result = merged.values.toList();
    print('✅ [SYNC] _mergeRecommendations completed with ${result.length} merged recommendations');
    return result;
  }

  Future<void> _updateLocalRecommendations(List<RecommendedFlashcard> recommendations) async {
    print('🔄 [SYNC] _updateLocalRecommendations called with ${recommendations.length} recommendations');
    
    // Get existing recommendations to avoid duplicates
    final existingRecommendations = await _dbHelper.getAllRecommendations();
    final existingTerms = existingRecommendations.map((r) => '${r.term}_${r.languageCode}').toSet();
    
    print('📊 [SYNC] Found ${existingRecommendations.length} existing recommendations');
    
    // Only insert new recommendations (don't clear existing ones)
    int insertedCount = 0;
    for (final recommendation in recommendations) {
      final key = '${recommendation.term}_${recommendation.languageCode}';
      if (!existingTerms.contains(key)) {
        print('➕ [SYNC] Inserting new recommendation: ${recommendation.term} (${recommendation.languageCode})');
        try {
          await _dbHelper.addRecommendation(recommendation);
          insertedCount++;
          print('✅ [SYNC] Successfully inserted recommendation: ${recommendation.term}');
        } catch (e) {
          print('❌ [SYNC] Error inserting recommendation: ${recommendation.term} - $e');
        }
      } else {
        print('⏭️ [SYNC] Skipping existing recommendation: ${recommendation.term} (${recommendation.languageCode})');
      }
    }
    
    print('✅ [SYNC] _updateLocalRecommendations completed - inserted $insertedCount new recommendations');
  }

  Future<void> _updateCloudRecommendations(List<RecommendedFlashcard> recommendations) async {
    print('🔄 [SYNC] _updateCloudRecommendations called with ${recommendations.length} recommendations');
    
    // Group recommendations by language
    final Map<String, List<RecommendedFlashcard>> recommendationsByLanguage = {};
    for (final recommendation in recommendations) {
      final languageCode = recommendation.languageCode;
      recommendationsByLanguage.putIfAbsent(languageCode, () => []).add(recommendation);
    }
    
    // Update each language collection
    for (final entry in recommendationsByLanguage.entries) {
      final languageCode = entry.key;
      final languageRecommendations = entry.value;
      
      print('📝 [SYNC] Updating cloud recommendations for language: $languageCode (${languageRecommendations.length} items)');
      
      final batch = _firestore.batch();
      final collectionRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('recommendations')
          .doc(languageCode)
          .collection('items');
      
      for (final recommendation in languageRecommendations) {
        // Use a consistent document ID based on term and language to avoid duplicates
        final documentId = '${recommendation.term}_${recommendation.languageCode}'.hashCode.toString();
        final docRef = collectionRef.doc(documentId);
        batch.set(docRef, {
          ...recommendation.toMap(),
          'id': int.parse(documentId), // Ensure the ID matches the document ID
          'lastModified': FieldValue.serverTimestamp(),
          'deviceId': _deviceId,
        });
      }
      
      await batch.commit();
      print('✅ [SYNC] Updated cloud recommendations for language: $languageCode');
    }
    
    print('✅ [SYNC] _updateCloudRecommendations completed');
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
    final List<Flashcard> allCloudFlashcards = [];
    
    // Get all language documents
    final languagesSnapshot = await _firestore
        .collection('users')
        .doc(userId)
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
          data['languageCode'] = languageCode; // Ensure language code is set
          allCloudFlashcards.add(Flashcard.fromMap(data));
          print('📥 [SYNC] Pulled cloud flashcard: ${data['originalText']} -> ${data['translatedText']} (${flashcardDoc.id})');
        } catch (e) {
          print('⚠️ [SYNC] Error parsing cloud flashcard: $e');
        }
      }
    }
    
    print('📊 [SYNC] Total cloud flashcards pulled: ${allCloudFlashcards.length}');
    await _updateLocalFlashcards(allCloudFlashcards);
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
    final List<RecommendedFlashcard> allCloudRecommendations = [];
    
    // Get all language documents
    final languagesSnapshot = await _firestore
        .collection('users')
        .doc(userId)
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
          data['id'] = int.parse(recommendationDoc.id);
          data['languageCode'] = languageCode; // Ensure language code is set
          allCloudRecommendations.add(RecommendedFlashcard.fromMap(data));
          print('📥 [SYNC] Pulled cloud recommendation: ${data['term']} (${recommendationDoc.id})');
        } catch (e) {
          print('⚠️ [SYNC] Error parsing cloud recommendation: $e');
        }
      }
    }
    
    print('📊 [SYNC] Total cloud recommendations pulled: ${allCloudRecommendations.length}');
    await _updateLocalRecommendations(allCloudRecommendations);
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
    final localRecommendations = await _dbHelper.getAllRecommendations();
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