import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adapters/tts/tts_provider.dart';
import '../../app_providers.dart';
import '../../domain/models/beat.dart';
import '../common/error_banner.dart';

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

  // When narration finishes naturally, auto-advance to the next chapter. Only
  // set true once narration has actually STARTED playing — so a failed synth
  // (which also lands the player on "idle") can't be mistaken for "finished"
  // and trigger a rapid jump through chapters.
  bool _autoAdvance = false;

  // True while the cloud voice is synthesizing, before any audio plays. Drives
  // the child-friendly "story is coming" popup and disables the Listen button.
  bool _buffering = false;

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
    if (_buffering) return; // ignore double taps while a synth is in flight
    // Stay put until narration actually starts; only then allow auto-advance.
    _autoAdvance = false;
    setState(() => _buffering = true);
    unawaited(_preloadNext());
    try {
      await _tts.speak(widget.beat.text, language: _lang);
      // speak() returns once playback has begun (it streams). If it didn't
      // throw, narration is really playing — safe to auto-advance at the end.
      _autoAdvance = true;
    } catch (e) {
      _autoAdvance = false;
      if (mounted) showErrorBanner(context, 'Voice unavailable: $e');
    } finally {
      if (mounted) setState(() => _buffering = false);
    }
  }

  /// Single Listen/Stop toggle used by the sticky bar.
  void _toggleListen(TtsState state) {
    if (_buffering) return;
    if (state == TtsState.speaking || state == TtsState.paused) {
      _stop();
    } else {
      _speak();
    }
  }

  /// Warm the next chapter's audio while this one plays, so paging/auto-advancing
  /// forward has no synthesis pause. Best-effort; ignores errors.
  Future<void> _preloadNext() async {
    final id = _seriesId;
    if (id == null || widget.beat.isFinal) return;
    try {
      final beats = await ref.read(storageRepoProvider).loadBeats(id);
      final next = _find(beats, widget.beat.seq + 1);
      if (next != null) await _tts.preload(next.text, language: _lang);
    } catch (_) {
      /* preload is an optimization only */
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
    final engine = ref.read(storyEngineProvider);
    Beat beat;
    try {
      beat = await engine.takeTurn(
        child: child,
        series: series,
        intent: StoryIntent.continued,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showErrorBanner(context, 'Could not load the next chapter: $e');
      return;
    }
    ref.invalidate(beatsForSeriesProvider(id));
    if (!mounted) return;
    setState(() => _busy = false);
    _warnIfFallback(engine.lastFallbackReason);
    await _open(beat);
  }

  /// Tapping the chapter title opens a picker to jump to any chapter.
  Future<void> _pickChapter(List<Beat> beats) async {
    if (beats.isEmpty) return;
    final chosen = await showModalBottomSheet<Beat>(
      context: context,
      showDragHandle: true,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: [
          for (final b in beats)
            ListTile(
              leading: CircleAvatar(child: Text('${b.seq + 1}')),
              title: Text('Chapter ${b.seq + 1}'),
              subtitle: Text(
                b.summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              selected: b.seq == widget.beat.seq,
              trailing: b.seq == widget.beat.seq
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.pop(context, b),
            ),
        ],
      ),
    );
    if (chosen != null && chosen.seq != widget.beat.seq) await _open(chosen);
  }

  /// Surface a placeholder fallback so a generic chapter isn't silent.
  void _warnIfFallback(String? reason) {
    if (reason == null || !mounted) return;
    showErrorBanner(
      context,
      'Story AI unavailable — using a placeholder. ($reason)',
    );
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

    final series = ref.watch(activeSeriesProvider);
    final world = ref.watch(activeWorldProvider);
    final storyTitle = series?.title ?? 'Story';
    final worldName = (world != null && series?.worldId == world.id)
        ? world.name
        : null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: widget.beat.seq > 0 ? 'Previous chapter' : 'Back',
          onPressed: _busy ? null : _back,
        ),
        title: Text(storyTitle, overflow: TextOverflow.ellipsis),
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
                    // ── Sticky header: story/world + chapter (+ icon slot) ──
                    _StoryHeader(
                      worldName: worldName,
                      storyTitle: storyTitle,
                      chapterLabel: 'Chapter ${widget.beat.seq + 1}',
                      onTapChapter: _busy ? null : () => _pickChapter(beats),
                    ),
                    // ── Sticky Listen/Stop bar ──
                    StreamBuilder<TtsState>(
                      stream: _tts.stateStream,
                      initialData: _tts.state,
                      builder: (context, snap) => _ListenBar(
                        state: snap.data ?? TtsState.idle,
                        buffering: _buffering,
                        onToggle: _toggleListen,
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
            if (_buffering) const _BufferingPopup(),
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

/// Sticky title block at the top: the story/world name and the current chapter
/// (tap to jump), with a slot on the left for a future story icon.
class _StoryHeader extends StatelessWidget {
  const _StoryHeader({
    required this.worldName,
    required this.storyTitle,
    required this.chapterLabel,
    required this.onTapChapter,
  });

  final String? worldName;
  final String storyTitle;
  final String chapterLabel;
  final VoidCallback? onTapChapter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            // Icon slot — a book placeholder for now; custom art comes later.
            CircleAvatar(
              radius: 22,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: const Text('📖', style: TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    worldName == null ? storyTitle : '$worldName · $storyTitle',
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  InkWell(
                    onTap: onTapChapter,
                    borderRadius: BorderRadius.circular(6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(chapterLabel, style: theme.textTheme.bodyMedium),
                        const Icon(Icons.arrow_drop_down, size: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The single sticky Listen/Stop button. Shows a spinner while the cloud voice
/// is buffering. Reads "LISTEN" until playing, then "STOP".
class _ListenBar extends StatelessWidget {
  const _ListenBar({
    required this.state,
    required this.buffering,
    required this.onToggle,
  });

  final TtsState state;
  final bool buffering;
  final void Function(TtsState) onToggle;

  @override
  Widget build(BuildContext context) {
    final playing = state == TtsState.speaking || state == TtsState.paused;
    final showStop = playing && !buffering;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: buffering ? null : () => onToggle(state),
          icon: buffering
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(showStop ? Icons.stop_rounded : Icons.volume_up_rounded),
          label: Text(
            showStop ? 'STOP' : 'LISTEN',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
      ),
    );
  }
}

/// A gentle, non-scary popup shown while the voice buffers, so a waiting child
/// knows the story is coming.
class _BufferingPopup extends StatelessWidget {
  const _BufferingPopup();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0x66000000),
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🌙✨', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 12),
                  Text(
                    'Warming up the storyteller…',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  const Text('Your story is coming!'),
                  const SizedBox(height: 16),
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
