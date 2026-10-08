import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../models/message_model.dart';
import '../models/chat_model.dart';

class FirebaseChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String _userId;

  FirebaseChatService(this._userId);

  // Chat operations
  Future<void> createChat(ChatModel chat) async {
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('chats')
        .doc(chat.id)
        .set(chat.toMap());
  }

  Future<List<ChatModel>> getAllChats() async {
    debugPrint('🔍 Firebase: Getting all chats for user: $_userId');
    final snapshot = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('chats')
        .orderBy('updatedAt', descending: true)
        .get();

    debugPrint('🔍 Firebase: Found ${snapshot.docs.length} documents');
    
    return snapshot.docs
        .map((doc) => ChatModel.fromMap({...doc.data(), 'id': doc.id}))
        .toList();
  }

  Future<void> updateChat(ChatModel chat) async {
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('chats')
        .doc(chat.id)
        .update(chat.toMap());
  }

  Future<void> deleteChat(String chatId) async {
    // Delete all messages first
    final messagesSnapshot = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .get();

    for (final doc in messagesSnapshot.docs) {
      await doc.reference.delete();
    }

    // Delete the chat
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('chats')
        .doc(chatId)
        .delete();
  }

  Future<void> clearAllChats() async {
    final chatsSnapshot = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('chats')
        .get();

    for (final chatDoc in chatsSnapshot.docs) {
      // Delete all messages in this chat
      final messagesSnapshot = await chatDoc.reference
          .collection('messages')
          .get();

      for (final messageDoc in messagesSnapshot.docs) {
        await messageDoc.reference.delete();
      }

      // Delete the chat
      await chatDoc.reference.delete();
    }
  }

  // Message operations
  Future<void> sendMessage(MessageModel message) async {
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('chats')
        .doc(message.chatId)
        .collection('messages')
        .doc(message.id)
        .set(message.toMap());
  }

  Future<List<MessageModel>> getMessages(String chatId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .get();

    return snapshot.docs
        .map((doc) => MessageModel.fromMap({...doc.data(), 'id': doc.id}))
        .toList();
  }

  Future<void> clearChatMessages(String chatId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .get();

    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  // Image upload operations
  Future<String?> uploadImage(File imageFile, String chatId) async {
    try {
      final ref = _storage
          .ref()
          .child('users')
          .child(_userId)
          .child('chats')
          .child(chatId)
          .child('images')
          .child('${const Uuid().v4()}.jpg');

      final uploadTask = await ref.putFile(imageFile);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Image upload error: $e');
      return null;
    }
  }

  Future<void> deleteImage(String imageUrl) async {
    try {
      final ref = FirebaseStorage.instance.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      print('Image delete error: $e');
    }
  }

  // Document upload operations
  Future<String?> uploadDocument(File documentFile, String chatId) async {
    try {
      final ref = _storage
          .ref()
          .child('chats')
          .child(chatId)
          .child('documents')
          .child('${const Uuid().v4()}_${documentFile.path.split('/').last}');

      final uploadTask = await ref.putFile(documentFile);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Document upload error: $e');
      return null;
    }
  }

  // Stream for real-time updates
  Stream<List<MessageModel>> getMessagesStream(String chatId) {
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MessageModel.fromMap({...doc.data(), 'id': doc.id}))
            .toList());
  }

  Stream<List<ChatModel>> getChatsStream() {
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('chats')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatModel.fromMap({...doc.data(), 'id': doc.id}))
            .toList());
  }
}
