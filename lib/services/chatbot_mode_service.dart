import 'package:shared_preferences/shared_preferences.dart';

enum ChatbotMode {
  main('main', 'Main Chatbot', 'General purpose AI assistant'),
  healthcare('healthcare', 'Healthcare Assistant', 'Medical and health-related queries'),
  fitness('fitness', 'Fitness Coach', 'Exercise, nutrition, and wellness guidance'),
  study('study', 'Study Assistant', 'Learning and educational support');

  const ChatbotMode(this.id, this.name, this.description);
  final String id;
  final String name;
  final String description;
}

class ChatbotModeService {
  static final ChatbotModeService _instance = ChatbotModeService._internal();
  factory ChatbotModeService() => _instance;
  ChatbotModeService._internal();

  late Future<SharedPreferences> _preferences;

  // Initialize preferences
  Future<void> init() async {
    _preferences = SharedPreferences.getInstance();
  }

  // Save selected mode
  Future<void> saveChatbotMode(ChatbotMode mode) async {
    final prefs = await _preferences;
    await prefs.setString('chatbot_mode', mode.id);
  }

  // Get current mode
  Future<ChatbotMode> getCurrentMode() async {
    final prefs = await _preferences;
    final modeId = prefs.getString('chatbot_mode') ?? 'main';
    return ChatbotMode.values.firstWhere(
      (mode) => mode.id == modeId,
      orElse: () => ChatbotMode.main,
    );
  }

  // Get all available modes
  List<ChatbotMode> getAllModes() {
    return ChatbotMode.values;
  }

  // Get system prompt for mode
  String getSystemPrompt(ChatbotMode mode) {
    switch (mode) {
      case ChatbotMode.main:
        return '''You are a helpful AI assistant named Celestera. Be friendly, professional, and provide accurate information. 
        You can help with a wide range of topics and questions. Always be respectful and helpful.''';
      
      case ChatbotMode.healthcare:
        return '''You are a healthcare AI assistant named Celestera. Provide medical information and health guidance, but always 
        include a disclaimer that you're not a substitute for professional medical advice. 
        Focus on general health information, wellness tips, and when to seek medical attention.''';
      
      case ChatbotMode.fitness:
        return '''You are a fitness coach AI assistant named Celestera. Provide exercise guidance, nutrition tips, and 
        wellness advice. Encourage healthy habits and suggest appropriate workout routines. 
        Always consider safety and recommend consulting professionals for personalized plans.''';
      
      case ChatbotMode.study:
        return '''You are an educational AI assistant named Celestera. Help with learning, explain concepts clearly, 
        provide study tips, and assist with homework. Be patient, encouraging, and break down 
        complex topics into understandable parts. Promote effective learning strategies.''';
    }
  }
}
