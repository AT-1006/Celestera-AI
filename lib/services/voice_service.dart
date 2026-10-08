import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';

enum VoiceGender { male, female }

class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _isListening = false;
  bool _isInitialized = false;
  bool _isSpeaking = false;
  bool _continuousMode = false;
  Timer? _silenceTimer;
  bool _userSpeaking = false;

  Function(String)? _onResultCallback;
  VoidCallback? _onListeningStopCallback;

  String _lastWords = '';
  VoiceGender _currentGender = VoiceGender.female;

  // Silence detection
  void _startSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(seconds: 3), () {
      if (_isListening && !_userSpeaking) {
        debugPrint('🤫 3 seconds of silence detected - stopping mic');
        _stopListeningForSilence();
      }
    });
  }

  void _stopListeningForSilence() {
    _isListening = false;
    _speech.stop();
    _silenceTimer?.cancel();
    _onListeningStopCallback?.call();
  }

  void _cancelSilenceTimer() {
    _silenceTimer?.cancel();
  }

  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;
  bool get isContinuous => _continuousMode;
  String get lastWords => _lastWords;
  VoiceGender get currentGender => _currentGender;

  // =============================
  // Initialize Speech Recognition
  // =============================
  Future<bool> initializeSpeech() async {
    try {
      final micPermission = await Permission.microphone.request();
      if (micPermission != PermissionStatus.granted) {
        debugPrint('🎤 Mic permission denied');
        return false;
      }

      bool available = await _speech.initialize(
        onStatus: (status) {
          debugPrint('🎤 STT status: $status');

          if (status == "listening") {
            _isListening = true;
            _userSpeaking = true;
            _startSilenceTimer();
          }

          if (status == "done" || status == "notListening") {
            _isListening = false;
            _userSpeaking = false;
            _cancelSilenceTimer();

            // Don't auto-restart in continuous mode - wait for user to tap mic button
          }
        },
        onError: (error) {
          debugPrint('🔥 STT error: ${error.errorMsg}');
          _isListening = false;

          // Restart mic on error in continuous mode
          if (_continuousMode && !_isSpeaking) {
            Future.delayed(const Duration(milliseconds: 500), _restartListening);
          }
        },
      );

      _isInitialized = available;
      if (available) await _configureTts();
      return available;
    } catch (e) {
      debugPrint('🔥 Speech init error: $e');
      return false;
    }
  }

  // =============================
  // Configure TTS
  // =============================
  Future<void> _configureTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.52); // Slightly faster for better flow
    await _tts.setVolume(1.0);
    await _tts.setPitch(_currentGender == VoiceGender.female ? 1.2 : 0.82);

    // Try to pick the best voice
    try {
      final voices = await _tts.getVoices as List?;
      if (voices != null) await _pickBestVoice(voices);
    } catch (_) {}

    _tts.setStartHandler(() {
      _isSpeaking = true;
      debugPrint('🔊 TTS started');
    });

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      debugPrint('🔊 TTS finished');
      // Don't auto-restart mic in continuous mode - wait for user to tap mic button
    });

    _tts.setErrorHandler((msg) {
      _isSpeaking = false;
      debugPrint('🔥 TTS error: $msg');
      if (_continuousMode) {
        Future.delayed(const Duration(milliseconds: 400), _restartListening);
      }
    });
  }

  Future<void> _pickBestVoice(List voices) async {
    for (final voice in voices) {
      if (voice is Map) {
        final name = (voice['name'] ?? '').toString().toLowerCase();
        final locale = (voice['locale'] ?? '').toString().toLowerCase();
        if (!locale.startsWith('en')) continue;

        if (_currentGender == VoiceGender.female) {
          if (name.contains('female') || name.contains('samantha') ||
              name.contains('victoria') || name.contains('karen') ||
              name.contains('zira') || name.contains('google us english female')) {
            await _tts.setVoice({'name': voice['name'], 'locale': voice['locale']});
            return;
          }
        } else {
          if (name.contains('male') || name.contains('daniel') ||
              name.contains('alex') || name.contains('david') ||
              name.contains('mark') || name.contains('fred') ||
              name.contains('google us english male')) {
            await _tts.setVoice({'name': voice['name'], 'locale': voice['locale']});
            return;
          }
        }
      }
    }
    // Fallback to pitch adjustment
    await _tts.setPitch(_currentGender == VoiceGender.female ? 1.2 : 0.82);
  }

  // =============================
  // CONTINUOUS voice chat mode
  // =============================

  /// Start continuous mode — mic stays open like a phone call
  Future<void> startContinuousListening({
    required Function(String) onResult,
    required VoidCallback onListeningStop,
  }) async {
    if (!_isInitialized) return;
    _continuousMode = true;
    _onResultCallback = onResult;
    _onListeningStopCallback = onListeningStop;
    
    // Start listening with silence detection
    await _restartListening();
  }

  /// Internal mic restart — called when user taps mic button again
  Future<void> _restartListening() async {
    if (!_continuousMode || _isSpeaking || !_isInitialized) return;

    if (_isListening) {
      await _speech.stop();
      await Future.delayed(const Duration(milliseconds: 200));
    }

    _lastWords = '';
    _cancelSilenceTimer(); // Cancel any existing silence timer

    try {
      await _speech.listen(
        onResult: (result) {
          if (result.recognizedWords.isNotEmpty) {
            _lastWords = result.recognizedWords;
          }

          if (result.finalResult && _lastWords.isNotEmpty) {
            _isListening = false;
            _userSpeaking = false;
            _cancelSilenceTimer();
            debugPrint('🎤 Got command: $_lastWords');

            final words = _lastWords;
            _lastWords = '';

            _onResultCallback?.call(words);
            _onListeningStopCallback?.call();
          }
        },
        listenFor: const Duration(minutes: 5),  // Effectively unlimited
        pauseFor: const Duration(seconds: 4),   // 4s silence = user done speaking
        localeId: 'en_US',
        listenOptions: SpeechListenOptions(
          cancelOnError: false,
          partialResults: true,  // Live transcription while user speaks
        ),
      );
      _isListening = true;
      _userSpeaking = true;
      _startSilenceTimer(); // Start silence detection
      debugPrint('🎤 Mic open (continuous)');
    } catch (e) {
      debugPrint('🔥 _restartListening error: $e');
      _isListening = false;
      _userSpeaking = false;
      _cancelSilenceTimer();
      if (_continuousMode) {
        await Future.delayed(const Duration(seconds: 1));
        _restartListening();
      }
    }
  }

  /// Stop continuous mode
  Future<void> stopContinuousListening() async {
    _continuousMode = false;
    _onResultCallback = null;
    _onListeningStopCallback = null;
    _cancelSilenceTimer();
    await stopListening();
    debugPrint('🛑 Continuous listening stopped');
  }

  /// Toggle button handler for continuous mode
  Future<void> toggleContinuousListening({
    required Function(String) onResult,
    required VoidCallback onListeningStop,
  }) async {
    if (_continuousMode) {
      await stopContinuousListening();
    } else {
      await startContinuousListening(
        onResult: onResult,
        onListeningStop: onListeningStop,
      );
    }
  }

  // =============================
  // Start Listening (Legacy method for compatibility)
  // =============================
  Future<void> startListening({
    required Function(String) onResult,
    required VoidCallback onListeningStop,
    bool continuousMode = false,
  }) async {
    if (!_isInitialized) return;

    if (_isListening) return;

    if (_isSpeaking) return;

    try {
      await _speech.listen(
        onResult: (result) {
          if (result.recognizedWords.isNotEmpty) {
            _lastWords = result.recognizedWords;
          }

          if (result.finalResult) {
            _isListening = false;
            onResult(_lastWords);
            onListeningStop();
          }
        },

        listenFor: continuousMode 
            ? const Duration(seconds: 10)  // 10 seconds for voice chat mode
            : const Duration(seconds: 30), // Normal listening duration
        pauseFor: continuousMode
            ? const Duration(seconds: 2)   // 2 seconds pause in voice chat mode
            : const Duration(seconds: 4),  // Normal pause duration
        localeId: "en_US",

        listenOptions: SpeechListenOptions(
          cancelOnError: false,
          partialResults: false,
        ),
      );

      _isListening = true;
    } catch (e) {
      debugPrint("Start listening error: $e");
      _isListening = false;
    }
  }

  // =============================
  // Stop Listening
  // =============================
  Future<void> stopListening() async {
    try {
      await _speech.stop();
      _isListening = false;
    } catch (e) {
      debugPrint("Stop listening error: $e");
    }
  }

  // =============================
  // Toggle Listening (Button)
  // =============================
  Future<void> toggleListening({
    required Function(String) onResult,
    required VoidCallback onListeningStop,
    bool continuousMode = false,
  }) async {
    if (_isListening) {
      await stopListening();
      onListeningStop();
    } else {
      await startListening(
        onResult: onResult,
        onListeningStop: onListeningStop,
        continuousMode: continuousMode,
      );
    }
  }

  // =============================
  // Speak AI Response
  // =============================
  Future<void> speak(
    String text, {
    VoidCallback? onComplete,
  }) async {
    if (text.isEmpty) return;

    try {
      // Stop mic before speaking
      if (_isListening) {
        await _speech.stop();
        _isListening = false;
      }
      await _tts.stop();
      _isSpeaking = true;

      _tts.setCompletionHandler(() {
        _isSpeaking = false;
        debugPrint('🔊 TTS done');
        onComplete?.call();
        // Don't auto-restart mic in continuous mode - wait for user to tap mic button
      });

      await _tts.speak(text);
    } catch (e) {
      debugPrint('🔥 speak() error: $e');
      _isSpeaking = false;
      if (_continuousMode) {
        Future.delayed(const Duration(milliseconds: 400), _restartListening);
      }
    }
  }

  // =============================
  // Stop Speaking
  // =============================
  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
      _isSpeaking = false;
    } catch (e) {
      debugPrint("Stop speaking error: $e");
    }
  }

  // =============================
  // Voice Gender Control
  // =============================
  Future<void> setVoiceGender(VoiceGender gender) async {
    _currentGender = gender;
    await _configureTts(); // Reconfigure with new voice
  }

  Future<void> toggleVoiceGender() async {
    _currentGender = _currentGender == VoiceGender.female
        ? VoiceGender.male
        : VoiceGender.female;
    await _configureTts(); // Reconfigure with new voice
  }

  // =============================
  // Cleanup
  // =============================
  void dispose() {
    _continuousMode = false;
    _cancelSilenceTimer();
    _speech.stop();
    _tts.stop();
  }
}
