import 'package:url_launcher/url_launcher.dart';
import 'nlp_classifier.dart';
import 'ai_services.dart';
import 'bot_config_service.dart';
import 'package:flutter/foundation.dart';

class CommandResult {
  final String message;
  final bool success;
  final Intent intent;
  final Map<String, String> entities;

  CommandResult({
    required this.message,
    required this.intent,
    this.success = true,
    this.entities = const {},
  });
}

class CommandProcessor {
  final AIService _aiService = AIService();
  final BotConfigService _botConfigService = BotConfigService.instance;

  // Music library — extend as needed
  static const Map<String, String> musicLibrary = {
    'nadan parinde': 'https://www.youtube.com/results?search_query=nadan+parinde',
    'tum hi ho': 'https://www.youtube.com/results?search_query=tum+hi+ho+aashiqui+2',
    'shape of you': 'https://www.youtube.com/results?search_query=ed+sheeran+shape+of+you',
    'blinding lights': 'https://www.youtube.com/results?search_query=the+weeknd+blinding+lights',
    'levitating': 'https://www.youtube.com/results?search_query=dua+lipa+levitating',
    'jai ho': 'https://www.youtube.com/results?search_query=jai+ho+ar+rahman',
    'kesariya': 'https://www.youtube.com/results?search_query=kesariya+brahmastra',
  };

  Future<CommandResult> process(String command) async {
    final result = NLPClassifier.classify(command);

    switch (result.intent) {
      case Intent.openWebsite:
        return _handleOpenWebsite(result.entities);

      case Intent.searchGoogle:
        return _handleGoogleSearch(result.entities);

      case Intent.searchYouTube:
        return _handleYouTubeSearch(result.entities);

      case Intent.playMusic:
        return _handlePlayMusic(result.entities);

      case Intent.openSpotify:
        return _handleOpenSpotify();

      case Intent.searchSpotify:
        return _handleSpotifySearch(result.entities);

      case Intent.getNews:
        return _handleNews();

      case Intent.changeName:
        return await _handleNameChange(result.entities);

      case Intent.changeVoice:
        return CommandResult(
          message: 'Voice changed to ${result.entities['gender']}.',
          intent: Intent.changeVoice,
          success: true,
          entities: result.entities,
        );

      case Intent.generateImage:
        return CommandResult(
          message: 'Generating image: ${result.entities['prompt']}',
          intent: Intent.generateImage,
          success: true,
          entities: result.entities,
        );

      case Intent.exitChat:
        return CommandResult(
          message: 'Goodbye! Just say my name whenever you need me.',
          intent: Intent.exitChat,
          entities: result.entities,
        );

      case Intent.generalQuestion:
      case Intent.unknown:
      default:
        final query = result.entities['query'] ?? command;
        final aiReply = await _aiService.getChatResponse(
          query,
          conversationHistory: [], // Could be enhanced with context
        );
        return CommandResult(
          message: aiReply,
          intent: Intent.generalQuestion,
          entities: result.entities,
        );
    }
  }

  // ─── Intent Handlers ──────────────────────────────────────────────────────

  Future<CommandResult> _handleOpenWebsite(Map<String, String> entities) async {
    final site = entities['site'] ?? '';
    final url = entities['url'] ?? 'https://google.com';
    await _launchUrl(url);
    return CommandResult(
      message: 'Opening $site...',
      intent: Intent.openWebsite,
      entities: entities,
    );
  }

  Future<CommandResult> _handleGoogleSearch(
      Map<String, String> entities) async {
    final query = entities['query'] ?? '';
    final encoded = Uri.encodeComponent(query);
    await _launchUrl('https://www.google.com/search?q=$encoded');
    return CommandResult(
      message: 'Searching for "$query" on Google...',
      intent: Intent.searchGoogle,
      entities: entities,
    );
  }

