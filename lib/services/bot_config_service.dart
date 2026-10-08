import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class BotConfigService {
  static BotConfigService? _instance;
  static BotConfigService get instance => _instance ??= BotConfigService._();
  
  BotConfigService._();

  String _botName = 'Celestera';
  String get botName => _botName;

  Future<File> _getBotConfigFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/bot_config.json');
  }

  Future<void> loadBotConfig() async {
    try {
      final file = await _getBotConfigFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content);
        _botName = data['name'] ?? 'Celestera';
        debugPrint(' Bot config loaded: $_botName');
      } else {
        // Create default config
        await saveBotConfig('Celestera');
        debugPrint(' Default bot config created');
      }
    } catch (e) {
      debugPrint(' Error loading bot config: $e');
      _botName = 'Celestera';
    }
  }

  Future<void> saveBotConfig(String botName) async {
    try {
      final file = await _getBotConfigFile();
      await file.writeAsString(jsonEncode({'name': botName}));
      _botName = botName;
      debugPrint(' Bot config saved: $botName');
    } catch (e) {
      debugPrint(' Error saving bot config: $e');
    }
  }

  Future<void> updateBotName(String newName) async {
    try {
      _botName = newName;
      await saveBotConfig(newName);
      debugPrint(' Bot name updated to: $newName');
    } catch (e) {
      debugPrint(' Error updating bot name: $e');
    }
  }
}
