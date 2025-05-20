//lib/utils/database_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/conversation_model.dart';
import '../models/chat_message_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  static Database? _database;

  DatabaseHelper._privateConstructor();

  static const String _dbName = 'lingolamp_chat.db';
  static const int _dbVersion = 1;

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
}