import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/message_model.dart';

class AIService {
  // Configure via --dart-define=COHERE_API_KEY=... or replace locally
  static const String _cohereApiKey = String.fromEnvironment('COHERE_API_KEY', defaultValue: 'YOUR_COHERE_API_KEY_HERE');
  static const String _cohereEndpoint = 'https://api.cohere.ai/v1/chat';

  Future<String> getChatResponse(
    String userMessage, {
    List<MessageModel>? conversationHistory,
    String? imagePath,
    String? systemPrompt,
  }) async {
    try {
      debugPrint('🤖 Getting AI response for: $userMessage');

      // Build conversation history
      final List<Map<String, String>> chatHistory = [];
      
      if (conversationHistory != null && conversationHistory.length > 1) {
        // Take last 10 messages for context
        final recentMessages = conversationHistory.length > 10
            ? conversationHistory.sublist(conversationHistory.length - 10)
            : conversationHistory;

        for (var msg in recentMessages) {
          if (msg.content.isNotEmpty) {
            chatHistory.add({
              'role': msg.isUser ? 'USER' : 'CHATBOT',
              'message': msg.content,
            });
          }
        }
      }

      // Prepare request body
      final requestBody = {
        'message': userMessage,
        'model': 'command-r-plus-08-2024',
        'temperature': 0.7,
        'chat_history': chatHistory,
        'preamble': systemPrompt ?? 'You are a helpful AI assistant. Be friendly, professional, and provide accurate information.',
      };

      // If image is provided, add context about it
      if (imagePath != null) {
        requestBody['message'] =
            '$userMessage\n\n[User has attached an image]';
      }

      debugPrint('📤 Sending request to Cohere API...');
      
      final response = await http.post(
        Uri.parse(_cohereEndpoint),
        headers: {
          'Authorization': 'Bearer $_cohereApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      debugPrint('📥 Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final responseText = data['text'] ?? 'No response from AI';
        debugPrint('✅ AI Response received: ${responseText.substring(0, 50)}...');
        return responseText;
      } else {
        debugPrint('❌ API Error: ${response.statusCode} - ${response.body}');
        throw Exception('API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ AI Service Error: $e');
      throw Exception('Failed to get AI response: $e');
    }
  }

  Future<String> generateTitle(String firstMessage) async {
    try {
      final response = await http.post(
        Uri.parse(_cohereEndpoint),
        headers: {
          'Authorization': 'Bearer $_cohereApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'message':
              'Generate a short, concise title (max 5 words) for this conversation: "$firstMessage"',
          'model': 'command-r-plus-08-2024',
          'temperature': 0.5,
          'max_tokens': 20,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String title = data['text'] ?? 'Chat';
        
        // Clean up the title
        title = title
            .replaceAll('"', '')
            .replaceAll('Title:', '')
            .replaceAll('title:', '')
            .trim();
        
        return title;
      } else {
        return 'Chat ${DateTime.now().day}/${DateTime.now().month}';
      }
    } catch (e) {
      return 'Chat ${DateTime.now().day}/${DateTime.now().month}';
    }
  }

  // Alternative: Use local processing for simple queries
  String? getLocalResponse(String query) {
    final lowerQuery = query.toLowerCase().trim();

    if (lowerQuery.contains('hello') ||
        lowerQuery.contains('hi') ||
        lowerQuery.contains('hey')) {
      return 'Hello! How can I help you today?';
    }

    if (lowerQuery.contains('how are you')) {
      return "I'm doing great! Thanks for asking. How can I assist you?";
    }

    if (lowerQuery.contains('your name') || lowerQuery.contains('who are you')) {
      return "I'm your AI assistant, here to help you with any questions or tasks!";
    }

    return null; // Return null to indicate no local response available
  }
}