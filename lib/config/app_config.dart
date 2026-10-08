class AppConfig {
  // API Keys (Configure via --dart-define or update locally)
  static const String groqApiKey = String.fromEnvironment('GROQ_API_KEY', defaultValue: 'YOUR_GROQ_API_KEY_HERE');
  static const String groqBackupApiKey = String.fromEnvironment('GROQ_BACKUP_API_KEY', defaultValue: 'YOUR_BACKUP_GROQ_API_KEY_HERE');
  
  // API Endpoints
  static const String groqBaseUrl = 'https://api.groq.com/openai/v1';
  static const String groqModel = 'llama-3.3-70b-versatile';
  
  // App Settings
  static const String defaultBotName = 'Celestera';
  static const String defaultUserNickname = 'User';
  static const String defaultHistoryName = 'default';
  
  // Search Settings
  static const int maxSearchResults = 5;
  static const String searchEngine = 'duckduckgo';
  
  // Chat Settings
  static const int maxConversationHistory = 10; // Last 10 messages for context
  static const int maxTitleLength = 50;
  static const int maxResponseTokens = 2048;
  static const double temperature = 0.7;
  static const double topP = 1.0;
  
  // File Paths
  static const String userProfileFile = 'user_profile.json';
  static const String botConfigFile = 'bot_config.json';
  static const String chatHistoryFile = 'chat_history.json';
  static const String historySelectionFile = 'history_selection.json';
  static const String historyFile = 'history.json';
  
  // Feature Flags
  static const bool useGroqService = true;
  static const bool enableRealTimeSearch = true;
  static const bool enableChatHistory = true;
  static const bool enableUserProfile = true;
}
