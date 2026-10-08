/// NLP Intent Classifier
/// Uses rule-based NLP with context awareness to classify user intent
/// Avoids false positives like "going to watch a play" being treated as "play music"

enum Intent {
  openWebsite,
  searchGoogle,
  searchYouTube,
  playMusic,
  openSpotify,
  searchSpotify,
  getNews,
  changeName,
  changeVoice,
  generateImage,
  generalQuestion,
  exitChat,
  unknown,
}

class IntentResult {
  final Intent intent;
  final Map<String, String> entities;
  final double confidence;

  IntentResult({
    required this.intent,
    required this.entities,
    required this.confidence,
  });

  @override
  String toString() =>
      'Intent: $intent | Entities: $entities | Confidence: $confidence';
}

class NLPClassifier {
  // ─── Context-aware keyword sets ──────────────────────────────────────────

  // Words that indicate "play" is used in NON-music context
  static const List<String> _nonMusicPlayContexts = [
    'in a play',
    'watching a play',
    'watch a play',
    'theatre play',
    'theater play',
    'stage play',
    'a play in',
    'play in london',
    'play in new york',
    'play at the',
    'broadway play',
    'going to a play',
    'tickets for a play',
    'playful',
    'playground',
    'gameplay',
    'word play',
    'wordplay',
    'role play',
    'roleplay',
    'fair play',
    'foul play',
  ];

  // Strong music-play indicators
  static const List<String> _musicPlayIndicators = [
    'play song',
    'play music',
    'play the song',
    'play me',
    'play some',
    'play album',
    'play playlist',
    'play artist',
    'play by',
    'play track',
  ];

  // Website mappings
  static const Map<String, String> _websiteMap = {
    'google': 'https://google.com',
    'youtube': 'https://youtube.com',
    'facebook': 'https://facebook.com',
    'instagram': 'https://instagram.com',
    'linkedin': 'https://linkedin.com',
    'spotify': 'https://spotify.com',
    'twitter': 'https://twitter.com',
    'reddit': 'https://reddit.com',
    'github': 'https://github.com',
    'netflix': 'https://netflix.com',
    'amazon': 'https://amazon.com',
    'whatsapp': 'https://web.whatsapp.com',
  };

  static const List<String> _exitPhrases = [
    'bye',
    'goodbye',
    'good bye',
    'exit chat',
    'end chat',
    'bye bye',
    'see you',
    'see ya',
    'quit',
    'stop listening',
  ];

  static const List<String> _changeVoicePhrases = [
    'change voice',
    'switch voice',
    'male voice',
    'female voice',
    'change to male',
    'change to female',
    'use male',
    'use female',
  ];

  static const List<String> _changeNamePhrases = [
    'change your name',
    'keep your name',
    'rename yourself',
    'your name is',
    'call you',
    'i will call you',
    'you are now',
    'your new name',
    'change name to',
    'rename to',
    'set your name',
    'your name should be',
    'i want to call you',
    'from now on call you',
    'henceforth call you',
  ];

  static const List<String> _newsKeywords = [
    'news',
    'headlines',
    'latest news',
    'top stories',
    'breaking news',
    'what\'s happening',
    'current events',
  ];

  static const List<String> _spotifyKeywords = [
    'on spotify',
    'spotify playlist',
    'open spotify',
    'play on spotify',
    'spotify song',
    'add to spotify',
    'spotify music',
  ];

  static const List<String> _imageGenerationKeywords = [
    'generate',
    'create',
    'make',
    'draw',
    'design',
    'image',
    'picture',
    'photo',
    'art',
    'illustration',
  ];

  static const List<String> _imageGenerationPhrases = [
    'generate image',
    'create image',
    'make image',
    'draw picture',
    'generate picture',
    'create picture',
    'make picture',
    'generate art',
    'create art',
    'make art',
    'generate photo',
    'create photo',
    'make photo',
    'generate illustration',
    'create illustration',
    'make illustration',
  ];

  // ─── Main classify method ─────────────────────────────────────────────────

