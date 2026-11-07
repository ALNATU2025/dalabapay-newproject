// lib/core/hawa_voice.dart
// Voice for Hawa (admin AI): speech-to-text for questions, text-to-speech
// for her answers and for admin alerts, plus the "Talk to Hawa" shortcut on
// the app icon (Android / iPhone: long-press the Dalabapay icon).
//
// Phones don't let apps listen for a wake word in the background, so the
// fastest ways in are the shortcut and tapping an alert notification; both
// open Hawa ready to listen / reading the alert aloud.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class HawaVoice {
  HawaVoice._();
  static final HawaVoice instance = HawaVoice._();

  static const _storage = FlutterSecureStorage();
  static const _kReplies = 'hawa_spoken_replies';
  static const _kAlerts = 'hawa_spoken_alerts';

  final SpeechToText _stt = SpeechToText();
  FlutterTts? _tts;
  bool _sttReady = false;
  bool _sttTried = false;

  /// Hawa reads her answers aloud (speaker button on her page).
  final ValueNotifier<bool> spokenReplies = ValueNotifier(true);

  /// Hawa reads admin alerts aloud when they arrive while the app is open.
  final ValueNotifier<bool> spokenAlerts = ValueNotifier(true);

  /// True while the microphone is on.
  final ValueNotifier<bool> listening = ValueNotifier(false);

  /// True while Hawa is talking.
  final ValueNotifier<bool> speaking = ValueNotifier(false);

  bool _loaded = false;
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      spokenReplies.value = (await _storage.read(key: _kReplies)) != 'off';
      spokenAlerts.value = (await _storage.read(key: _kAlerts)) != 'off';
    } catch (_) {}
  }

  Future<void> setSpokenReplies(bool on) async {
    spokenReplies.value = on;
    if (!on) await stop();
    try {
      await _storage.write(key: _kReplies, value: on ? 'on' : 'off');
    } catch (_) {}
  }

  Future<void> setSpokenAlerts(bool on) async {
    spokenAlerts.value = on;
    try {
      await _storage.write(key: _kAlerts, value: on ? 'on' : 'off');
    } catch (_) {}
  }

  // ── Speaking ─────────────────────────────────────────────
  Future<FlutterTts?> _engine() async {
    if (_tts != null) return _tts;
    try {
      final t = FlutterTts();
      await t.setSpeechRate(kIsWeb ? 1.0 : 0.5);
      await t.setPitch(1.05);
      try {
        await t.setLanguage('en-GB');
      } catch (_) {}
      t.setStartHandler(() => speaking.value = true);
      t.setCompletionHandler(() => speaking.value = false);
      t.setCancelHandler(() => speaking.value = false);
      t.setErrorHandler((_) => speaking.value = false);
      _tts = t;
    } catch (e) {
      debugPrint('Hawa voice (TTS) unavailable: $e');
    }
    return _tts;
  }

  /// Reads [text] aloud (markdown and symbols removed).
  Future<void> speak(String text) async {
    final clean = text
        .replaceAll(RegExp(r'\*\*|__|`|#'), '')
        .replaceAll(RegExp(r'^\s*[-•*]\s+', multiLine: true), '')
        .replaceAll('₦', ' naira ')
        .replaceAll(RegExp(r'\bLe\s?(?=\d)'), 'leones ')
        .trim();
    if (clean.isEmpty) return;
    final t = await _engine();
    if (t == null) return;
    try {
      await t.stop();
      await t.speak(clean);
    } catch (e) {
      debugPrint('Hawa could not speak: $e');
    }
  }

  Future<void> stop() async {
    speaking.value = false;
    try {
      await _tts?.stop();
    } catch (_) {}
  }

  // ── Listening ────────────────────────────────────────────
  Future<bool> get canListen async {
    if (_sttTried) return _sttReady;
    _sttTried = true;
    try {
      _sttReady = await _stt.initialize(
        onStatus: (s) {
          if (s == 'done' || s == 'notListening') listening.value = false;
        },
        onError: (e) {
          listening.value = false;
          debugPrint('Hawa mic error: ${e.errorMsg}');
        },
      );
    } catch (e) {
      debugPrint('Hawa mic unavailable: $e');
      _sttReady = false;
    }
    return _sttReady;
  }

  /// Starts the microphone. [onWords] gets what was heard so far; [onDone]
  /// gets the final words once the admin stops talking.
  Future<bool> listen({required void Function(String words) onWords, required void Function(String words) onDone}) async {
    if (!await canListen) return false;
    await stop(); // don't record Hawa's own voice
    var finished = false;
    listening.value = true;
    try {
      await _stt.listen(
        onResult: (SpeechRecognitionResult r) {
          onWords(r.recognizedWords);
          if (r.finalResult && !finished) {
            finished = true;
            listening.value = false;
            onDone(r.recognizedWords);
          }
        },
        listenFor: const Duration(seconds: 45),
        pauseFor: const Duration(seconds: 3),
        listenOptions: SpeechListenOptions(partialResults: true, listenMode: ListenMode.dictation, cancelOnError: true),
      );
      return true;
    } catch (e) {
      listening.value = false;
      debugPrint('Hawa could not listen: $e');
      return false;
    }
  }

  Future<void> stopListening() async {
    try {
      await _stt.stop();
    } catch (_) {}
    listening.value = false;
  }

  // ── "Talk to Hawa" on the app icon ───────────────────────
  static const shortcutType = 'talk_to_hawa';
  final QuickActions _quick = const QuickActions();
  bool _quickInit = false;

  static bool get _mobile =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  /// Call once at start; [onTalk] opens Hawa ready to listen.
  void initShortcut(void Function() onTalk) {
    if (!_mobile || _quickInit) return;
    _quickInit = true;
    try {
      _quick.initialize((type) {
        if (type == shortcutType) onTalk();
      });
    } catch (e) {
      debugPrint('App shortcuts unavailable: $e');
    }
  }

  /// Shows the shortcut for admins, removes it for everyone else.
  Future<void> updateShortcut({required bool admin}) async {
    if (!_mobile) return;
    try {
      if (admin) {
        await _quick.setShortcutItems(const [
          ShortcutItem(type: shortcutType, localizedTitle: 'Talk to Hawa'),
        ]);
      } else {
        await _quick.clearShortcutItems();
      }
    } catch (e) {
      debugPrint('App shortcut not set: $e');
    }
  }
}
