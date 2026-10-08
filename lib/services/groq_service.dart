import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/message_model.dart';
import '../config/app_config.dart';

class GroqService {
  String _apiKey;
  late final String _botName;
  late final String _userNickname;
  bool _usingBackupKey = false;
  
  GroqService({
    String? apiKey,
    String? botName,
    String? userNickname,
  }) : _apiKey = apiKey ?? AppConfig.groqApiKey {
    _botName = botName ?? AppConfig.defaultBotName;
    _userNickname = userNickname ?? AppConfig.defaultUserNickname;
  }

  // Switch to backup API key
  void _switchToBackupKey() {
    if (!_usingBackupKey) {
      debugPrint(' Groq: Switching to backup API key due to token error');
      _apiKey = AppConfig.groqBackupApiKey;
      _usingBackupKey = true;
    }
  }

  // Check if error is token-related
  bool _isTokenError(int statusCode, Map<String, dynamic> errorData) {
    if (statusCode == 401) return true; // Unauthorized
    if (statusCode == 429) return true; // Rate limit exceeded
    
    // Check error message for token-related keywords
    final error = errorData['error']?['message']?.toString().toLowerCase() ?? '';
    return error.contains('token') || 
           error.contains('quota') || 
           error.contains('limit') || 
           error.contains('insufficient') ||
           error.contains('exceeded');
  }

  String get _systemPrompt => """
Hello, I am $_userNickname, always call me with this name. 
You are a very accurate and advanced AI chatbot named $_botName which has real-time up-to-date information from the internet.

*** Provide answers in a professional way. Make sure to add full stops, commas, question marks, and use proper grammar. ***
*** Just answer the question from the provided data in a professional way. ***
""";

  String get _systemInfo => """
Use this real-time information if needed:
Day: ${DateTime.now().weekday == 1 ? 'Monday' : DateTime.now().weekday == 2 ? 'Tuesday' : DateTime.now().weekday == 3 ? 'Wednesday' : DateTime.now().weekday == 4 ? 'Thursday' : DateTime.now().weekday == 5 ? 'Friday' : DateTime.now().weekday == 6 ? 'Saturday' : 'Sunday'}
Date: ${DateTime.now().day}
Month: ${DateTime.now().month == 1 ? 'January' : DateTime.now().month == 2 ? 'February' : DateTime.now().month == 3 ? 'March' : DateTime.now().month == 4 ? 'April' : DateTime.now().month == 5 ? 'May' : DateTime.now().month == 6 ? 'June' : DateTime.now().month == 7 ? 'July' : DateTime.now().month == 8 ? 'August' : DateTime.now().month == 9 ? 'September' : DateTime.now().month == 10 ? 'October' : DateTime.now().month == 11 ? 'November' : 'December'}
Year: ${DateTime.now().year}
Time: ${DateTime.now().hour} hours, ${DateTime.now().minute} minutes, ${DateTime.now().second} seconds.
""";

  Future<String> _googleSearch(String query) async {
    try {
      // Using a simple search API for demonstration
      // In production, you might want to use Google Custom Search API
      final response = await http.get(
        Uri.parse('https://duckduckgo.com/html/?q=$query'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        },
      );

      if (response.statusCode == 200) {
        // Simple HTML parsing to extract search results
        final html = response.body;
        final results = _parseSearchResults(html);
        
        String searchContext = "The search results for '$query' are:\n[start]\n";
        for (int i = 0; i < results.length && i < 5; i++) {
          searchContext += "Title: ${results[i]['title']}\nDescription: ${results[i]['description']}\n\n";
        }
        searchContext += "[end]";
        
        return searchContext;
      } else {
        debugPrint('Search API error: ${response.statusCode}');
        return "Search temporarily unavailable. Using my knowledge base.";
      }
    } catch (e) {
      debugPrint('Search error: $e');
      return "Search temporarily unavailable. Using my knowledge base.";
    }
  }

  List<Map<String, String>> _parseSearchResults(String html) {
    final results = <Map<String, String>>[];
    
    // Simple regex parsing for DuckDuckGo results
    // This is a basic implementation - in production, use proper HTML parsing
    final regex = RegExp(r'<a[^>]*class="result__a"[^>]*>(.*?)</a>.*?<a[^>]*class="result__snippet"[^>]*>(.*?)</a>', dotAll: true);
    
    final matches = regex.allMatches(html);
    for (final match in matches) {
      if (match.groupCount >= 2) {
        final title = _cleanHtml(match.group(1) ?? '');
        final description = _cleanHtml(match.group(2) ?? '');
        
        if (title.isNotEmpty && description.isNotEmpty) {
          results.add({
            'title': title,
            'description': description,
          });
        }
      }
    }
    
    return results;
  }