  static IntentResult classify(String input) {
    final text = input.toLowerCase().trim();
    final words = text.split(RegExp(r'\s+'));

    // 1. Exit intent
    if (_exitPhrases.any((p) => text.contains(p))) {
      return IntentResult(
        intent: Intent.exitChat,
        entities: {},
        confidence: 0.95,
      );
    }

    // 2. Change voice intent
    if (_changeVoicePhrases.any((p) => text.contains(p))) {
      final gender = text.contains('male') && !text.contains('female')
          ? 'male'
          : text.contains('female')
              ? 'female'
              : 'toggle';
      return IntentResult(
        intent: Intent.changeVoice,
        entities: {'gender': gender},
        confidence: 0.92,
      );
    }

    // 3. Change bot name
    if ((text.contains('change your name') ||
        text.contains('keep your name') ||
        text.contains('rename yourself') ||
        text.contains('your name is') ||
        text.contains('call you'))) {
      final nameEntity = _extractNameChange(text, words);
      return IntentResult(
        intent: Intent.changeName,
        entities: {'name': nameEntity},
        confidence: 0.88,
      );
    }

    // 4. News intent
    if (_newsKeywords.any((k) => text.contains(k))) {
      return IntentResult(
        intent: Intent.getNews,
        entities: {},
        confidence: 0.90,
      );
    }

    // 5. Image generation intent
    if (_imageGenerationPhrases.any((p) => text.contains(p)) ||
        (_imageGenerationKeywords.any((k) => text.contains(k)) && 
         _imageGenerationKeywords.where((k) => text.contains(k)).length >= 2)) {
      final prompt = _extractImagePrompt(text);
      return IntentResult(
        intent: Intent.generateImage,
        entities: {'prompt': prompt},
        confidence: 0.92,
      );
    }

    // 6. Spotify-specific intents
    if (_spotifyKeywords.any((k) => text.contains(k))) {
      if (text.startsWith('open spotify') || text == 'spotify') {
        return IntentResult(
          intent: Intent.openSpotify,
          entities: {},
          confidence: 0.95,
        );
      }
      final query = _extractSpotifyQuery(text);
      return IntentResult(
        intent: Intent.searchSpotify,
        entities: {'query': query},
        confidence: 0.88,
      );
    }

    // 6. Open website intent
    if (text.startsWith('open ')) {
      final siteName = text.replaceFirst('open ', '').trim();
      final url = _websiteMap[siteName] ??
          'https://www.google.com/search?q=${siteName.replaceAll(' ', '+')}';
      return IntentResult(
        intent: Intent.openWebsite,
        entities: {'site': siteName, 'url': url},
        confidence: 0.90,
      );
    }

    // 7. YouTube search intent
    if (text.contains('search') && text.contains('youtube')) {
      final query = _extractYouTubeSearchQuery(text);
      return IntentResult(
        intent: Intent.searchYouTube,
        entities: {'query': query},
        confidence: 0.88,
      );
    }

    // 8. General search intent
    if (text.startsWith('search') || text.startsWith('search for')) {
      final query = _extractSearchQuery(text);
      return IntentResult(
        intent: Intent.searchGoogle,
        entities: {'query': query},
        confidence: 0.85,
      );
    }

    // 9. PLAY intent — with NLP disambiguation
    if (words.contains('play')) {
      return _classifyPlayIntent(text, words);
    }

    // 10. Fallback: general AI question
    return IntentResult(
      intent: Intent.generalQuestion,
      entities: {'query': input},
      confidence: 0.60,
    );
  }

  // ─── Play intent NLP disambiguation ──────────────────────────────────────

  static IntentResult _classifyPlayIntent(String text, List<String> words) {
    // Check for non-music play contexts first (higher priority)
    for (final context in _nonMusicPlayContexts) {
      if (text.contains(context)) {
        // "play" is used in a non-music sense → treat as general question
        return IntentResult(
          intent: Intent.generalQuestion,
          entities: {'query': text},
          confidence: 0.85,
        );
      }
    }

    // Check for strong music indicators
    final hasStrongMusicContext =
        _musicPlayIndicators.any((ind) => text.contains(ind));

    // Check structural patterns: "play [song/artist name]" at start
    final playIndex = words.indexOf('play');
    final isPlayAtStart = playIndex == 0;
    final hasWordsAfterPlay =
        playIndex != -1 && playIndex < words.length - 1;

    // Heuristic: if "play" is the first word and followed by nouns, likely music
    if (isPlayAtStart && hasWordsAfterPlay) {
      // Check if followed by prepositions suggesting non-music context
      final nextWord =
          playIndex + 1 < words.length ? words[playIndex + 1] : '';
      final nonMusicNextWords = [
        'the',
        'a',
        'an',
        'at',
        'in',
        'on',
        'by',
        'my',
        'our'
      ];

      if (hasStrongMusicContext ||
          !nonMusicNextWords.contains(nextWord) ||
          _isMusicQuery(text, words, playIndex)) {
        // Likely a music play intent
        final query = _extractMusicQuery(text, words, playIndex);

        // Check if YouTube is mentioned
        if (text.contains('youtube') || text.contains('on yt')) {
          return IntentResult(
            intent: Intent.searchYouTube,
            entities: {'query': query},
            confidence: 0.85,
          );
        }
        if (text.contains('spotify')) {
          return IntentResult(
            intent: Intent.searchSpotify,
            entities: {'query': query},
            confidence: 0.85,
          );
        }

        return IntentResult(
          intent: Intent.playMusic,
          entities: {'query': query},
          confidence: 0.82,
        );
      }
    }

    // Default: if unclear, treat as general question
    return IntentResult(
      intent: Intent.generalQuestion,
      entities: {'query': text},
      confidence: 0.65,
    );
  }

