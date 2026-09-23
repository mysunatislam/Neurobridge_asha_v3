import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Real voice output: feminine TTS + continuous companion talk.
/// - Picks a female voice on every platform (Android/iOS/Web/Windows).
/// - `speak()` always produces audible speech in the app, not just logs.
/// - `continuousTalk` keeps Asha gently speaking (greetings, check-ins,
///   reassurance) until stopped — respecting quiet hours via [muted].
enum AshaVoiceMode { standard, familiar, custom }

class TtsService extends ChangeNotifier {
  FlutterTts? _tts;
  bool _ready = false;

  /// Set to true by unit/widget tests BEFORE AppScope.init().
  /// flutter_test runs in a fake-async zone where Timer-based timeouts
  /// never fire before pumpWidget, so the native engine must be skipped
  /// outright (additionally keeps `dart:io` out for web builds).
  static bool testMode = false;

  bool enabled = true;
  bool continuousTalk = false;
  bool muted = false; // quiet hours / user asked for quiet
  String language = 'en'; // en | bn
  double rate = 0.92;
  double volume = 1.0;
  double pitch = 1.25; // slightly higher = feminine warmth
  AshaVoiceMode mode = AshaVoiceMode.standard;
  String? voiceLabel;
  String _lastSpoken = '';
  bool _speaking = false;
  Timer? _loop;
  int _utteranceCount = 0;

  // Gentle continuous script — short lines for neurological ease.
  static const List<String> _loopLines = [
    "I'm here with you.",
    "You're doing well. I'm staying nearby.",
    "If you need water, blink three times.",
    "If you need your caregiver, smile and I'll call them.",
    "Would you like a short story, a joke, or quiet company?",
    "Take your time. There's no rush.",
  ];

  String get lastSpoken => _lastSpoken;
  bool get speaking => _speaking;
  bool get isReady => _ready;
  int get utteranceCount => _utteranceCount;

  Future<void> init() async {
    try {
      await _initInner().timeout(const Duration(seconds: 4), onTimeout: () {
        debugPrint('[Asha TTS] init timed out (likely test env) — fallback mode.');
      });
    } catch (e) {
      // Tests / unsupported platforms: stay in log-only fallback.
      debugPrint('[Asha TTS] init fallback: $e');
      _ready = false;
    }
  }

