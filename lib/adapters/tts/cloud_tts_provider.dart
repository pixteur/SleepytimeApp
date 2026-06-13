import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import 'tts_provider.dart';
import 'tts_synthesizer.dart';

/// A [TtsProvider] that streams narration: it splits a chapter into paragraphs
/// and synthesizes them one at a time, so playback starts after just the FIRST
/// paragraph (fast) while the rest are fetched in the background. Plays via
/// `audioplayers`. See `docs/voice-tts.md`.
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

  // Paragraph queue + one-ahead prefetch.
  List<String> _chunks = const [];
  int _i = 0;
  bool _active = false;
  Future<Uint8List>? _next;
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

  @override
  Future<void> speak(
    String text, {
    String language = 'en',
    TtsVoicePref voice = const TtsVoicePref(),
  }) async {
    await _player.stop();
    _lang = language;
    _voice = voice;
    _chunks = _splitParagraphs(text);
    _i = 0;
    _next = null;
    _active = true;
    if (_chunks.isEmpty) {
      _set(TtsState.idle);
      return;
    }
    _set(TtsState.speaking);
    await _play(0); // awaits only the FIRST paragraph's synthesis
  }

  Future<void> _play(int i) async {
    try {
      final bytes = _next != null
          ? await _next!
          : await _synth.synthesize(_chunks[i], language: _lang, voice: _voice);
      // Kick off the next paragraph while this one plays.
      _next = (i + 1 < _chunks.length)
          ? _synth.synthesize(_chunks[i + 1], language: _lang, voice: _voice)
          : null;
      if (!_active) return;
      await _player.play(BytesSource(bytes, mimeType: _synth.mimeType));
    } catch (_) {
      _active = false;
      _set(TtsState.idle);
      rethrow;
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
    _next = null;
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

  /// Split into paragraphs (blank-line separated); further split very long
  /// paragraphs by sentence so chunks stay short. The very first chunk is forced
  /// down to a single sentence so playback starts almost immediately instead of
  /// waiting on a whole paragraph to synthesize.
  static List<String> _splitParagraphs(String text, {int maxLen = 500}) {
    final paras = text
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty);
    final out = <String>[];
    for (final p in paras) {
      if (p.length <= maxLen) {
        out.add(p);
        continue;
      }
      final sentences = p.split(RegExp(r'(?<=[.!?])\s+'));
      final buf = StringBuffer();
      for (final s in sentences) {
        if (buf.length + s.length > maxLen && buf.isNotEmpty) {
          out.add(buf.toString().trim());
          buf.clear();
        }
        buf.write('$s ');
      }
      if (buf.isNotEmpty) out.add(buf.toString().trim());
    }
    if (out.isEmpty) {
      final t = text.trim();
      return t.isEmpty ? const [] : [t];
    }
    // Peel the first sentence off the opening chunk for a fast time-to-audio.
    if (out.first.length > 220) {
      final first = out.first;
      final m = RegExp(r'.*?[.!?](\s|$)').firstMatch(first);
      if (m != null && m.end < first.length) {
        out[0] = first.substring(m.end).trim();
        out.insert(0, first.substring(0, m.end).trim());
      }
    }
    return out;
  }
}
