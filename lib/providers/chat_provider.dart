import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import '../models/message_model.dart';
import '../models/chat_model.dart';
import '../services/database_service.dart';
import '../services/firebase_chat_service.dart';
import '../services/ai_services.dart';
import '../services/chat_lock_service.dart';
import '../services/chatbot_mode_service.dart';
import '../services/voice_service.dart';
import '../services/command_processor.dart';
import '../services/nlp_classifier.dart' as nlp;
import '../services/image_generation_service.dart';
import '../services/persona_service.dart';
import '../services/document_service.dart';
import '../services/groq_service.dart';
import '../services/user_profile_service.dart';
import '../services/chat_history_service.dart';
import '../services/bot_config_service.dart';
import '../config/app_config.dart';

class ChatProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;
  final AIService _aiService = AIService();
  final ChatLockService _chatLockService = ChatLockService();
  final ChatbotModeService _chatbotModeService = ChatbotModeService();
  final VoiceService _voiceService = VoiceService();
  final CommandProcessor _commandProcessor = CommandProcessor();
  final ImageGenerationService _imageService = ImageGenerationService();
  late FirebaseChatService _firebaseChatService;
  
  // Groq and related services
  late GroqService _groqService;
  final UserProfileService _userProfileService = UserProfileService.instance;
  final ChatHistoryService _chatHistoryService = ChatHistoryService.instance;
  final BotConfigService _botConfigService = BotConfigService.instance;
  
  bool _useGroqService = AppConfig.useGroqService; // Toggle between AI services
  
  List<ChatModel> _chats = [];
  ChatModel? _currentChat;
  List<MessageModel> _messages = [];
  bool _isLoading = false;
  bool _isTyping = false;
  bool _isGeneratingImage = false;
  String? _currentUserId;
  BotPersona _currentPersona = BotPersona.general;
  String? _documentContext;
  File? _attachedDocument;

  List<ChatModel> get chats => _chats;
  ChatModel? get currentChat => _currentChat;
  List<MessageModel> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isTyping => _isTyping;
  bool get isGeneratingImage => _isGeneratingImage;
  String? get currentUserId => _currentUserId;
  BotPersona get currentPersona => _currentPersona;
  String? get documentContext => _documentContext;
  File? get attachedDocument => _attachedDocument;
  ChatLockService get chatLockService => _chatLockService;

  // Method to update bot name in Groq service
  Future<void> updateBotName(String newName) async {
    try {
      // Update bot config service
      await _botConfigService.updateBotName(newName);
      
      // Update Groq service with new name (it will handle fallback automatically)
      _groqService = GroqService(
        apiKey: AppConfig.groqApiKey, // Main key, service will fallback if needed
        botName: newName,
        userNickname: _userProfileService.currentUserNickname,
      );
      
      debugPrint(' Bot name updated in Groq service to: $newName');
      notifyListeners(); // Notify UI of the change
    } catch (e) {
      debugPrint(' Error updating bot name: $e');
    }
  }

  // Method to get current bot name
  String getCurrentBotName() {
    return _botConfigService.botName;
  }

  void stopLoading() {
    debugPrint('🛑 Manually stopping all loading states...');
    _isLoading = false;
    _isTyping = false;
    _isGeneratingImage = false;
    notifyListeners();
  }

  ChatProvider() {
    // Don't load chats here - wait for user ID to be set
  }

  Future<void> _initializeServices() async {
    try {
      // Initialize bot config
      await _botConfigService.loadBotConfig();
      
      // Initialize user profile
      await _userProfileService.initializeCurrentUser();
      
      // Initialize Groq service with API key and user info
      _groqService = GroqService(
        apiKey: AppConfig.groqApiKey,
        botName: _botConfigService.botName,
        userNickname: _userProfileService.currentUserNickname,
      );
      
      debugPrint(' Groq service initialized with bot: ${_botConfigService.botName}');
      debugPrint(' User nickname: ${_userProfileService.currentUserNickname}');
    } catch (e) {
      debugPrint(' Error initializing services: $e');
      // Fallback to basic Groq service
      _groqService = GroqService(
        apiKey: AppConfig.groqApiKey,
      );
    }
  }

  void setUserId(String userId) async {
    debugPrint('=== Setting ChatProvider User ID: $userId ===');
    debugPrint('Previous user ID was: $_currentUserId');
    _currentUserId = userId;
    _firebaseChatService = FirebaseChatService(userId);
    
    // Set user ID in ChatLockService for user-specific locks
    _chatLockService.setUserId(userId);
    
    // Initialize Groq and related services
    await _initializeServices();
    
    // Initialize security state
    await _chatLockService.initializeSecurityState();
    
    // Clear current state and reload from Firebase
    _chats = [];
    _currentChat = null;
    _messages = [];
    notifyListeners();
    
    // Load chats from Firebase
    _loadChats();
  }

  Future<void> _loadChats() async {
    if (_currentUserId == null) {
      debugPrint('❌ Cannot load chats - no user ID');
      debugPrint('Current user ID is null');
      return;
    }
    
    debugPrint('📁 Loading chats for user: $_currentUserId');
    debugPrint('Firebase service instance: $_firebaseChatService');
    try {
      _chats = await _firebaseChatService.getAllChats();
      debugPrint('✅ Loaded ${_chats.length} chats');
      for (var chat in _chats) {
        debugPrint('Chat: ${chat.id} - ${chat.title}');
      }
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading chats: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      _chats = [];
      notifyListeners();
    }
  }

  Future<void> createNewChat([String? title]) async {
    if (_currentUserId == null) return;
    
    // Don't create empty chats automatically - only when user explicitly clicks new chat
    if (title == null && _chats.isNotEmpty) {
      // Check if there's already an empty "New Chat" we can reuse
      final existingEmptyChat = _chats.firstWhere(
        (chat) => chat.title == 'New Chat' && _messages.isEmpty,
        orElse: () => ChatModel(id: '', title: '', createdAt: DateTime.now(), updatedAt: DateTime.now()),
      );
      
      if (existingEmptyChat.id.isNotEmpty) {
        // Reuse existing empty chat
        _currentChat = existingEmptyChat;
        _messages = [];
        notifyListeners();
        return;
      }
    }
    
    final chatId = const Uuid().v4();
    final chat = ChatModel(
      id: chatId,
      title: title ?? 'New Chat',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Only save to Firebase if it has a custom title (user-created) or will have content
    // This prevents saving empty "New Chat" entries
    if (title != null && title != 'New Chat') {
      await _firebaseChatService.createChat(chat);
      debugPrint(' Saved user-created chat to Firebase: ${chat.title}');
    } else {
      debugPrint(' Created local empty chat (not saved to Firebase yet): ${chat.title}');
    }
    
    _chats.insert(0, chat);
    _currentChat = chat;
    _messages = [];
    notifyListeners();
  }

  // Clean up empty chats from history
  Future<void> cleanupEmptyChats() async {
    if (_currentUserId == null) return;
    
    // Check each chat to see if it has messages
    final List<ChatModel> emptyChats = [];
    
    for (final chat in _chats) {
      if (chat.title == 'New Chat') {
        try {
          final messages = await _firebaseChatService.getMessages(chat.id);
          if (messages.isEmpty) {
            emptyChats.add(chat);
          }
        } catch (e) {
          debugPrint('Error checking messages for chat ${chat.id}: $e');
          // If we can't get messages, assume it's empty
          emptyChats.add(chat);
        }
      }
    }
    
    for (final emptyChat in emptyChats) {
      // Don't delete the current chat even if it's empty
      if (emptyChat.id != _currentChat?.id) {
        await _firebaseChatService.deleteChat(emptyChat.id);
        _chats.removeWhere((chat) => chat.id == emptyChat.id);
        debugPrint(' Deleted empty chat: ${emptyChat.id}');
      }
    }
    
    notifyListeners();
  }

  Future<void> selectChat(String chatId) async {
    if (_currentUserId == null) return;
    
    _currentChat = _chats.firstWhere((chat) => chat.id == chatId);
    _messages = await _firebaseChatService.getMessages(chatId);
    notifyListeners();
  }

  Future<void> deleteChat(String chatId) async {
    if (_currentUserId == null) return;
    
    await _firebaseChatService.deleteChat(chatId);
    _chats.removeWhere((chat) => chat.id == chatId);
    
    if (_currentChat?.id == chatId) {
      _currentChat = null;
      _messages = [];
    }
    
    notifyListeners();
  }

  Future<void> renameChat(String chatId, String newTitle) async {
    if (_currentUserId == null) return;
    
    final chat = _chats.firstWhere((c) => c.id == chatId);
    final updatedChat = chat.copyWith(
      title: newTitle,
      updatedAt: DateTime.now(),
    );
    
    await _firebaseChatService.updateChat(updatedChat);
    
    final index = _chats.indexWhere((c) => c.id == chatId);
    _chats[index] = updatedChat;
    
    if (_currentChat?.id == chatId) {
      _currentChat = updatedChat;
    }
    
    notifyListeners();
  }

  Future<void> sendMessage(String content, {File? image, File? document}) async {
    if (_currentChat == null || _currentUserId == null) {
      await createNewChat();
    }

    _isTyping = true;
    notifyListeners();

    String? imageUrl;
    String? documentUrl;
    
    if (image != null) {
      try {
        imageUrl = await _firebaseChatService.uploadImage(image, _currentChat!.id);
      } catch (e) {
        debugPrint(' Image upload error: $e');
        imageUrl = null; // Don't use image if upload fails
      }
    }
    
    if (document != null) {
      try {
        documentUrl = await _firebaseChatService.uploadDocument(document, _currentChat!.id);
      } catch (e) {
        debugPrint(' Document upload error: $e');
        documentUrl = null; // Don't use document if upload fails
      }
    }

    // Ensure chat exists in Firebase before adding messages
    if (!_chats.any((chat) => chat.id == _currentChat!.id)) {
      // Add chat to local list first
      _chats.insert(0, _currentChat!);
      notifyListeners();
      
      // Then save to Firebase regardless of title
      try {
        await _firebaseChatService.createChat(_currentChat!);
        debugPrint(' Created chat in Firebase: ${_currentChat!.id} (${_currentChat!.title})');
      } catch (e) {
        debugPrint(' Error creating chat in Firebase: $e');
        // Continue anyway since chat is already in local list
      }
    } else if (_currentChat!.title == 'New Chat') {
      // If chat exists but is still "New Chat", ensure it's saved to Firebase
      try {
        await _firebaseChatService.createChat(_currentChat!);
        debugPrint(' Saved "New Chat" to Firebase: ${_currentChat!.id}');
      } catch (e) {
        debugPrint(' Error saving "New Chat" to Firebase: $e');
      }
    }

    // Create user message
    final userMessage = MessageModel(
      id: const Uuid().v4(),
      chatId: _currentChat!.id,
      content: content,
      isUser: true,
      timestamp: DateTime.now(),
      imagePath: imageUrl,
      documentPath: documentUrl,
    );

    try {
      await _firebaseChatService.sendMessage(userMessage);
      _messages.add(userMessage);
      notifyListeners();
    } catch (e) {
      debugPrint(' Error sending user message: $e');
      // Still add message locally even if Firebase fails
      _messages.add(userMessage);
      notifyListeners();
      return; // Don't proceed to AI response if user message fails
    }

    // Get AI response or process command
    try {
      String response = '';
      CommandResult? commandResult;
      
      // First, check if this is a command
      try {
        commandResult = await _commandProcessor.process(content);
        
        // If it's a command intent, execute it and use the command response
        switch (commandResult.intent) {
          case nlp.Intent.openWebsite:
          case nlp.Intent.searchGoogle:
          case nlp.Intent.searchYouTube:
          case nlp.Intent.playMusic:
          case nlp.Intent.openSpotify:
          case nlp.Intent.searchSpotify:
          case nlp.Intent.getNews:
            // This is a command - use the command result as response
            response = commandResult.message;
            break;
          case nlp.Intent.generateImage:
            // Handle image generation
            final prompt = commandResult.entities['prompt'] ?? 'beautiful landscape';
            await generateImage(prompt);
            return; // Don't send a text response, image will be sent
          case nlp.Intent.changeVoice:
            // Handle voice change commands
            if (commandResult.entities['gender'] == 'male') {
              await setVoiceGender(VoiceGender.male);
              response = 'Voice changed to male.';
            } else if (commandResult.entities['gender'] == 'female') {
              await setVoiceGender(VoiceGender.female);
              response = 'Voice changed to female.';
            } else {
              response = commandResult.message;
            }
            break;
          case nlp.Intent.changeName:
            // Handle name change commands
            final newName = commandResult.entities['name'];
            if (newName != null && newName.isNotEmpty) {
              try {
                await updateBotName(newName);
                response = commandResult.message;
              } catch (e) {
                debugPrint(' Error updating bot name: $e');
                response = 'Sorry, I had trouble changing my name. Please try again.';
              }
            } else {
              response = commandResult.message;
            }
            break;
          case nlp.Intent.exitChat:
            // Handle exit command
            response = commandResult.message;
            break;
          default:
            // Not a recognized command, get AI response with Groq (real-time search)
            final systemPrompt = PersonaService.getSystemPrompt(_currentPersona, documentContext: _documentContext);
            try {
              if (_useGroqService) {
                debugPrint(' Using Groq service with real-time search...');
                response = await _groqService.getChatResponse(
                  content,
                  conversationHistory: _messages,
                  imagePath: imageUrl,
                  systemPrompt: systemPrompt,
                );
              } else {
                debugPrint(' Using legacy AI service...');
                response = await _aiService.getChatResponse(
                  content,
                  conversationHistory: _messages,
                  imagePath: imageUrl,
                  systemPrompt: systemPrompt,
                );
              }
            } catch (e) {
              debugPrint(' AI Service Error: $e');
              response = 'Sorry, I encountered an error while processing your request. Please try again.';
            }
            break;
        }
      } catch (e) {
        debugPrint('Command processing error: $e');
        // For any command processing error, don't fall back to AI - just show error
        response = 'Sorry, I had trouble processing that command. Please try again.';
      }

      // Only send response if it's not empty (not for image generation)
      if (response.isNotEmpty) {
        final botMessage = MessageModel(
          id: const Uuid().v4(),
          chatId: _currentChat!.id,
          content: response,
          isUser: false,
          timestamp: DateTime.now(),
        );

        try {
          await _firebaseChatService.sendMessage(botMessage);
          _messages.add(botMessage);
          notifyListeners();
        } catch (e) {
          debugPrint(' Error sending bot message: $e');
          // Still add message locally even if Firebase fails
          _messages.add(botMessage);
          notifyListeners();
        }

        // Save to chat history (local JSON storage)
        try {
          await _chatHistoryService.addToHistory(content, response);
        } catch (e) {
          debugPrint(' Error saving to chat history: $e');
        }

        // Update chat timestamp only if chat exists and message was sent successfully
        try {
          final updatedChat = _currentChat!.copyWith(
            updatedAt: DateTime.now(),
          );
          await _firebaseChatService.updateChat(updatedChat);
        } catch (e) {
          debugPrint(' Error updating chat timestamp: $e');
          // Don't fail the whole operation if timestamp update fails
        }

        // Auto-generate chat title if first message or if still "New Chat"
        if (_messages.length >= 2 && _currentChat!.title == 'New Chat') {
          try {
            final title = await _generateChatTitle(content);
            await renameChat(_currentChat!.id, title);
          } catch (e) {
            debugPrint(' Error generating chat title: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Send message error: $e');
    } finally {
      _isTyping = false;
      notifyListeners();
    }
  }

  Future<String> _generateChatTitle(String firstMessage) async {
    try {
      String title;
      if (_useGroqService) {
        title = await _groqService.generateTitle(firstMessage);
      } else {
        title = await _aiService.generateTitle(firstMessage);
      }
      return title.length > 50 ? '${title.substring(0, 47)}...' : title;
    } catch (e) {
      return firstMessage.length > 30
          ? '${firstMessage.substring(0, 27)}...'
          : firstMessage;
    }
  }

  Future<void> clearCurrentChat() async {
    if (_currentChat == null || _currentUserId == null) return;
    
    await _firebaseChatService.clearChatMessages(_currentChat!.id);
    _messages = [];
    notifyListeners();
  }

  // Chat Lock Methods
  Future<void> lockChat(String chatId) async {
    await _chatLockService.lockChat(chatId);
    notifyListeners();
  }

  Future<void> unlockChat() async {
    await _chatLockService.removeChatLock();
    notifyListeners();
  }

  Future<bool> isChatLocked(String chatId) async {
    return await _chatLockService.isChatLocked(chatId);
  }

  Future<bool> unlockChatWithPin(String pin) async {
    bool success = await _chatLockService.unlockChatWithPin(pin);
    if (success) {
      await unlockChat();
    }
    return success;
  }

  Future<bool> unlockChatWithBiometrics() async {
    bool success = await _chatLockService.unlockChatWithBiometrics();
    if (success) {
      await unlockChat();
    }
    return success;
  }

  Future<String?> getLockedChat() async {
    return await _chatLockService.getLockedChat();
  }

  // Chatbot Mode Methods
  Future<void> setChatbotMode(ChatbotMode mode) async {
    await _chatbotModeService.saveChatbotMode(mode);
    notifyListeners();
  }

  Future<ChatbotMode> getCurrentChatbotMode() async {
    return await _chatbotModeService.getCurrentMode();
  }

  List<ChatbotMode> getAllChatbotModes() {
    return _chatbotModeService.getAllModes();
  }

  bool _isVoiceChatMode = false; // Separate voice chat mode

  // Voice Methods
  Future<bool> initializeSpeech() async {
    return await _voiceService.initializeSpeech();
  }

  bool get isVoiceListening => _voiceService.isListening;
  bool get isVoiceSpeaking => _voiceService.isSpeaking;
  bool get isVoiceChatMode => _isVoiceChatMode;
  VoiceGender get voiceGender => _voiceService.currentGender;

  Future<void> startVoiceListening() async {
    if (_voiceService.isListening) return;

    if (_isVoiceChatMode) {
      // Use new continuous mode for voice chat
      await _voiceService.startContinuousListening(
        onResult: (command) async {
          debugPrint('🎤 Voice command received: $command');
          // Add user message to chat first
          await _addUserMessage(command);
          // Then process the command
          await _processVoiceCommandOnly(command);
        },
        onListeningStop: () {
          debugPrint('🎤 Listening stopped (continuous mode)');
          notifyListeners();
        },
      );
    } else {
      // Use legacy method for single commands
      await _voiceService.startListening(
        onResult: (command) async {
          debugPrint('🎤 Voice command received: $command');
          await _processVoiceCommand(command);
        },
        onListeningStop: () {
          debugPrint('🎤 Listening stopped (single command)');
          notifyListeners();
        },
        continuousMode: false,
      );
    }
    notifyListeners();
  }

  Future<void> stopVoiceListening() async {
    await _voiceService.stopListening();
    notifyListeners();
  }

  Future<void> toggleVoiceChatMode() async {
    _isVoiceChatMode = !_isVoiceChatMode;
    
    if (_isVoiceChatMode) {
      // Start continuous listening immediately without TTS
      debugPrint('🎤 Starting voice chat mode (continuous)');
      await startVoiceListening();
    } else {
      // Stop continuous listening when exiting voice chat mode
      debugPrint('🛑 Stopping voice chat mode');
      await _voiceService.stopContinuousListening();
      await speakText('Voice chat mode deactivated.');
    }
    
    notifyListeners();
  }

  Future<void> setVoiceChatMode(bool enabled) async {
    _isVoiceChatMode = enabled;
    
    if (enabled) {
      debugPrint('🎤 Enabling voice chat mode (continuous)');
      await startVoiceListening();
    } else {
      debugPrint('🛑 Disabling voice chat mode');
      await _voiceService.stopContinuousListening();
      await speakText('Voice chat mode deactivated.');
    }
    
    notifyListeners();
  }

  Future<void> toggleVoiceGender() async {
    // Toggle between male and female
    final newGender = voiceGender == VoiceGender.male ? VoiceGender.female : VoiceGender.male;
    await setVoiceGender(newGender);
    notifyListeners();
  }

  Future<void> setVoiceGender(VoiceGender gender) async {
    await _voiceService.setVoiceGender(gender);
    notifyListeners();
  }

  Future<void> speakText(String text) async {
    if (_isVoiceChatMode) {
      // In voice chat mode, restart listening after TTS completes
      await _voiceService.speak(text, onComplete: () {
        if (_isVoiceChatMode && !_voiceService.isListening) {
          debugPrint('🔄 Restarting listening after TTS completion');
          Future.delayed(const Duration(milliseconds: 50), () {
            if (_isVoiceChatMode && !_voiceService.isListening) {
              startVoiceListening();
            }
          });
        }
      });
    } else {
      // Normal mode - just speak
      await _voiceService.speak(text);
    }
  }

  Future<void> _processVoiceCommand(String command) async {
    if (command.trim().isEmpty) return;

    // Add user message
    await sendMessage(command);

    // Process command with NLP
    try {
      final result = await _commandProcessor.process(command);
      
      // Handle special intents
      switch (result.intent) {
        case nlp.Intent.changeVoice:
          if (result.entities['gender'] == 'male') {
            await setVoiceGender(VoiceGender.male);
          } else if (result.entities['gender'] == 'female') {
            await setVoiceGender(VoiceGender.female);
          }
          break;
        case nlp.Intent.exitChat:
          await stopVoiceListening();
          break;
        default:
          // For other intents, just let the normal chat flow handle it
          break;
      }

      // Speak the response
      await speakText(result.message);
    } catch (e) {
      debugPrint('Voice command processing error: $e');
      await speakText('Sorry, I had trouble processing that command.');
    }
  }

  Future<void> _processVoiceCommandOnly(String command) async {
    if (command.trim().isEmpty) return;

    // Don't add user message here - it's handled in the voice service callback
    // The user message is already added by the calling method

    // Process command with NLP
    try {
      final result = await _commandProcessor.process(command);
      
      // Handle special intents
      switch (result.intent) {
        case nlp.Intent.changeVoice:
          if (result.entities['gender'] == 'male') {
            await setVoiceGender(VoiceGender.male);
            await speakText('Voice changed to male.');
            // Add bot response to chat
            await _addBotMessage('Voice changed to male.');
          } else if (result.entities['gender'] == 'female') {
            await setVoiceGender(VoiceGender.female);
            await speakText('Voice changed to female.');
            // Add bot response to chat
            await _addBotMessage('Voice changed to female.');
          }
          break;
        case nlp.Intent.exitChat:
          await toggleVoiceChatMode(); // Exit voice chat mode
          break;
        case nlp.Intent.openWebsite:
        case nlp.Intent.searchGoogle:
        case nlp.Intent.searchYouTube:
        case nlp.Intent.playMusic:
        case nlp.Intent.openSpotify:
        case nlp.Intent.searchSpotify:
        case nlp.Intent.getNews:
          // For command intents, speak the result message and add to chat
          await speakText(result.message);
          await _addBotMessage(result.message);
          break;
        case nlp.Intent.generateImage:
          // Handle image generation
          final prompt = result.entities['prompt'] ?? 'beautiful landscape';
          await generateImage(prompt);
          break;
        default:
          // For general chat, get AI response, speak it, and add to chat
          try {
            final response = await _aiService.getChatResponse(
              command,
              conversationHistory: _messages,
              systemPrompt: PersonaService.getSystemPrompt(_currentPersona, documentContext: _documentContext),
            );
            await speakText(response);
            await _addBotMessage(response);
          } catch (e) {
            debugPrint('AI Service Error in voice mode: $e');
            await speakText('Sorry, I had trouble processing that request.');
            await _addBotMessage('Sorry, I had trouble processing that request.');
          }
          break;
      }
    } catch (e) {
      debugPrint('Voice command processing error: $e');
      await speakText('Sorry, I had trouble processing that command.');
      await _addBotMessage('Sorry, I had trouble processing that command.');
    }
  }

  // Helper method to add bot messages to chat
  Future<void> _addBotMessage(String message) async {
    if (_currentChat == null || _currentUserId == null) return;

    try {
      // Ensure chat exists in Firebase before adding messages
      if (!_chats.any((chat) => chat.id == _currentChat!.id)) {
        await _firebaseChatService.createChat(_currentChat!);
        debugPrint(' Created missing chat in Firebase: ${_currentChat!.id}');
        // Add to local chats list
        _chats.add(_currentChat!);
        notifyListeners();
      }

      final botMessage = MessageModel(
        id: const Uuid().v4(),
        chatId: _currentChat!.id,
        content: message,
        isUser: false,
        timestamp: DateTime.now(),
      );

      await _firebaseChatService.sendMessage(botMessage);
      _messages.add(botMessage);
      notifyListeners();

      // Update chat timestamp only if chat exists
      try {
        final updatedChat = _currentChat!.copyWith(
          updatedAt: DateTime.now(),
        );
        await _firebaseChatService.updateChat(updatedChat);
      } catch (e) {
        debugPrint(' Error updating chat timestamp: $e');
        // Don't fail the whole operation if timestamp update fails
      }
    } catch (e) {
      debugPrint('Error adding bot message: $e');
    }
  }

  // Helper method to add user messages to chat
  Future<void> _addUserMessage(String message) async {
    if (_currentChat == null || _currentUserId == null) {
      await createNewChat();
    }

    try {
      final userMessage = MessageModel(
        id: const Uuid().v4(),
        chatId: _currentChat!.id,
        content: message,
        isUser: true,
        timestamp: DateTime.now(),
      );

      await _firebaseChatService.sendMessage(userMessage);
      _messages.add(userMessage);
      notifyListeners();

      // Auto-generate chat title if first message
      if (_messages.length == 1 && _currentChat!.title == 'New Chat') {
        final title = await _generateChatTitle(message);
        await renameChat(_currentChat!.id, title);
      }

      // Update chat timestamp
      final updatedChat = _currentChat!.copyWith(
        updatedAt: DateTime.now(),
      );
      await _firebaseChatService.updateChat(updatedChat);
    } catch (e) {
      debugPrint('Error adding user message: $e');
    }
  }

  void clearMessages() {
    debugPrint('🧹 Clearing chat messages and current state');
    _messages = [];
    _currentChat = null;
    _chats = [];
    // Clear user ID from ChatLockService when logging out
    _chatLockService.setUserId('');
    // Don't clear _currentUserId so we can reload data when user logs back in
    notifyListeners();
  }
  // =============================
  // Image Generation Methods
  // =============================
  
  Future<File?> generateImage(String prompt) async {
    try {
      debugPrint(' Generating image: $prompt');
      
      // Set loading state
      _isLoading = true;
      notifyListeners();
      
      // Use the new clean method that returns bytes directly
      final imageBytes = await _imageService.generateImageBytes(prompt);
      
      if (imageBytes != null) {
        debugPrint(' Image generated successfully: ${imageBytes.length} bytes');
        
        // Create file from bytes in app's permanent directory
        final appDir = await getApplicationDocumentsDirectory();
        final imagesDir = Directory('${appDir.path}/generated_images');
        
        // Create the images directory if it doesn't exist
        if (!await imagesDir.exists()) {
          await imagesDir.create(recursive: true);
        }
        
        final fileName = 'generated_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final imageFile = File('${imagesDir.path}/$fileName');
        await imageFile.writeAsBytes(imageBytes);
        
        debugPrint(' Image saved to: ${imageFile.path}');
        
        // Ensure we have a chat and save it to Firebase if this is the first message
        if (_currentChat == null || _currentUserId == null) {
          await createNewChat();
          // Wait a moment to ensure chat is saved to Firebase
          await Future.delayed(Duration(milliseconds: 500));
        }
        
        // Save chat to Firebase if it hasn't been saved yet (for image generation)
        if (_currentChat != null && !_chats.any((chat) => chat.id == _currentChat!.id)) {
          await _firebaseChatService.createChat(_currentChat!);
          debugPrint(' Saved image generation chat to Firebase: ${_currentChat!.title}');
          // Wait a moment to ensure chat is saved
          await Future.delayed(Duration(milliseconds: 500));
        }
        
        // Send the generated image as a message
        await _sendImageMessage('Generated image: $prompt', imageFile);
        
        // Auto-generate chat title for image generation if it's the first message
        if (_messages.length == 1 && _currentChat!.title == 'New Chat') {
          final title = await _generateChatTitle('Image: $prompt');
          await renameChat(_currentChat!.id, title);
        }
        
        // Clear loading state
        _isLoading = false;
        notifyListeners();
        
        return imageFile;
      } else {
        debugPrint(' Failed to generate image');
        await _sendTextMessage('Sorry, I failed to generate the image. Please try again.');
        
        // Clear loading state on failure
        _isLoading = false;
        notifyListeners();
        
        return null;
      }
    } catch (e) {
      debugPrint(' Error generating image: $e');
      await _sendTextMessage('Sorry, I encountered an error while generating the image.');
      
      // Clear loading state on error
      _isLoading = false;
      notifyListeners();
      
      return null;
    }
  }

  Future<void> _sendImageMessage(String content, File image) async {
    if (_currentChat == null || _currentUserId == null) {
      await createNewChat();
    }

    String? imageUrl;
    
    try {
      debugPrint(' Uploading image to Firebase...');
      
      // Try Firebase upload first with proper metadata
      imageUrl = await _firebaseChatService.uploadImage(image, _currentChat!.id)
          .timeout(const Duration(seconds: 15), onTimeout: () {
        throw TimeoutException('Firebase upload timed out after 15 seconds');
      });
      
      debugPrint(' Image uploaded to Firebase: $imageUrl');
    } catch (e) {
      debugPrint(' Firebase upload failed: $e');
      debugPrint(' Using local file path as fallback...');
      // Fallback: use local file path if Firebase upload fails
      imageUrl = image.path;
    }

    // Create bot message with image
    final botMessage = MessageModel(
      id: const Uuid().v4(),
      chatId: _currentChat!.id,
      content: content,
      isUser: false,
      timestamp: DateTime.now(),
      imagePath: imageUrl,
    );

    try {
      await _firebaseChatService.sendMessage(botMessage);
      _messages.add(botMessage);
      notifyListeners();

      // Update chat timestamp
      final updatedChat = _currentChat!.copyWith(
        updatedAt: DateTime.now(),
      );
      await _firebaseChatService.updateChat(updatedChat);
    } catch (e) {
      debugPrint(' Error sending image message: $e');
      // Still add the message locally even if Firebase fails
      _messages.add(botMessage);
      notifyListeners();
    }
    
    // CRITICAL: Always clear loading state at the end
    if (_isLoading) {
      debugPrint(' Clearing loading state after image message sent...');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _sendTextMessage(String content) async {
    if (_currentChat == null || _currentUserId == null) {
      await createNewChat();
    }

    // Ensure chat exists in Firebase before sending message
    if (!_chats.any((chat) => chat.id == _currentChat!.id)) {
      await _firebaseChatService.createChat(_currentChat!);
      debugPrint(' Created missing chat in Firebase: ${_currentChat!.id}');
      // Add to local chats list
      _chats.add(_currentChat!);
      notifyListeners();
    }

    // Create bot message
    final botMessage = MessageModel(
      id: const Uuid().v4(),
      chatId: _currentChat!.id,
      content: content,
      isUser: false,
      timestamp: DateTime.now(),
    );

    try {
      await _firebaseChatService.sendMessage(botMessage);
      _messages.add(botMessage);
      notifyListeners();

      // Update chat timestamp only if chat exists
      try {
        final updatedChat = _currentChat!.copyWith(
          updatedAt: DateTime.now(),
        );
        await _firebaseChatService.updateChat(updatedChat);
      } catch (e) {
        debugPrint(' Error updating chat timestamp: $e');
        // Don't fail the whole operation if timestamp update fails
      }
    } catch (e) {
      debugPrint(' Error sending text message: $e');
      // Still add message locally even if Firebase fails
      _messages.add(botMessage);
      notifyListeners();
    }
  }

  Future<void> testImageGeneration() async {
    debugPrint(' Testing image generation from ChatProvider...');
    await _imageService.testDirectCall();
  }

  // =============================
  // Persona Management Methods
  // =============================
  
  Future<void> setPersona(BotPersona persona) async {
    _currentPersona = persona;
    notifyListeners();
    debugPrint('🤖 AI Persona changed to: ${persona.name}');
  }

  // =============================
  // Document Management Methods
  // =============================
  
  Future<bool> attachDocument(File document) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      // Read document content
      final content = await DocumentService.readDocument(document);
      if (content != null) {
        _attachedDocument = document;
        _documentContext = await DocumentService.summarizeDocumentContent(content);
        notifyListeners();
        debugPrint('📄 Document attached: ${document.path}');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error attaching document: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> detachDocument() async {
    _attachedDocument = null;
    _documentContext = null;
    notifyListeners();
    debugPrint('📄 Document detached');
  }
  
  Future<void> pickAndAttachDocument() async {
    try {
      // This would use file_picker package
      // For now, this is a placeholder
      debugPrint('📄 Document picking not yet implemented');
    } catch (e) {
      debugPrint('❌ Error picking document: $e');
    }
  }
}