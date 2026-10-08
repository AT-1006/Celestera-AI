// lib/models/message_model.dart
class MessageModel {
  final String id;
  final String chatId;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final String? imagePath;
  final String? documentPath;

  MessageModel({
    required this.id,
    required this.chatId,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.imagePath,
    this.documentPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'chatId': chatId,
      'content': content,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'imagePath': imagePath,
      'documentPath': documentPath,
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'],
      chatId: map['chatId'],
      content: map['content'],
      isUser: map['isUser'] ?? false,
      timestamp: DateTime.parse(map['timestamp']),
      imagePath: map['imagePath'],
      documentPath: map['documentPath'],
    );
  }
}