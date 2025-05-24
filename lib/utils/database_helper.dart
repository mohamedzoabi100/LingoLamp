//lib/utils/database_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/conversation_model.dart';
import '../models/chat_message_model.dart';
import '../models/flashcard_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  static Database? _database;

  DatabaseHelper._privateConstructor();

  static const String _dbName = 'lingolamp_chat.db';
  static const int _dbVersion = 2; // Updated version for flashcards

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
  static const String colMessageTranslatedText = 'translated_text';

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
        $colMessageTranslatedText TEXT,
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
      // Add flashcards table for version 2
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
  }

  // --- Conversation Methods ---
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

  //--- Chat Message Methods ---
  Future<int> insertMessage(ChatMessage message) async {
    Database db = await instance.database;
    int messageId = await db.insert(tableMessages, message.toMap());

    //Update conversation's last_message_timestamp
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

  Future<int> deleteConversation(int id) async {
    Database db = await instance.database;
    //Deleting from the 'conversations' table will also delete associated messages
    //in the 'messages' table due to 'ON DELETE CASCADE' in the foreign key constraint.
    return await db.delete(
      tableConversations,
      where: '$colConversationId = ?',
      whereArgs: [id],
    );
  }

  // --- Flashcard Methods ---
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

  Future<List<Flashcard>> getFlashcardsByDifficulty(int difficulty) async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableFlashcards,
      where: '$colFlashcardDifficulty = ?',
      whereArgs: [difficulty],
      orderBy: '$colFlashcardLastStudied ASC',
    );
    return List.generate(maps.length, (i) {
      return Flashcard.fromMap(maps[i]);
    });
  }

  Future<List<Flashcard>> getFavoriteFlashcards() async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableFlashcards,
      where: '$colFlashcardIsFavorite = ?',
      whereArgs: [1],
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

  Future<int> deleteFlashcard(int id) async {
    Database db = await instance.database;
    return await db.delete(
      tableFlashcards,
      where: '$colFlashcardId = ?',
      whereArgs: [id],
    );
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

  Future<List<Flashcard>> getFlashcardsForStudy(int limit) async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableFlashcards,
      orderBy: '$colFlashcardLastStudied ASC, $colFlashcardTimesStudied ASC',
      limit: limit,
    );
    return List.generate(maps.length, (i) {
      return Flashcard.fromMap(maps[i]);
    });
  }
}