  Future<CommandResult> _handleYouTubeSearch(
      Map<String, String> entities) async {
    final query = entities['query'] ?? '';
    final encoded = query.replaceAll(' ', '+');
    await _launchUrl(
        'https://www.youtube.com/results?search_query=$encoded');
    return CommandResult(
      message: 'Searching YouTube for "$query"...',
      intent: Intent.searchYouTube,
      entities: entities,
    );
  }

  Future<CommandResult> _handlePlayMusic(Map<String, String> entities) async {
    final query = entities['query'] ?? '';
    final queryLower = query.toLowerCase();

    // Check local music library first
    for (final key in musicLibrary.keys) {
      if (queryLower.contains(key)) {
        await _launchUrl(musicLibrary[key]!);
        return CommandResult(
          message: 'Playing "$key"...',
          intent: Intent.playMusic,
          entities: entities,
        );
      }
    }

    // Fallback to YouTube search
    final encoded = queryLower.replaceAll(' ', '+');
    await _launchUrl(
        'https://www.youtube.com/results?search_query=$encoded');
    return CommandResult(
      message: '"$query" not found in library. Searching YouTube...',
      intent: Intent.playMusic,
      entities: entities,
    );
  }

  Future<CommandResult> _handleOpenSpotify() async {
    // Try Spotify app first via deep link, fallback to web
    final appUri = Uri.parse('spotify:');
    final webUri = Uri.parse('https://open.spotify.com');
    try {
      if (await canLaunchUrl(appUri)) {
        await launchUrl(appUri);
      } else {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
    return CommandResult(
      message: 'Opening Spotify...',
      intent: Intent.openSpotify,
      entities: {},
    );
  }

  Future<CommandResult> _handleSpotifySearch(
      Map<String, String> entities) async {
    final query = entities['query'] ?? '';
    final encoded = Uri.encodeComponent(query);
    // Deep link to Spotify search
    final spotifyDeepLink =
        Uri.parse('spotify:search:$query');
    final webFallback = Uri.parse(
        'https://open.spotify.com/search/$encoded');
    try {
      if (await canLaunchUrl(spotifyDeepLink)) {
        await launchUrl(spotifyDeepLink);
      } else {
        await launchUrl(webFallback, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      await launchUrl(webFallback, mode: LaunchMode.externalApplication);
    }
    return CommandResult(
      message: 'Searching Spotify for "$query"...',
      intent: Intent.searchSpotify,
      entities: entities,
    );
  }

  Future<CommandResult> _handleNews() async {
    // Open Google News
    await _launchUrl('https://news.google.com');
    return CommandResult(
      message: 'Opening latest news for you...',
      intent: Intent.getNews,
      entities: {},
    );
  }

  Future<CommandResult> _handleNameChange(Map<String, String> entities) async {
    final newName = entities['name']?.trim();
    
    if (newName == null || newName.isEmpty) {
      return CommandResult(
        message: 'I didn\'t catch the new name. Please try again with "call you [name]" or "your name is [name]".',
        intent: Intent.changeName,
        success: false,
        entities: entities,
      );
    }

    // Validate name
    if (newName.length < 2 || newName.length > 20) {
      return CommandResult(
        message: 'Name should be between 2 and 20 characters.',
        intent: Intent.changeName,
        success: false,
        entities: entities,
      );
    }

    try {
      // Load current config
      await _botConfigService.loadBotConfig();
      
      // Update bot name
      await _botConfigService.updateBotName(newName);
      
      debugPrint(' Bot name changed to: $newName');
      
      return CommandResult(
        message: 'Successfully changed my name to $newName! From now on, you can call me $newName.',
        intent: Intent.changeName,
        success: true,
        entities: entities,
      );
    } catch (e) {
      debugPrint(' Error changing bot name: $e');
      return CommandResult(
        message: 'Sorry, I had trouble changing my name. Please try again.',
        intent: Intent.changeName,
        success: false,
        entities: entities,
      );
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