  String _cleanHtml(String html) {
    // Remove HTML tags and decode entities
    String clean = html.replaceAll(RegExp(r'<[^>]*>'), '');
    clean = clean.replaceAll('&amp;', '&');
    clean = clean.replaceAll('&lt;', '<');
    clean = clean.replaceAll('&gt;', '>');
    clean = clean.replaceAll('&quot;', '"');
    clean = clean.replaceAll('&#39;', "'");
    return clean.trim();
  }

  String _cleanAnswer(String answer) {
    final lines = answer.split('\n');
    final nonEmptyLines = lines.where((line) => line.trim().isNotEmpty).toList();
    return nonEmptyLines.join('\n');
  }

  Future<String> getChatResponse(
    String userPrompt, {
    List<MessageModel>? conversationHistory,
    String? imagePath,
    String? systemPrompt,
  }) async {
    try {
      debugPrint(' Groq: Getting response for: $userPrompt');
      
      // Get search context
      final searchContext = await _googleSearch(userPrompt);
      
      // Prepare messages
      final messages = <Map<String, String>>[];
      
      // Add system messages
      messages.add({'role': 'system', 'content': systemPrompt ?? _systemPrompt});
      messages.add({'role': 'system', 'content': searchContext});
      messages.add({'role': 'system', 'content': _systemInfo});
      
      // Add conversation history
      if (conversationHistory != null) {
        final historyLength = conversationHistory.length;
        final startIndex = historyLength > AppConfig.maxConversationHistory 
            ? historyLength - AppConfig.maxConversationHistory 
            : 0;
        final recentMessages = conversationHistory.sublist(startIndex);
        
        for (final message in recentMessages) { // Take last N messages for context
          messages.add({
            'role': message.isUser ? 'user' : 'assistant',
            'content': message.content,
          });
        }
      }
      
      // Add current user message
      messages.add({'role': 'user', 'content': userPrompt});
      
      debugPrint(' Groq: Sending request to API...');
      debugPrint(' Groq: Total messages: ${messages.length}');
      
      // Try first API call
      String? response = await _makeApiCall(messages);
      
      // If first call fails and we haven't tried backup key yet, try with backup
      if (response == null && !_usingBackupKey) {
        debugPrint(' Groq: First API call failed, trying backup key...');
        _switchToBackupKey();
        response = await _makeApiCall(messages);
      }
      
      if (response != null) {
        return response;
      } else {
        return 'Sorry, I encountered an error while processing your request. Please try again.';
      }
    } catch (e) {
      debugPrint(' Groq Service Error: $e');
      return 'Sorry, I encountered an error while processing your request. Please try again.';
    }
  }

  Future<String?> _makeApiCall(List<Map<String, String>> messages) async {
    try {
      // Make API request
      final response = await http.post(
        Uri.parse('${AppConfig.groqBaseUrl}/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': AppConfig.groqModel,
          'messages': messages,
          'temperature': AppConfig.temperature,
          'max_tokens': AppConfig.maxResponseTokens,
          'top_p': AppConfig.topP,
          'stream': false,
        }),
      );

      debugPrint(' Groq: Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final answer = data['choices'][0]['message']['content'] as String;
        
        debugPrint(' Groq: Response received successfully');
        debugPrint(' Groq: Response length: ${answer.length}');
        
        return _cleanAnswer(answer);
      } else {
        final errorData = jsonDecode(response.body);
        debugPrint(' Groq API Error: ${response.statusCode}');
        debugPrint(' Groq Error: ${errorData}');
        
        // Check if this is a token error that should trigger fallback
        if (_isTokenError(response.statusCode, errorData)) {
          debugPrint(' Groq: Token error detected, fallback should be triggered');
          return null; // Return null to trigger fallback
        }
        
        // For other errors, return error message
        return 'Sorry, I encountered an error while processing your request. Please try again.';
      }
    } catch (e) {
      debugPrint(' Groq API Call Error: $e');
      return null; // Return null to trigger fallback
    }
  }

  Future<String> generateTitle(String firstMessage) async {
    try {
      final response = await getChatResponse(
        'Generate a short, descriptive title (max 50 characters) for this conversation: "$firstMessage"',
        systemPrompt: 'You are a title generator. Create concise, descriptive titles for conversations. Return only the title, no extra text.',
      );
      
      // Clean up the title
      String title = response.trim();
      // Remove leading quotes
      if (title.startsWith('"') || title.startsWith("'")) {
        title = title.substring(1);
      }
      // Remove trailing quotes
      if (title.endsWith('"') || title.endsWith("'")) {
        title = title.substring(0, title.length - 1);
      }
      // Keep only first line
      final lines = title.split('\n\n');
      title = lines.first;
      
      return title.length > 50 ? '${title.substring(0, 47)}...' : title;
    } catch (e) {
      debugPrint(' Error generating title: $e');
      return firstMessage.length > 30
          ? '${firstMessage.substring(0, 27)}...'
          : firstMessage;
    }
  }
}
