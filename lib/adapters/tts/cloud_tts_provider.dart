import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import 'tts_provider.dart';
import 'tts_synthesizer.dart';

/// A [TtsProvider] that synthesizes audio via a [TtsSynthesizer] (OpenAI /
/// ElevenLabs / Gemini) and plays it through `audioplayers`. The playback bar
/// works unchanged. See `docs/voice-tts.md`.
class CloudTtsProvider implements TtsProvider {
  CloudTtsProvider(this._synth, this._id, {AudioPlayer? player})
    : _player = player ?? AudioPlayer() {
    _sub = _player.onPlayerStateChanged.listen((s) {
      _set(switch (s) {
        PlayerState.playing => TtsState.speaking,
        PlayerState.paused => TtsState.paused,
        _ => TtsState.idle,
      });
    });
  }

  final TtsSynthesizer _synth;
  final TtsProviderId _id;
  final AudioPlayer _player;
  late final StreamSubscription<PlayerState> _sub;
  final StreamController<TtsState> _states =
      StreamController<TtsState>.broadcast();
  TtsState _state = TtsState.idle;

  @override
  TtsProviderId get id => _id;

  @override
  TtsState get state => _state;

  @override
  Stream<TtsState> get stateStream => _states.stream;

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
    await _player.stop();
    _set(TtsState.speaking); // optimistic; the player state stream confirms
    try {
      final bytes = await _synth.synthesize(
        text,
        language: language,
        voice: voice,
      );
      await _player.play(BytesSource(bytes, mimeType: _synth.mimeType));
    } catch (_) {
      _set(TtsState.idle);
      rethrow;
    }
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> resume() => _player.resume();

  @override
  Future<void> stop() async {
    await _player.stop();
    _set(TtsState.idle);
  }

  @override
  Future<void> dispose() async {
    await _sub.cancel();
    await _player.dispose();
    await _states.close();
  }
}
