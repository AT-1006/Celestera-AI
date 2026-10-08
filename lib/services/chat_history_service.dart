import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/message_model.dart';

class ChatHistoryService {
  static ChatHistoryService? _instance;
  static ChatHistoryService get instance => _instance ??= ChatHistoryService._();
  
  ChatHistoryService._();

  Future<File> _getChatHistoryFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/chat_history.json');
  }

  Future<File> _getHistorySelectionFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/history_selection.json');
  }

  Future<File> _getHistoryFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/history.json');
  }

  Future<List<Map<String, dynamic>>> loadChatHistory() async {
    try {
      final file = await _getChatHistoryFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> data = jsonDecode(content);
        return data.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint(' Error loading chat history: $e');
    }
    return [];
  }

  Future<void> saveChatHistory(List<Map<String, dynamic>> history) async {
    try {
      final file = await _getChatHistoryFile();
      await file.writeAsString(jsonEncode(history));
      debugPrint(' Chat history saved: ${history.length} messages');
    } catch (e) {
      debugPrint(' Error saving chat history: $e');
    }
  }

  Future<String?> getCurrentHistoryName() async {
    try {
      final file = await _getHistorySelectionFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        return jsonDecode(content);
      }
    } catch (e) {
      debugPrint(' Error loading history selection: $e');
    }
    return null;
  }

  Future<void> setCurrentHistoryName(String historyName) async {
    try {
      final file = await _getHistorySelectionFile();
      await file.writeAsString(jsonEncode(historyName));
      debugPrint(' Current history name set to: $historyName');
    } catch (e) {
      debugPrint(' Error setting history selection: $e');
    }
  }

  Future<Map<String, List<Map<String, dynamic>>>> loadAllHistories() async {
    try {
      final file = await _getHistoryFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final Map<String, dynamic> data = jsonDecode(content);
        
        // Convert to proper type
        final Map<String, List<Map<String, dynamic>>> histories = {};
        data.forEach((key, value) {
          if (value is List) {
            histories[key] = value.cast<Map<String, dynamic>>();
          }
        });
        
        return histories;
      }
    } catch (e) {
      debugPrint(' Error loading all histories: $e');
    }
    return {};
  }

  Future<void> saveAllHistories(Map<String, List<Map<String, dynamic>>> histories) async {
    try {
      final file = await _getHistoryFile();
      await file.writeAsString(jsonEncode(histories));
      debugPrint(' All histories saved: ${histories.keys.length} history groups');
    } catch (e) {
      debugPrint(' Error saving all histories: $e');
    }
  }

  Future<void> addToHistory(String userPrompt, String botResponse) async {
    try {
      // Get current history name
      final historyName = await getCurrentHistoryName() ?? 'default';
      
      // Load all histories
      final histories = await loadAllHistories();
      
      // Ensure the history exists
      if (!histories.containsKey(historyName)) {
        histories[historyName] = [];
      }
      
      // Add new conversation
      histories[historyName]!.add({
        'user': userPrompt,
        'chatbot': botResponse,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      // Save all histories
      await saveAllHistories(histories);
      
      // Also add to chat log
      final chatHistory = await loadChatHistory();
      chatHistory.add({'role': 'user', 'content': userPrompt});
      chatHistory.add({'role': 'assistant', 'content': botResponse});
      await saveChatHistory(chatHistory);
      
      debugPrint(' Added to history "$historyName": $userPrompt');
    } catch (e) {
      debugPrint(' Error adding to history: $e');
    }
  }

  Future<void> createNewHistory(String historyName) async {
    try {
      final histories = await loadAllHistories();
      histories[historyName] = [];
      await saveAllHistories(histories);
      await setCurrentHistoryName(historyName);
      debugPrint(' Created new history: $historyName');
    } catch (e) {
      debugPrint(' Error creating new history: $e');
    }
  }

  Future<List<String>> getAllHistoryNames() async {
    final histories = await loadAllHistories();
    return histories.keys.toList();
  }

  Future<List<Map<String, dynamic>>> getHistory(String historyName) async {
    final histories = await loadAllHistories();
    return histories[historyName] ?? [];
  }

  Future<void> deleteHistory(String historyName) async {
    try {
      final histories = await loadAllHistories();
      histories.remove(historyName);
      await saveAllHistories(histories);
      debugPrint(' Deleted history: $historyName');
    } catch (e) {
      debugPrint(' Error deleting history: $e');
    }
  }

  Future<void> clearCurrentChatHistory() async {
    try {
      await saveChatHistory([]);
      debugPrint(' Current chat history cleared');
    } catch (e) {
      debugPrint(' Error clearing chat history: $e');
    }
  }
}