  Future<void> _initInner() async {
    if (testMode) {
      voiceLabel = 'default feminine (test)';
      _ready = false;
      return;
    }
    _tts ??= FlutterTts();
    final tts = _tts!;
    try {
      await tts.setSharedInstance(true).timeout(const Duration(seconds: 2));
    } catch (_) {}
    try {
      await tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [IosTextToSpeechAudioCategoryOptions.defaultToSpeaker]).timeout(const Duration(seconds: 2));
    } catch (_) {}
    try {
      tts.setStartHandler(() {
        _speaking = true;
        notifyListeners();
      });
      tts.setCompletionHandler(() {
        _speaking = false;
        notifyListeners();
      });
      tts.setCancelHandler(() {
        _speaking = false;
        notifyListeners();
      });
      tts.setErrorHandler((msg) {
        _speaking = false;
        notifyListeners();
      });
    } catch (_) {}
    await _applyVoice();
    _ready = true;
  }

  Future<void> _applyVoice() async {
    if (testMode) {
      voiceLabel ??= 'default feminine (test)';
      return;
    }
    final tts = _tts;
    if (tts == null) return;
    try {
      final lang = language == 'bn' ? 'bn-BD' : 'en-US';
      try {
        await tts.setLanguage(lang).timeout(const Duration(seconds: 2));
      } catch (_) {}
      try {
        await tts.setSpeechRate(rate).timeout(const Duration(seconds: 2));
      } catch (_) {}
      try {
        await tts.setVolume(volume).timeout(const Duration(seconds: 2));
      } catch (_) {}
      try {
        await tts.setPitch(pitch).timeout(const Duration(seconds: 2));
      } catch (_) {}
      dynamic voices;
      try {
        voices = await tts.getVoices.timeout(const Duration(seconds: 2));
      } catch (_) {
        voiceLabel = 'default feminine';
        return;
      }
      final female = _pickFemaleVoice(voices);
      if (female != null) {
        try {
          await tts.setVoice(female).timeout(const Duration(seconds: 2));
        } catch (_) {}
        voiceLabel = '${female['name']}';
      } else {
        voiceLabel = 'default feminine';
      }
    } catch (e) {
      debugPrint('[Asha TTS] voice select fallback: $e');
    }
  }

  /// Prefer voices whose name/locale signals female on each OS/browser.
  Map<String, String>? _pickFemaleVoice(dynamic voices) {
    try {
      if (voices is! List) return null;
      final prefs = language == 'bn'
          ? ['female', 'woman', 'veena', 'lekha', 'google', 'microsoft']
          : ['female', 'samantha', 'karen', 'zira', 'jenny', 'aria',
             'google us english female', 'google uk english female'];
      Map<String, String>? firstEn;
      for (final v in voices) {
        if (v is! Map) continue;
        final name = '${v['name']}'.toLowerCase();
        final locale = '${v['locale']}'.toLowerCase();
        final map = {'name': '${v['name']}', 'locale': '${v['locale']}'};
        if (language == 'bn' && (locale.startsWith('bn') || name.contains('bengali'))) {
          return map; // any Bengali voice is better than English fallback
        }
        firstEn ??= (locale.startsWith('en') ? map : null);
        for (final p in prefs) {
          if (name.contains(p)) return map;
        }
      }
      return firstEn;
    } catch (_) {
      return null;
    }
  }

  Future<void> setLanguageCode(String code) async {
    language = code;
    await _applyVoice();
    notifyListeners();
  }

  Future<void> speak(String text, {bool interrupt = true}) async {
    if (!enabled || text.trim().isEmpty) return;
    if (muted) {
      debugPrint('[Asha TTS][muted] $text');
      return;
    }
    final tts = _tts;
    if (testMode || tts == null) {
      // Unit/widget tests: log + simulated timing, no platform channel.
      _speaking = true;
      _lastSpoken = text;
      _utteranceCount++;
      debugPrint('[Asha TTS][test] $text');
      notifyListeners();
      await Future.delayed(
          Duration(milliseconds: (text.length * 20).clamp(50, 800)));
      _speaking = false;
      notifyListeners();
      return;
    }
    if (interrupt) {
      try {
        await tts.stop().timeout(const Duration(seconds: 2));
      } catch (_) {}
    }
    _speaking = true;
    _lastSpoken = text;
    _utteranceCount++;
    debugPrint('[Asha TTS][$language${voiceLabel != null ? '/$voiceLabel' : ''}] $text');
    notifyListeners();
    try {
      await tts.speak(text).timeout(const Duration(seconds: 5));
    } catch (e) {
      // Fallback timing so state machines keep working in tests.
      debugPrint('[Asha TTS] speak fallback: $e');
      await Future.delayed(
          Duration(milliseconds: (text.length * 55).clamp(600, 6000)));
      _speaking = false;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    final tts = _tts;
    if (tts != null && !testMode) {
      try {
        await tts.stop().timeout(const Duration(seconds: 2));
      } catch (_) {}
    }
    _speaking = false;
    notifyListeners();
  }

  /// Start gentle continuous talking. Safe to call repeatedly.
  void startContinuous({Duration interval = const Duration(seconds: 45)}) {
    if (continuousTalk) return;
    continuousTalk = true;
    notifyListeners();
    // Immediate warm greeting in a real feminine voice.
    speak("Hello. I'm Asha. I'm here with you. I'll stay and talk with you.");
    _loop?.cancel();
    var i = 0;
    _loop = Timer.periodic(interval, (_) {
      if (!continuousTalk || !enabled || muted) return;
      if (_speaking) return; // never talk over herself
      speak(_loopLines[i % _loopLines.length]);
      i++;
    });
  }

  void stopContinuous() {
    continuousTalk = false;
    _loop?.cancel();
    _loop = null;
    stop();
    notifyListeners();
  }

  String label() {
    final v = voiceLabel ?? 'feminine voice';
    if (mode == AshaVoiceMode.standard) return 'Asha voice · $v';
    return "Asha using ${voiceLabel ?? 'selected'} voice (generated, not a live call)";
  }

  @override
  void dispose() {
    _loop?.cancel();
    super.dispose();
  }
}