  // ─── Helper: Is this likely a music query? ────────────────────────────────

  static bool _isMusicQuery(
      String text, List<String> words, int playIndex) {
    // Music-related words near "play"
    const musicWords = [
      'song',
      'music',
      'track',
      'album',
      'playlist',
      'remix',
      'beat',
      'audio',
      'ft',
      'feat',
      'featuring',
    ];
    return musicWords.any((w) => words.contains(w));
  }

  // ─── Query extraction helpers ─────────────────────────────────────────────

  static String _extractMusicQuery(
      String text, List<String> words, int playIndex) {
    final afterPlay = words.sublist(playIndex + 1);

    // Remove trailing context words
    final stopWords = ['on', 'from', 'using', 'via', 'in', 'at'];
    var end = afterPlay.length;
    for (var i = afterPlay.length - 1; i >= 0; i--) {
      if (stopWords.contains(afterPlay[i]) &&
          ['youtube', 'spotify', 'music'].any((s) => text.contains(s))) {
        end = i;
        break;
      }
    }
    return afterPlay.sublist(0, end).join(' ').trim();
  }

  static String _extractYouTubeSearchQuery(String text) {
    var query = text
        .replaceAll('search on youtube', '')
        .replaceAll('search youtube for', '')
        .replaceAll('search youtube', '')
        .replaceAll('on youtube', '')
        .replaceAll('youtube', '')
        .replaceAll('search for', '')
        .replaceAll('search', '')
        .trim();
    return query;
  }

  static String _extractSearchQuery(String text) {
    return text
        .replaceFirst(RegExp(r'^search for\s+'), '')
        .replaceFirst(RegExp(r'^search\s+'), '')
        .trim();
  }

  static String _extractSpotifyQuery(String text) {
    return text
        .replaceAll('play on spotify', '')
        .replaceAll('search spotify for', '')
        .replaceAll('search on spotify', '')
        .replaceAll('play', '')
        .replaceAll('spotify', '')
        .replaceAll('on', '')
        .replaceAll('search for', '')
        .replaceAll('search', '')
        .trim();
  }

  static String _extractNameChange(String text, List<String> words) {
    final indicators = [
      'name is',
      'call you',
      'name to',
      'rename to',
      'your name',
      'you are now',
      'your new name',
      'set your name',
      'your name should be',
      'want to call you',
      'now call you',
      'henceforth call you',
    ];

    // Try each indicator pattern
    for (final ind in indicators) {
      if (text.contains(ind)) {
        final idx = text.indexOf(ind) + ind.length;
        var namePart = text.substring(idx).trim();
        
        // Extract first meaningful word or phrase
        namePart = namePart.split(' ').first;
        
        // Clean up the name (remove punctuation, quotes, etc.)
        namePart = namePart.replaceAll(RegExp(r'[^\w\s]'), '').trim();
        
        // Validate name (at least 2 characters, reasonable length)
        if (namePart.length >= 2 && namePart.length <= 20) {
          return namePart;
        }
      }
    }
    
    // Fallback: Look for patterns like "call you [name]"
    final callYouPattern = RegExp(r'call you\s+(\w+)', caseSensitive: false);
    final match = callYouPattern.firstMatch(text);
    if (match != null) {
      final name = match.group(1);
      if (name != null && name.length >= 2 && name.length <= 20) {
        return name;
      }
    }
    
    return '';
  }

  static String _extractImagePrompt(String text) {
    // Remove image generation keywords to get actual prompt
    final keywordsToRemove = [
      'generate image',
      'create image',
      'make image',
      'draw picture',
      'generate picture',
      'create picture',
      'make picture',
      'generate art',
      'create art',
      'make art',
      'generate photo',
      'create photo',
      'make photo',
      'generate illustration',
      'create illustration',
      'make illustration',
      'generate',
      'create',
      'make',
      'draw',
      'design',
      'image',
      'picture',
      'photo',
      'art',
      'illustration',
    ];

    String prompt = text.toLowerCase();
    for (final keyword in keywordsToRemove) {
      prompt = prompt.replaceAll(keyword, '');
    }
    
    // Clean up and capitalize first letter
    prompt = prompt.trim();
    if (prompt.isEmpty) {
      prompt = 'beautiful landscape'; // Default prompt
    }
    
    return prompt;
  }

  // ─── Public helper: Get website URL ──────────────────────────────────────

  static String getWebsiteUrl(String name) {
    return _websiteMap[name.toLowerCase()] ??
        'https://www.google.com/search?q=${name.replaceAll(' ', '+')}';
  }
}
