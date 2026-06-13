import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adapters/tts/tts_provider.dart';
import '../../app_providers.dart';
import '../../domain/models/beat.dart';

/// Displays one chapter, reads it aloud (auto-plays, streamed paragraph-by-
/// paragraph), and pages through the story: Back = previous chapter, Next =
/// next chapter (generating it if needed), Home = back to the app home.
/// See `docs/ui-ux.md`, `docs/voice-tts.md`.
class StoryViewScreen extends ConsumerStatefulWidget {
  const StoryViewScreen({
    super.key,
    required this.beat,
    this.canContinue = true,
  });

  final Beat beat;

  /// False when viewing from the archive (no generating new chapters).
  final bool canContinue;

  @override
  ConsumerState<StoryViewScreen> createState() => _StoryViewScreenState();
}

class _StoryViewScreenState extends ConsumerState<StoryViewScreen> {
  late final TtsProvider _tts;
  StreamSubscription<TtsState>? _stateSub;
  bool _busy = false;

  // When narration finishes naturally, auto-advance to the next chapter.
  // Cleared when the user stops, so Stop doesn't trigger an advance.
  bool _autoAdvance = false;

  @override
  void initState() {
    super.initState();
    _tts = ref.read(ttsProvider);
    _stateSub = _tts.stateStream.listen(_onTtsState);
    WidgetsBinding.instance.addPostFrameCallback((_) => _speak());
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _tts.stop();
    super.dispose();
  }

  String get _lang => ref.read(activeChildProvider)?.language ?? 'en';
  String? get _seriesId => ref.read(activeSeriesProvider)?.id;

  Future<void> _speak() async {
    _autoAdvance = true;
    try {
      await _tts.speak(widget.beat.text, language: _lang);
    } catch (e) {
      _autoAdvance = false;
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Voice unavailable: $e')));
    }
  }

  void _onTtsState(TtsState s) {
    if (s == TtsState.idle && _autoAdvance) {
      _autoAdvance = false;
      _autoNext();
    }
  }

  /// Auto-advance to the next chapter when this one finishes reading.
  Future<void> _autoNext() async {
    if (!mounted || _busy) return;
    final id = _seriesId;
    if (id == null) return;
    final beats = await ref.read(storageRepoProvider).loadBeats(id);
    final hasNext = beats.any((b) => b.seq == widget.beat.seq + 1);
    final canGenerate = widget.canContinue && !widget.beat.isFinal && !hasNext;
    if (hasNext || canGenerate) await _next();
  }

  /// User-initiated stop — cancels auto-advance so it stays put.
  Future<void> _stop() async {
    _autoAdvance = false;
    await _tts.stop();
  }

  Beat? _find(List<Beat> beats, int seq) {
    for (final b in beats) {
      if (b.seq == seq) return b;
    }
    return null;
  }

