import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/message_model.dart';
import '../models/chat_model.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('chatbot.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE chats (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        chat_id TEXT NOT NULL,
        content TEXT NOT NULL,
        is_user INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        image_path TEXT,
        FOREIGN KEY (chat_id) REFERENCES chats (id) ON DELETE CASCADE
      )
    ''');
  }

  // Chat operations
  Future<void> insertChat(ChatModel chat) async {
    final db = await database;
    await db.insert('chats', chat.toMap());
  }

  Future<List<ChatModel>> getAllChats() async {
    final db = await database;
    final maps = await db.query(
      'chats',
      orderBy: 'updated_at DESC',
    );
    return maps.map((map) => ChatModel.fromMap(map)).toList();
  }

  Future<void> updateChat(ChatModel chat) async {
    final db = await database;
    await db.update(
      'chats',
      chat.toMap(),
      where: 'id = ?',
      whereArgs: [chat.id],
    );
  }

  Future<void> deleteChat(String chatId) async {
    final db = await database;
    await db.delete(
      'messages',
      where: 'chat_id = ?',
      whereArgs: [chatId],
    );
    await db.delete(
      'chats',
      where: 'id = ?',
      whereArgs: [chatId],
    );
  }

  Future<void> clearAllChats() async {
    final db = await database;
    await db.delete('messages');
    await db.delete('chats');
  }

  // Message operations
  Future<void> insertMessage(MessageModel message) async {
    final db = await database;
    await db.insert('messages', message.toMap());
  }

  Future<List<MessageModel>> getMessages(String chatId) async {
    final db = await database;
    final maps = await db.query(
      'messages',
      where: 'chat_id = ?',
      whereArgs: [chatId],
      orderBy: 'timestamp ASC',
    );
    return maps.map((map) => MessageModel.fromMap(map)).toList();
  }

  Future<void> clearChatMessages(String chatId) async {
    final db = await database;
    await db.delete(
      'messages',
      where: 'chat_id = ?',
      whereArgs: [chatId],
    );
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}