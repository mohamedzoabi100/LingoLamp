// lib/utils/database_helper.dart
// ** UPDATED FILE WITH ADDITIONAL METHODS **

import 'dart:async';
import 'package:rxdart/rxdart.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import '../models/conversation_model.dart';
import '../models/chat_message_model.dart';
import '../models/flashcard_model.dart';
import '../models/spaced_repetition_model.dart';
import '../models/recommended_flashcard_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  static Database? _database;

  // StreamController for flashcards - Now a BehaviorSubject
  final _flashcardsController = BehaviorSubject<List<Flashcard>>();
  Stream<List<Flashcard>> get flashcardsStream => _flashcardsController.stream;

  // StreamController for recommended flashcards
  final _recommendedController = BehaviorSubject<List<RecommendedFlashcard>>.seeded(const <RecommendedFlashcard>[]);
  Stream<List<RecommendedFlashcard>> get recommendedStream => _recommendedController.stream;

  // StreamController for chat messages
  final _chatController = BehaviorSubject<List<ChatMessage>>.seeded(const <ChatMessage>[]);
  Stream<List<ChatMessage>> get chatStream => _chatController.stream;

  DatabaseHelper._privateConstructor();

  // Database version incremented to handle schema change
  static const String _dbName = 'lingolamp_chat.db';
  static const int _dbVersion = 7;

  static const String tableConversations = 'conversations';
  static const String colConversationId = 'id';
  static const String colConversationTitle = 'title';
  static const String colConversationCreatedAt = 'created_at';
  static const String colConversationLastMessageTimestamp = 'last_message_timestamp';

  static const String tableMessages = 'messages';
  static const String colMessageId = 'id';
  static const String colMessageConversationId = 'conversation_id';
  static const String colMessageText = 'text';
  static const String colMessageIsUser = 'is_user_message';
  static const String colMessageTimestamp = 'timestamp';
  static const String colMessageOriginalQuery = 'original_query';

  // Flashcards table constants
  static const String tableFlashcards = 'flashcards';
  static const String colFlashcardId = 'id';
  static const String colFlashcardUuid = 'uuid';
  static const String colFlashcardOriginalText = 'original_text';
  static const String colFlashcardTranslatedText = 'translated_text';
  static const String colFlashcardSourceLanguage = 'source_language';
  static const String colFlashcardTargetLanguage = 'target_language';
  static const String colFlashcardCreatedAt = 'created_at';
  static const String colFlashcardLastStudied = 'last_studied';
  static const String colFlashcardTimesStudied = 'times_studied';
  static const String colFlashcardDifficulty = 'difficulty';
  static const String colFlashcardIsFavorite = 'is_favorite';
  static const String colFlashcardCategory = 'category';
  static const String colFlashcardTags = 'tags';

  // Spaced repetition table constants
  static const String tableSpacedRepetition = 'spaced_repetition';
  static const String colSpacedRepetitionId = 'id';
  static const String colSpacedRepetitionFlashcardId = 'flashcard_id';
  static const String colSpacedRepetitionEaseFactor = 'ease_factor';
  static const String colSpacedRepetitionInterval = 'interval';
  static const String colSpacedRepetitionRepetitions = 'repetitions';
  static const String colSpacedRepetitionLapses = 'lapses';
  static const String colSpacedRepetitionNextReview = 'next_review';
  static const String colSpacedRepetitionLastReviewed = 'last_reviewed';
  static const String colSpacedRepetitionLastReviewQuality = 'last_review_quality';

  // === NEW: Recommended flashcards table ===
  static const String tableRecommended = 'recommended_flashcards';
  static const String colRecommendedId = 'id';
  static const String colRecommendedTerm = 'term';
  static const String colRecommendedContext = 'context';
  static const String colRecommendedSource = 'source';
  static const String colRecommendedWeight = 'weight';
  static const String colRecommendedCreatedAt = 'created_at';
  static const String colRecommendedUpdatedAt = 'updated_at';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    // Prime the stream with initial data as soon as the db is ready
    _onFlashcardsChanged();
    _onChatChanged();
    _onRecommendedChanged();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _dbName);
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableConversations (
        $colConversationId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colConversationTitle TEXT,
        $colConversationCreatedAt TEXT NOT NULL,
        $colConversationLastMessageTimestamp TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableMessages (
        $colMessageId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colMessageConversationId INTEGER NOT NULL,
        $colMessageText TEXT NOT NULL,
        $colMessageIsUser INTEGER NOT NULL, 
        $colMessageTimestamp TEXT NOT NULL,
        $colMessageOriginalQuery TEXT,
        FOREIGN KEY ($colMessageConversationId) REFERENCES $tableConversations ($colConversationId) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableFlashcards (
        $colFlashcardId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colFlashcardUuid TEXT UNIQUE,
        $colFlashcardOriginalText TEXT NOT NULL,
        $colFlashcardTranslatedText TEXT NOT NULL,
        $colFlashcardSourceLanguage TEXT NOT NULL,
        $colFlashcardTargetLanguage TEXT NOT NULL,
        $colFlashcardCreatedAt TEXT NOT NULL,
        $colFlashcardLastStudied TEXT NOT NULL,
        $colFlashcardTimesStudied INTEGER DEFAULT 0,
        $colFlashcardDifficulty INTEGER DEFAULT 2,
        $colFlashcardIsFavorite INTEGER DEFAULT 0,
        $colFlashcardCategory TEXT,
        $colFlashcardTags TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableSpacedRepetition (
        $colSpacedRepetitionId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colSpacedRepetitionFlashcardId INTEGER NOT NULL,
        $colSpacedRepetitionEaseFactor REAL DEFAULT 2.5,
        $colSpacedRepetitionInterval INTEGER DEFAULT 0,
        $colSpacedRepetitionRepetitions INTEGER DEFAULT 0,
        $colSpacedRepetitionLapses INTEGER DEFAULT 0,
        $colSpacedRepetitionNextReview TEXT,
        $colSpacedRepetitionLastReviewed TEXT NOT NULL,
        $colSpacedRepetitionLastReviewQuality INTEGER,
        FOREIGN KEY ($colSpacedRepetitionFlashcardId) REFERENCES $tableFlashcards ($colFlashcardId) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableRecommended (
        $colRecommendedId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colRecommendedTerm TEXT NOT NULL,
        $colRecommendedContext TEXT NOT NULL,
        $colRecommendedSource TEXT NOT NULL,
        $colRecommendedWeight REAL NOT NULL,
        $colRecommendedCreatedAt TEXT NOT NULL,
        $colRecommendedUpdatedAt TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _onCreate(db, newVersion); // Re-create if starting from a very old version
    }
    // Handles the upgrade from version 2 to 3 by adding the new column
    if (oldVersion == 2) {
      await db.execute('ALTER TABLE $tableMessages ADD COLUMN $colMessageOriginalQuery TEXT');
    }
    // Handles the upgrade from version 3 to 4 by adding new flashcard columns and spaced repetition table
    if (oldVersion == 3) {
      await db.execute('ALTER TABLE $tableFlashcards ADD COLUMN $colFlashcardCategory TEXT');
      await db.execute('ALTER TABLE $tableFlashcards ADD COLUMN $colFlashcardTags TEXT');
      
      await db.execute('''
        CREATE TABLE $tableSpacedRepetition (
          $colSpacedRepetitionId INTEGER PRIMARY KEY AUTOINCREMENT,
          $colSpacedRepetitionFlashcardId INTEGER NOT NULL,
          $colSpacedRepetitionEaseFactor REAL DEFAULT 2.5,
          $colSpacedRepetitionInterval INTEGER DEFAULT 0,
          $colSpacedRepetitionRepetitions INTEGER DEFAULT 0,
          $colSpacedRepetitionLapses INTEGER DEFAULT 0,
          $colSpacedRepetitionNextReview TEXT,
          $colSpacedRepetitionLastReviewed TEXT NOT NULL,
          $colSpacedRepetitionLastReviewQuality INTEGER,
          FOREIGN KEY ($colSpacedRepetitionFlashcardId) REFERENCES $tableFlashcards ($colFlashcardId) ON DELETE CASCADE
        )
      ''');
    }
    // Handles the upgrade from version 4 to 5 by fixing any schema inconsistencies
    if (oldVersion == 4) {
      // Check if last_modified column exists and remove it if it does (it should be last_message_timestamp)
      try {
        await db.execute('ALTER TABLE $tableConversations DROP COLUMN last_modified');
      } catch (e) {
        // Column doesn't exist, which is fine
      }
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE $tableFlashcards ADD COLUMN $colFlashcardUuid TEXT');
      // Populate uuid for existing rows that don't have one
      final List<Map<String, dynamic>> flashcardsToUpdate = await db.query(
        tableFlashcards,
        where: '$colFlashcardUuid IS NULL',
      );
      
      final batch = db.batch();
      const uuidGenerator = Uuid();
      
      for (final card in flashcardsToUpdate) {
        batch.update(
          tableFlashcards,
          {'$colFlashcardUuid': uuidGenerator.v4()},
          where: '$colFlashcardId = ?',
          whereArgs: [card['id']],
        );
      }
      await batch.commit();
    }
    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE $tableRecommended (
          $colRecommendedId INTEGER PRIMARY KEY AUTOINCREMENT,
          $colRecommendedTerm TEXT NOT NULL,
          $colRecommendedContext TEXT NOT NULL,
          $colRecommendedSource TEXT NOT NULL,
          $colRecommendedWeight REAL NOT NULL,
          $colRecommendedCreatedAt TEXT NOT NULL,
          $colRecommendedUpdatedAt TEXT NOT NULL
        )
      ''');
    }
  }

  Future<void> _onFlashcardsChanged() async {
    final flashcards = await getAllFlashcards();
    _flashcardsController.add(flashcards);
  }

  Future<void> _onRecommendedChanged() async {
    final recs = await getAllRecommendedFlashcards();
    _recommendedController.add(recs);
  }

  Future<void> _onChatChanged() async {
    Database db = await instance.database;
    final rows = await db.query(
      tableMessages,
      orderBy: '$colMessageTimestamp DESC',
    );
    final messages = rows.map(ChatMessage.fromMap).toList();
    _chatController.add(messages);
  }

  // === CONVERSATION METHODS ===
  
  Future<int> insertConversation(Conversation conversation) async {
    Database db = await instance.database;
    return await db.insert(tableConversations, conversation.toMap());
  }

  Future<List<Conversation>> getAllConversations() async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableConversations,
      orderBy: '$colConversationLastMessageTimestamp DESC',
    );
    return List.generate(maps.length, (i) {
      return Conversation.fromMap(maps[i]);
    });
  }

  Future<int> updateConversation(Conversation conversation) async {
    Database db = await instance.database;
    return await db.update(
      tableConversations,
      conversation.toMap(),
      where: '$colConversationId = ?',
      whereArgs: [conversation.id],
    );
  }

  Future<Conversation?> getConversation(int id) async {
    Database db = await instance.database;
    List<Map<String, dynamic>> maps = await db.query(
      tableConversations,
      where: '$colConversationId = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Conversation.fromMap(maps.first);
    }
    return null;
  }

  Future<int> deleteConversation(int id) async {
    Database db = await instance.database;
    return await db.delete(
      tableConversations,
      where: '$colConversationId = ?',
      whereArgs: [id],
    );
  }

  // === CHAT MESSAGE METHODS ===
  
  Future<int> insertMessage(ChatMessage message) async {
    Database db = await instance.database;
    int messageId = await db.insert(tableMessages, message.toMap());

    if (messageId > 0) {
      Conversation? convo = await getConversation(message.conversationId);
      if (convo != null) {
        convo.lastMessageTimestamp = message.timestamp;
        await updateConversation(convo);
      }
    }
    _onChatChanged();
    return messageId;
  }

  Future<List<ChatMessage>> getMessagesForConversation(int conversationId) async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableMessages,
      where: '$colMessageConversationId = ?',
      whereArgs: [conversationId],
      orderBy: '$colMessageTimestamp ASC',
    );
    return List.generate(maps.length, (i) {
      return ChatMessage.fromMap(maps[i]);
    });
  }

  // === FLASHCARD METHODS ===
  
  Future<int> insertFlashcard(Flashcard flashcard) async {
    Database db = await instance.database;
    final id = await db.insert(tableFlashcards, flashcard.toMap());
    _onFlashcardsChanged();
    return id;
  }

  Future<List<Flashcard>> getAllFlashcards() async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableFlashcards,
      orderBy: '$colFlashcardCreatedAt DESC',
    );
    return List.generate(maps.length, (i) {
      return Flashcard.fromMap(maps[i]);
    });
  }

  Future<List<Flashcard>> getFlashcardsPaginated({required int limit, required int offset}) async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableFlashcards,
      orderBy: '$colFlashcardCreatedAt DESC',
      limit: limit,
      offset: offset,
    );
    return List.generate(maps.length, (i) {
      return Flashcard.fromMap(maps[i]);
    });
  }

  Future<int> updateFlashcard(Flashcard flashcard) async {
    Database db = await instance.database;
    final result = await db.update(
      tableFlashcards,
      flashcard.toMap(),
      where: '$colFlashcardId = ?',
      whereArgs: [flashcard.id],
    );
    _onFlashcardsChanged();
    return result;
  }

  // Original method - delete flashcard by ID
  Future<int> deleteFlashcardById(int id) async {
    Database db = await instance.database;
    final result = await db.delete(
      tableFlashcards,
      where: '$colFlashcardId = ?',
      whereArgs: [id],
    );
    _onFlashcardsChanged();
    return result;
  }

  // NEW METHOD - Delete flashcard by text content (for syncing purposes)
  Future<int> deleteFlashcard(String originalText, String translatedText) async {
    Database db = await instance.database;
    return await db.delete(
      tableFlashcards,
      where: '$colFlashcardOriginalText = ? AND $colFlashcardTranslatedText = ?',
      whereArgs: [originalText, translatedText],
    );
  }

  // NEW METHOD - Delete flashcard by UUID
  Future<int> deleteFlashcardByUuid(String uuid) async {
    Database db = await instance.database;
    final result = await db.delete(
      tableFlashcards,
      where: '$colFlashcardUuid = ?',
      whereArgs: [uuid],
    );
    _onFlashcardsChanged();
    return result;
  }

  // NEW METHOD - Clear all flashcards (for guest/user data separation)
  Future<int> clearAllFlashcards() async {
    Database db = await instance.database;
    final result = await db.delete(tableFlashcards);
    _onFlashcardsChanged();
    return result;
  }

  Future<bool> flashcardExists(String originalText, String translatedText) async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableFlashcards,
      where: '$colFlashcardOriginalText = ? AND $colFlashcardTranslatedText = ?',
      whereArgs: [originalText, translatedText],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  // === SPACED REPETITION METHODS ===
  
  Future<int> insertSpacedRepetitionCard(SpacedRepetitionCard card) async {
    Database db = await instance.database;
    return await db.insert(tableSpacedRepetition, card.toMap());
  }

  Future<List<SpacedRepetitionCard>> getAllSpacedRepetitionCards() async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableSpacedRepetition,
      orderBy: '$colSpacedRepetitionNextReview ASC',
    );
    return List.generate(maps.length, (i) {
      return SpacedRepetitionCard.fromMap(maps[i]);
    });
  }

  Future<SpacedRepetitionCard?> getSpacedRepetitionCard(int flashcardId) async {
    Database db = await instance.database;
    List<Map<String, dynamic>> maps = await db.query(
      tableSpacedRepetition,
      where: '$colSpacedRepetitionFlashcardId = ?',
      whereArgs: [flashcardId],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return SpacedRepetitionCard.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateSpacedRepetitionCard(SpacedRepetitionCard card) async {
    Database db = await instance.database;
    return await db.update(
      tableSpacedRepetition,
      card.toMap(),
      where: '$colSpacedRepetitionId = ?',
      whereArgs: [card.id],
    );
  }

  Future<int> deleteSpacedRepetitionCard(int id) async {
    Database db = await instance.database;
    return await db.delete(
      tableSpacedRepetition,
      where: '$colSpacedRepetitionId = ?',
      whereArgs: [id],
    );
  }

  Future<List<SpacedRepetitionCard>> getDueSpacedRepetitionCards() async {
    Database db = await instance.database;
    final now = DateTime.now().toIso8601String();
    final List<Map<String, dynamic>> maps = await db.query(
      tableSpacedRepetition,
      where: '$colSpacedRepetitionNextReview IS NULL OR $colSpacedRepetitionNextReview <= ?',
      whereArgs: [now],
      orderBy: '$colSpacedRepetitionNextReview ASC',
    );
    return List.generate(maps.length, (i) {
      return SpacedRepetitionCard.fromMap(maps[i]);
    });
  }

  Future<List<SpacedRepetitionCard>> getTodaySpacedRepetitionCards() async {
    Database db = await instance.database;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    
    final List<Map<String, dynamic>> maps = await db.query(
      tableSpacedRepetition,
      where: '$colSpacedRepetitionNextReview IS NULL OR ($colSpacedRepetitionNextReview >= ? AND $colSpacedRepetitionNextReview < ?)',
      whereArgs: [today.toIso8601String(), tomorrow.toIso8601String()],
      orderBy: '$colSpacedRepetitionNextReview ASC',
    );
    return List.generate(maps.length, (i) {
      return SpacedRepetitionCard.fromMap(maps[i]);
    });
  }

  Future<void> clearAllSpacedRepetitionCards() async {
    Database db = await instance.database;
    await db.delete(tableSpacedRepetition);
  }

  Future<Flashcard?> getFlashcardByUuid(String uuid) async {
    Database db = await instance.database;
    final maps = await db.query(
      tableFlashcards,
      where: '$colFlashcardUuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    if (maps.isNotEmpty) return Flashcard.fromMap(maps.first);
    return null;
  }

  Future<int> upsertSpacedRepetitionCard(SpacedRepetitionCard card) async {
    if (card.id != null) {
      return await updateSpacedRepetitionCard(card);
    }
    // If a card exists for this flashcardId update instead of insert duplicate
    final existing = await getSpacedRepetitionCard(card.flashcardId);
    if (existing != null) {
      final updated = card.copyWith(id: existing.id);
      return await updateSpacedRepetitionCard(updated);
    } else {
      return await insertSpacedRepetitionCard(card);
    }
  }

  // === RECOMMENDED FLASHCARD METHODS ===
  Future<int> upsertRecommendedFlashcard(RecommendedFlashcard card) async {
    Database db = await instance.database;
    // Try update first
    final existing = await db.query(
      tableRecommended,
      where: '$colRecommendedTerm = ?',
      whereArgs: [card.term],
      limit: 1,
    );
    int result;
    if (existing.isNotEmpty) {
      result = await db.update(
        tableRecommended,
        card.copyWith(id: existing.first[colRecommendedId] as int).toMap(),
        where: '$colRecommendedId = ?',
        whereArgs: [existing.first[colRecommendedId]],
      );
    } else {
      result = await db.insert(tableRecommended, card.toMap());
    }
    _onRecommendedChanged();
    return result;
  }

  Future<List<RecommendedFlashcard>> getAllRecommendedFlashcards() async {
    Database db = await instance.database;
    final maps = await db.query(
      tableRecommended,
      orderBy: '$colRecommendedWeight DESC',
    );
    return maps.map(RecommendedFlashcard.fromMap).toList();
  }

  Future<int> deleteRecommended(int id) async {
    Database db = await instance.database;
    final result = await db.delete(
      tableRecommended,
      where: '$colRecommendedId = ?',
      whereArgs: [id],
    );
    _onRecommendedChanged();
    return result;
  }

  Future<int> clearAllRecommended() async {
    Database db = await instance.database;
    final result = await db.delete(tableRecommended);
    _onRecommendedChanged();
    return result;
  }

  void dispose() {
    _flashcardsController.close();
    _recommendedController.close();
    _chatController.close();
  }
}