  Future<void> _open(Beat beat) async {
    await _tts.stop();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            StoryViewScreen(beat: beat, canContinue: widget.canContinue),
      ),
    );
  }

  Future<void> _goToSeq(int seq) async {
    final id = _seriesId;
    if (id == null) return;
    final beats = await ref.read(storageRepoProvider).loadBeats(id);
    final target = _find(beats, seq);
    if (target != null) await _open(target);
  }

  Future<void> _back() async {
    if (widget.beat.seq > 0) {
      await _goToSeq(widget.beat.seq - 1);
    } else {
      await _tts.stop();
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _home() async {
    await _tts.stop();
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  /// Restart from chapter 1 (re-reads and re-narrates from the start).
  Future<void> _restart() => _goToSeq(0);

  Future<void> _next() async {
    final id = _seriesId;
    if (id == null) return;
    final beats = await ref.read(storageRepoProvider).loadBeats(id);
    final existing = _find(beats, widget.beat.seq + 1);
    if (existing != null) {
      await _open(existing);
      return;
    }
    if (!widget.canContinue || widget.beat.isFinal) return;
    final child = ref.read(activeChildProvider);
    final series = ref.read(activeSeriesProvider);
    if (child == null || series == null) return;
    await _tts.stop();
    setState(() => _busy = true);
    final beat = await ref
        .read(storyEngineProvider)
        .takeTurn(child: child, series: series, intent: StoryIntent.continued);
    ref.invalidate(beatsForSeriesProvider(id));
    if (!mounted) return;
    setState(() => _busy = false);
    await _open(beat);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final seriesId = _seriesId;
    final beats = seriesId == null
        ? const <Beat>[]
        : (ref.watch(beatsForSeriesProvider(seriesId)).asData?.value ??
              const <Beat>[]);
    final hasNext = beats.any((b) => b.seq == widget.beat.seq + 1);
    final canGenerate = widget.canContinue && !widget.beat.isFinal && !hasNext;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: widget.beat.seq > 0 ? 'Previous chapter' : 'Back',
          onPressed: _busy ? null : _back,
        ),
        title: Text('Chapter ${widget.beat.seq + 1}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.replay_rounded),
            tooltip: 'Start from chapter 1',
            onPressed: _busy ? null : _restart,
          ),
          IconButton(
            icon: const Icon(Icons.home_rounded),
            tooltip: 'Home',
            onPressed: _busy ? null : _home,
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: _onSwipe,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  children: [
                    StreamBuilder<TtsState>(
                      stream: _tts.stateStream,
                      initialData: _tts.state,
                      builder: (context, snap) => _PlaybackBar(
                        state: snap.data ?? TtsState.idle,
                        onPlay: _speak,
                        onPause: _tts.pause,
                        onResume: _tts.resume,
                        onStop: _stop,
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        // wider side padding leaves room for the edge arrows
                        padding: const EdgeInsets.fromLTRB(56, 8, 56, 24),
                        children: [
                          Text(
                            widget.beat.text,
                            style: theme.textTheme.titleMedium?.copyWith(
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 32),
                          if (hasNext || canGenerate)
                            FilledButton.icon(
                              onPressed: _busy ? null : _next,
                              icon: _busy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.arrow_forward_rounded),
                              label: Text(
                                hasNext ? 'Next chapter' : 'Continue the story',
                              ),
                            )
                          else if (widget.beat.isFinal)
                            Center(
                              child: Text(
                                'The End  🌙',
                                style: theme.textTheme.titleLarge,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.beat.seq > 0)
              Positioned(
                left: 4,
                child: _NavArrow(
                  icon: Icons.chevron_left_rounded,
                  onTap: _busy ? null : _back,
                ),
              ),
            if (hasNext || canGenerate)
              Positioned(
                right: 4,
                child: _NavArrow(
                  icon: Icons.chevron_right_rounded,
                  onTap: _busy ? null : _next,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _onSwipe(DragEndDetails details) {
    if (_busy) return;
    final v = details.primaryVelocity ?? 0;
    if (v > 250 && widget.beat.seq > 0) {
      _back(); // swipe right → previous chapter
    } else if (v < -250) {
      _next(); // swipe left → next chapter (no-op at the end)
    }
  }
}

class _NavArrow extends StatelessWidget {
  const _NavArrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => IconButton.filledTonal(
    icon: Icon(icon),
    iconSize: 32,
    tooltip: icon == Icons.chevron_left_rounded ? 'Previous' : 'Next',
    onPressed: onTap,
  );
}

class _PlaybackBar extends StatelessWidget {
  const _PlaybackBar({
    required this.state,
    required this.onPlay,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  final TtsState state;
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final speaking = state == TtsState.speaking;
    final paused = state == TtsState.paused;
    final label = switch (state) {
      TtsState.speaking => 'Reading aloud…',
      TtsState.paused => 'Paused',
      TtsState.idle => 'Tap to read aloud',
    };
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(
                speaking ? Icons.pause_rounded : Icons.volume_up_rounded,
              ),
              tooltip: speaking ? 'Pause' : (paused ? 'Resume' : 'Read aloud'),
              onPressed: speaking ? onPause : (paused ? onResume : onPlay),
            ),
            IconButton(
              icon: const Icon(Icons.stop_rounded),
              tooltip: 'Stop',
              onPressed: state == TtsState.idle ? null : onStop,
            ),
            const SizedBox(width: 8),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
