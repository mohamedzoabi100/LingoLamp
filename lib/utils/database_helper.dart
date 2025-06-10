// lib/utils/database_helper.dart
// ** UPDATED FILE WITH ADDITIONAL METHODS **

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/conversation_model.dart';
import '../models/chat_message_model.dart';
import '../models/flashcard_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  static Database? _database;

  DatabaseHelper._privateConstructor();

  // Database version incremented to handle schema change
  static const String _dbName = 'lingolamp_chat.db';
  static const int _dbVersion = 3;

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
  static const String colFlashcardOriginalText = 'original_text';
  static const String colFlashcardTranslatedText = 'translated_text';
  static const String colFlashcardSourceLanguage = 'source_language';
  static const String colFlashcardTargetLanguage = 'target_language';
  static const String colFlashcardCreatedAt = 'created_at';
  static const String colFlashcardLastStudied = 'last_studied';
  static const String colFlashcardTimesStudied = 'times_studied';
  static const String colFlashcardDifficulty = 'difficulty';
  static const String colFlashcardIsFavorite = 'is_favorite';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
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
        $colFlashcardOriginalText TEXT NOT NULL,
        $colFlashcardTranslatedText TEXT NOT NULL,
        $colFlashcardSourceLanguage TEXT NOT NULL,
        $colFlashcardTargetLanguage TEXT NOT NULL,
        $colFlashcardCreatedAt TEXT NOT NULL,
        $colFlashcardLastStudied TEXT NOT NULL,
        $colFlashcardTimesStudied INTEGER DEFAULT 0,
        $colFlashcardDifficulty INTEGER DEFAULT 2,
        $colFlashcardIsFavorite INTEGER DEFAULT 0
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
    return await db.insert(tableFlashcards, flashcard.toMap());
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

  Future<int> updateFlashcard(Flashcard flashcard) async {
    Database db = await instance.database;
    return await db.update(
      tableFlashcards,
      flashcard.toMap(),
      where: '$colFlashcardId = ?',
      whereArgs: [flashcard.id],
    );
  }

  // Original method - delete flashcard by ID
  Future<int> deleteFlashcardById(int id) async {
    Database db = await instance.database;
    return await db.delete(
      tableFlashcards,
      where: '$colFlashcardId = ?',
      whereArgs: [id],
    );
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

  // NEW METHOD - Clear all flashcards (for guest/user data separation)
  Future<int> clearAllFlashcards() async {
    Database db = await instance.database;
    return await db.delete(tableFlashcards);
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
}