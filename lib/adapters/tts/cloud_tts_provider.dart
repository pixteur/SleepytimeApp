import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart' hide AudioCache;

import '../ai/rate_limit_retry.dart';
import 'audio_cache.dart';
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
  CloudTtsProvider(
    this._synth,
    this._id, {
    AudioCache? cache,
    AudioPlayer? player,
  }) : _cache = cache, // ignore: prefer_initializing_formals
       _player = player ?? AudioPlayer() {
    _completeSub = _player.onPlayerComplete.listen((_) => _advance());
    _durSub = _player.onDurationChanged.listen((d) => _duration = d);
    _posSub = _player.onPositionChanged.listen((p) {
      final ms = _duration.inMilliseconds;
      if (ms > 0 && !_progress.isClosed) {
        _progress.add((p.inMilliseconds / ms).clamp(0.0, 1.0));
      }
    });
  }

  final TtsSynthesizer _synth;
  final TtsProviderId _id;
  final AudioCache? _cache;
  final AudioPlayer _player;
  late final StreamSubscription<void> _completeSub;
  late final StreamSubscription<Duration> _durSub;
  late final StreamSubscription<Duration> _posSub;
  Duration _duration = Duration.zero;
  final StreamController<TtsState> _states =
      StreamController<TtsState>.broadcast();
  final StreamController<double> _progress =
      StreamController<double>.broadcast();
  final StreamController<void> _done = StreamController<void>.broadcast();
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

  @override
  Stream<double> get progressStream => _progress.stream;

  @override
  Stream<void> get onDone => _done.stream;

  @override
  String get voiceSignature => _synth.voiceSignature;

  @override
  String get audioMimeType => _synth.mimeType;

  void _set(TtsState s) {
    _state = s;
    if (!_states.isClosed) _states.add(s);
  }

  /// Start (or return the running) synthesis job for chunk [i]. Serves from the
  /// on-disk cache when possible; otherwise synthesizes (retrying through
  /// transient 429s) and caches the result for instant replay next time.
  Future<Uint8List> _synthAt(int i) => _jobs[i] ??= _cachedSynthesize(
    _chunks[i],
    _lang,
    _voice,
    cancelled: () => !_active,
  );

  String _keyFor(String chunk, String language) =>
      audioCacheKey('${_synth.voiceSignature}|$language|$chunk');

  Future<Uint8List> _cachedSynthesize(
    String chunk,
    String language,
    TtsVoicePref voice, {
    bool Function()? cancelled,
  }) async {
    final key = _keyFor(chunk, language);
    final hit = await _cache?.get(key);
    if (hit != null && hit.isNotEmpty) return hit;
    final bytes = await retryOnRateLimit(
      () => _synth.synthesize(chunk, language: language, voice: voice),
      cancelled: cancelled ?? () => false,
    );
    await _cache?.put(key, bytes);
    return bytes;
  }

  /// Warm the cache for [text] (the next chapter) without playing it, so paging
  /// forward has no synthesis pause. Runs sequentially in the background and
  /// swallows errors — it's an optimization, not a hard requirement. Does not
  /// touch playback state, so it's safe to call while the current chapter plays.
  @override
  Future<void> preload(
    String text, {
    String language = 'en',
    TtsVoicePref voice = const TtsVoicePref(),
  }) async {
    if (_cache == null) return;
    for (final chunk in _chunkText(text)) {
      try {
        await _cachedSynthesize(chunk, language, voice);
      } catch (_) {
        return;
      }
    }
  }

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
    _duration = Duration.zero;
    if (!_progress.isClosed) _progress.add(0);
    if (_chunks.isEmpty) {
      _set(TtsState.idle);
      return;
    }
    // NB: we do NOT emit "speaking" here — only once audio actually starts (see
    // _play), so the UI's buffering indicator stays up during synthesis.
    await _play(0); // awaits the FIRST chunk's synthesis, then starts playback
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
      _set(TtsState.speaking); // audio is starting for real now
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
      final playedSomething = _state == TtsState.speaking;
      _active = false;
      _set(TtsState.idle);
      // Only a genuine finish (we were actually speaking) counts as "done".
      if (playedSomething && !_done.isClosed) _done.add(null);
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
    if (!_progress.isClosed) _progress.add(0);
    _set(TtsState.idle);
  }

  @override
  Future<void> dispose() async {
    _active = false;
    await _completeSub.cancel();
    await _posSub.cancel();
    await _durSub.cancel();
    await _player.dispose();
    await _states.close();
    await _progress.close();
    await _done.close();
  }

  /// Synthesize a whole chapter as ONE request when possible: a single request
  /// gives a consistent voice (volume/prosody drift between separate Gemini TTS
  /// calls is what made paragraphs sound like "a different reader"), removes
  /// inter-paragraph seams entirely, and makes far fewer API calls (one per
  /// chapter, not per paragraph) — so rate limits are hit far less often.
  ///
  /// Only a very long chapter is split, and then only on sentence boundaries
  /// into large pieces, to stay within the provider's per-request limit.
  static List<String> _chunkText(String text, {int maxLen = 6000}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const [];
    if (trimmed.length <= maxLen) return [trimmed];

    final sentences = trimmed
        .replaceAll(RegExp(r'\n\s*\n'), ' ')
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty);
    final out = <String>[];
    final buf = StringBuffer();
    for (final s in sentences) {
      if (buf.isNotEmpty && buf.length + s.length > maxLen) {
        out.add(buf.toString().trim());
        buf.clear();
      }
      buf.write('$s ');
    }
    if (buf.isNotEmpty) out.add(buf.toString().trim());
    return out.isEmpty ? [trimmed] : out;
  }
}
