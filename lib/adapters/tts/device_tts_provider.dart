import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

import 'tts_provider.dart';

/// On-device TTS via `flutter_tts` (Windows SAPI/WinRT, macOS/iOS AVSpeech).
/// Free, offline, no key. Cloud expressive voices come later behind the same
/// interface. See `docs/voice-tts.md`.
class DeviceTtsProvider implements TtsProvider {
  DeviceTtsProvider([FlutterTts? tts]) : _tts = tts ?? FlutterTts() {
    _tts
      ..setStartHandler(() => _set(TtsState.speaking))
      ..setCompletionHandler(() => _set(TtsState.idle))
      ..setCancelHandler(() => _set(TtsState.idle))
      ..setPauseHandler(() => _set(TtsState.paused))
      ..setContinueHandler(() => _set(TtsState.speaking))
      ..setErrorHandler((_) => _set(TtsState.idle))
      // Word-boundary progress for read-along highlighting (platform-dependent).
      ..setProgressHandler((text, start, end, word) {
        final len = text.isEmpty ? 1 : text.length;
        if (!_progress.isClosed) _progress.add((end / len).clamp(0.0, 1.0));
      });
  }

  final FlutterTts _tts;
  final StreamController<TtsState> _states =
      StreamController<TtsState>.broadcast();
  final StreamController<double> _progress =
      StreamController<double>.broadcast();
  TtsState _state = TtsState.idle;

  // Device SAPI/WinRT has no reliable resume; remember the last utterance so
  // "resume" restarts it.
  String? _lastText;
  String _lastLang = 'en';
  TtsVoicePref _lastVoice = const TtsVoicePref();

  @override
  TtsProviderId get id => TtsProviderId.device;

  @override
  TtsState get state => _state;

  @override
  Stream<TtsState> get stateStream => _states.stream;

  @override
  Stream<double> get progressStream => _progress.stream;

  @override
  String get voiceSignature => 'device';

  void _set(TtsState s) {
    _state = s;
    if (!_states.isClosed) _states.add(s);
  }

  @override
  Future<void> speak(
    String text, {
    String language = 'en',
    TtsVoicePref voice = const TtsVoicePref(),
  }) async {
    _lastText = text;
    _lastLang = language;
    _lastVoice = voice;
    await _tts.stop();
    await _tts.setLanguage(_bcp47(language));
    await _tts.setPitch(voice.pitch.clamp(0.5, 2.0));
    await _tts.setSpeechRate(voice.rate.clamp(0.0, 1.0));
    await _applyGender(language, voice.gender);
    _set(TtsState.speaking); // optimistic; start handler confirms
    await _tts.speak(text);
  }

  @override
  Future<void> preload(
    String text, {
    String language = 'en',
    TtsVoicePref voice = const TtsVoicePref(),
  }) async {
    // Device TTS synthesizes instantly on speak; nothing to warm.
  }

  @override
  Future<void> pause() => _tts.pause();

  @override
  Future<void> resume() async {
    if (_lastText != null) {
      await speak(_lastText!, language: _lastLang, voice: _lastVoice);
    }
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
    _set(TtsState.idle);
  }

  @override
  Future<void> dispose() async {
    await _tts.stop();
    await _states.close();
    await _progress.close();
  }

  String _bcp47(String lang) => switch (lang) {
    'en' => 'en-US',
    'fr' => 'fr-FR',
    'es' => 'es-ES',
    'ja' => 'ja-JP',
    _ => lang,
  };

  /// Best-effort: pick a device voice matching the requested gender + language.
  Future<void> _applyGender(String lang, TtsGender gender) async {
    if (gender == TtsGender.either) return;
    try {
      final voices = await _tts.getVoices as List<dynamic>?;
      if (voices == null) return;
      final want = gender == TtsGender.male ? 'male' : 'female';
      final lang2 = _bcp47(lang).split('-').first.toLowerCase();
      for (final raw in voices) {
        final v = (raw as Map).cast<String, dynamic>();
        final locale = (v['locale'] ?? '').toString().toLowerCase();
        final name = (v['name'] ?? '').toString().toLowerCase();
        final g = (v['gender'] ?? '').toString().toLowerCase();
        if (locale.startsWith(lang2) && (g == want || name.contains(want))) {
          await _tts.setVoice({
            'name': v['name'].toString(),
            'locale': v['locale'].toString(),
          });
          return;
        }
      }
    } catch (_) {
      // best-effort only — fall back to the default voice
    }
  }
}
