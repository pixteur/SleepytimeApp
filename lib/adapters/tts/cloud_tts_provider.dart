import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import '../ai/rate_limit_retry.dart';
import 'tts_provider.dart';
import 'tts_synthesizer.dart';

/// A [TtsProvider] that streams narration smoothly despite a slow cloud
/// synthesizer (Gemini TTS adds ~10s of fixed latency per request). It splits a
/// chapter into a few sizeable chunks and synthesizes them *all* in the
/// background, sequentially, the moment narration starts — so once the first
/// chunk plays the rest are already buffered and playback is gap-free.
///
/// Two levers keep it smooth:
///  * the first chunk is small (fast time-to-audio),
///  * later chunks are large, so each one's playback comfortably outlasts the
///    next chunk's synthesis.
/// Plays via `audioplayers`. See `docs/voice-tts.md`.
class CloudTtsProvider implements TtsProvider {
  CloudTtsProvider(this._synth, this._id, {AudioPlayer? player})
    : _player = player ?? AudioPlayer() {
    _completeSub = _player.onPlayerComplete.listen((_) => _advance());
  }

  final TtsSynthesizer _synth;
  final TtsProviderId _id;
  final AudioPlayer _player;
  late final StreamSubscription<void> _completeSub;
  final StreamController<TtsState> _states =
      StreamController<TtsState>.broadcast();
  TtsState _state = TtsState.idle;

  // Chunk queue + a cache of in-flight/finished synthesis jobs, keyed by index.
  List<String> _chunks = const [];
  final Map<int, Future<Uint8List>> _jobs = {};
  int _i = 0;
  bool _active = false;
  String _lang = 'en';
  TtsVoicePref _voice = const TtsVoicePref();

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

  /// Start (or return the running) synthesis job for chunk [i]. Retries through
  /// transient provider rate limits (429) so narration doesn't drop out.
  Future<Uint8List> _synthAt(int i) => _jobs[i] ??= retryOnRateLimit(
    () => _synth.synthesize(_chunks[i], language: _lang, voice: _voice),
    cancelled: () => !_active,
  );

  @override
  Future<void> speak(
    String text, {
    String language = 'en',
    TtsVoicePref voice = const TtsVoicePref(),
  }) async {
    await _player.stop();
    _lang = language;
    _voice = voice;
    _chunks = _chunkText(text);
    _jobs.clear();
    _i = 0;
    _active = true;
    if (_chunks.isEmpty) {
      _set(TtsState.idle);
      return;
    }
    _set(TtsState.speaking);
    await _play(0); // awaits only the FIRST chunk's synthesis
  }

  Future<void> _play(int i) async {
    Uint8List bytes;
    try {
      bytes = await _synthAt(i); // usually already buffered
      // Prefetch exactly ONE chunk ahead while this one plays. Because chunks
      // are large, a chunk's playback comfortably outlasts the next chunk's
      // synthesis, so it's ready in time — and pacing it to playback (rather
      // than firing the whole chapter at once) stays under provider rate limits.
      if (_active && i + 1 < _chunks.length) _synthAt(i + 1);
    } catch (_) {
      // Synthesis failed for real (e.g. rate limit exhausted, no key) — surface
      // it so the reader knows the voice is unavailable.
      _active = false;
      _set(TtsState.idle);
      rethrow;
    }
    if (!_active) return;
    // A degenerate buffer (empty / header-only WAV) can make the Windows audio
    // backend throw a RangeError. Skip it and keep the story going instead of
    // dropping narration entirely.
    if (bytes.length < 64) {
      _advance();
      return;
    }
    try {
      await _player.play(BytesSource(bytes, mimeType: _synth.mimeType));
    } catch (_) {
      // This one chunk wouldn't play — skip it and continue with the next.
      _advance();
    }
  }

  void _advance() {
    if (!_active) return;
    _i++;
    if (_i >= _chunks.length) {
      _active = false;
      _set(TtsState.idle);
      return;
    }
    _play(_i).catchError((_) {
      _active = false;
      _set(TtsState.idle);
    });
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    _set(TtsState.paused);
  }

  @override
  Future<void> resume() async {
    await _player.resume();
    _set(TtsState.speaking);
  }

  @override
  Future<void> stop() async {
    _active = false;
    _chunks = const [];
    _jobs.clear();
    await _player.stop();
    _set(TtsState.idle);
  }

  @override
  Future<void> dispose() async {
    _active = false;
    await _completeSub.cancel();
    await _player.dispose();
    await _states.close();
  }

  /// Break [text] into sentence-aligned chunks. The first chunk is kept small
  /// ([firstLen]) for a quick start; the rest are packed up to [maxLen] so each
  /// chunk's playback comfortably outlasts the next chunk's synthesis latency.
  static List<String> _chunkText(
    String text, {
    int firstLen = 320,
    int maxLen = 900,
  }) {
    final sentences = text
        // Treat paragraph breaks as sentence boundaries too.
        .replaceAll(RegExp(r'\n\s*\n'), ' ')
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (sentences.isEmpty) {
      final t = text.trim();
      return t.isEmpty ? const [] : [t];
    }
    final out = <String>[];
    final buf = StringBuffer();
    var target = firstLen;
    for (final s in sentences) {
      if (buf.isNotEmpty && buf.length + s.length > target) {
        out.add(buf.toString().trim());
        buf.clear();
        target = maxLen; // only the first chunk uses the small target
      }
      buf.write('$s ');
    }
    if (buf.isNotEmpty) out.add(buf.toString().trim());
    return out;
  }
}
