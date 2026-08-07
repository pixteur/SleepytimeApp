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
  StreamSubscription<void>? _doneSub;
  bool _busy = false;

  // When narration finishes naturally, auto-advance to the next chapter. Only
  // set true once narration has actually STARTED playing — so a failed synth
  // (which also lands the player on "idle") can't be mistaken for "finished"
  // and trigger a rapid jump through chapters.
  bool _autoAdvance = false;

  // True while the cloud voice is synthesizing, before any audio plays. Drives
  // the child-friendly "story is coming" popup and disables the Listen button.
  bool _buffering = false;

  // The edge nav arrows fade away after a few seconds of no interaction, and
  // reappear on any tap/swipe, so they never sit over the text for long.
  bool _controlsVisible = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _tts = ref.read(ttsProvider);
    _stateSub = _tts.stateStream.listen(_onTtsState);
    // Auto-advance ONLY on a genuine finish — never on a stop from navigating.
    _doneSub = _tts.onDone.listen((_) {
      if (_autoAdvance) {
        _autoAdvance = false;
        _autoNext();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _speak());
    _pokeControls();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _stateSub?.cancel();
    _doneSub?.cancel();
    _tts.stop();
    super.dispose();
  }

  /// Show the arrows and (re)start the inactivity timer that hides them.
  void _pokeControls() {
    _hideTimer?.cancel();
    if (!_controlsVisible && mounted) setState(() => _controlsVisible = true);
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  String get _lang => ref.read(activeChildProvider)?.language ?? 'en';
  String? get _seriesId => ref.read(activeSeriesProvider)?.id;

  Future<void> _speak() async {
    if (_buffering) return; // ignore double taps while a synth is in flight
    // Stay put until narration actually starts (the "speaking" state), so a
    // failed synth (which lands on "idle") can't be mistaken for "finished".
    _autoAdvance = false;
    setState(() => _buffering = true);
    unawaited(_preloadNext());
    try {
      await _tts.speak(widget.beat.text, language: _lang);
    } catch (e) {
      if (mounted) showErrorBanner(context, 'Voice unavailable: $e');
    } finally {
      // Backstop in case audio never actually started (e.g. empty text).
      if (mounted && _buffering) setState(() => _buffering = false);
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
    if (s == TtsState.speaking) {
      // Real audio is now playing: hide the buffering popup and arm auto-advance
      // so the chapter advances (via onDone) only when it genuinely finishes.
      if (mounted && _buffering) setState(() => _buffering = false);
      _autoAdvance = true;
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
    _autoAdvance = false; // manual navigation must not chain another advance
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
    _autoAdvance = false;
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
    _autoAdvance = false;
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

    final footer = Padding(
      padding: const EdgeInsets.only(top: 28),
      child: (hasNext || canGenerate)
          ? FilledButton.icon(
              onPressed: _busy ? null : _next,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward_rounded),
              label: Text(hasNext ? 'Next chapter' : 'Continue the story'),
            )
          : (widget.beat.isFinal
                ? Center(
                    child: Text(
                      'The End  🌙',
                      style: theme.textTheme.titleLarge,
                    ),
                  )
                : const SizedBox.shrink()),
    );

    return Scaffold(
      // ── One compact top bar: story name once, chapter under it ──
      appBar: AppBar(
        toolbarHeight: 64,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: widget.beat.seq > 0 ? 'Previous chapter' : 'Back',
          onPressed: _busy ? null : _back,
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: const Text('📖', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    worldName == null ? storyTitle : '$worldName · $storyTitle',
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  InkWell(
                    onTap: _busy ? null : () => _pickChapter(beats),
                    borderRadius: BorderRadius.circular(6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Chapter ${widget.beat.seq + 1}',
                          style: theme.textTheme.bodySmall,
                        ),
                        const Icon(Icons.arrow_drop_down, size: 18),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
      // ── Play/Stop pinned to the bottom of the screen ──
      bottomNavigationBar: SafeArea(
        child: StreamBuilder<TtsState>(
          stream: _tts.stateStream,
          initialData: _tts.state,
          builder: (context, snap) => _ListenBar(
            state: snap.data ?? TtsState.idle,
            buffering: _buffering,
            onToggle: _toggleListen,
          ),
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _pokeControls,
        onHorizontalDragEnd: _onSwipe,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Positioned.fill gives the scroll view a tight, bounded height so
            // the text always lays out (a Center left it unbounded → blank).
            Positioned.fill(
              child: _ReadingText(
                text: widget.beat.text,
                progress: _tts.progressStream,
                style: theme.textTheme.titleMedium?.copyWith(height: 1.6),
                footer: footer,
              ),
            ),
            // Edge arrows fade out after inactivity and sit clear of the text.
            AnimatedOpacity(
              opacity: _controlsVisible ? 1 : 0,
              duration: const Duration(milliseconds: 250),
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (widget.beat.seq > 0)
                      Positioned(
                        left: 0,
                        child: _NavArrow(
                          icon: Icons.chevron_left_rounded,
                          onTap: _busy ? null : _back,
                        ),
                      ),
                    if (hasNext || canGenerate)
                      Positioned(
                        right: 0,
                        child: _NavArrow(
                          icon: Icons.chevron_right_rounded,
                          onTap: _busy ? null : _next,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_buffering) const _BufferingPopup(),
          ],
        ),
      ),
    );
  }

  void _onSwipe(DragEndDetails details) {
    _pokeControls();
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
    iconSize: 24,
    visualDensity: VisualDensity.compact,
    tooltip: icon == Icons.chevron_left_rounded ? 'Previous' : 'Next',
    onPressed: onTap,
  );
}

/// The chapter text with read-along behaviour: it auto-scrolls to keep pace
/// with narration and highlights the word currently being read. Timing is
/// estimated from the audio's play position (0–1 of the chapter), so it tracks
/// the reading closely without needing per-word timestamps.
class _ReadingText extends StatefulWidget {
  const _ReadingText({
    required this.text,
    required this.progress,
    this.style,
    this.footer,
  });

  final String text;
  final Stream<double> progress;
  final TextStyle? style;
  final Widget? footer;

  @override
  State<_ReadingText> createState() => _ReadingTextState();
}

class _Para {
  const _Para(this.start, this.end, this.text);
  final int start;
  final int end;
  final String text;
}

class _ReadingTextState extends State<_ReadingText> {
  final ScrollController _scroll = ScrollController();
  late final List<RegExpMatch> _words;
  late final List<_Para> _paras;
  StreamSubscription<double>? _sub;
  int _current = -1; // global word index being read (-1 = not started)

  @override
  void initState() {
    super.initState();
    _words = RegExp(r'\S+').allMatches(widget.text).toList();
    _paras = _splitParagraphs(widget.text);
    _sub = widget.progress.listen(_onProgress);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  static List<_Para> _splitParagraphs(String text) {
    final out = <_Para>[];
    var cursor = 0;
    for (final m in RegExp(r'\n\s*\n').allMatches(text)) {
      if (text.substring(cursor, m.start).trim().isNotEmpty) {
        out.add(_Para(cursor, m.start, text.substring(cursor, m.start)));
      }
      cursor = m.end;
    }
    if (text.substring(cursor).trim().isNotEmpty) {
      out.add(_Para(cursor, text.length, text.substring(cursor)));
    }
    if (out.isEmpty) out.add(_Para(0, text.length, text));
    return out;
  }

  void _onProgress(double fraction) {
    if (!mounted || _words.isEmpty) return;
    if (fraction <= 0) {
      if (_current != -1) setState(() => _current = -1);
      return;
    }
    final chars = fraction * widget.text.length;
    var idx = -1;
    for (var i = 0; i < _words.length; i++) {
      if (_words[i].start <= chars) {
        idx = i;
      } else {
        break;
      }
    }
    if (idx != _current) setState(() => _current = idx);
    // Keep the reading position in view by scrolling proportionally.
    if (_scroll.hasClients) {
      final max = _scroll.position.maxScrollExtent;
      final target = (fraction * max).clamp(0.0, max);
      if ((target - _scroll.offset).abs() > 24) {
        _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOut,
        );
      }
    }
  }

  int get _currentPara {
    if (_current < 0) return -1;
    final c = _words[_current].start;
    for (var i = 0; i < _paras.length; i++) {
      if (c >= _paras[i].start && c < _paras[i].end) return i;
    }
    return _paras.length - 1;
  }

  /// Spans for one paragraph, highlighting the current word (colour only — no
  /// weight/size change — so following text never shifts).
  List<InlineSpan> _paraSpans(_Para para, TextStyle? highlight) {
    final spans = <InlineSpan>[];
    var cursor = para.start;
    for (var i = 0; i < _words.length; i++) {
      final m = _words[i];
      if (m.end <= para.start) continue;
      if (m.start >= para.end) break;
      if (m.start > cursor) {
        spans.add(TextSpan(text: widget.text.substring(cursor, m.start)));
      }
      spans.add(
        TextSpan(text: m.group(0), style: i == _current ? highlight : null),
      );
      cursor = m.end;
    }
    if (cursor < para.end) {
      spans.add(TextSpan(text: widget.text.substring(cursor, para.end)));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = widget.style ?? theme.textTheme.titleMedium;
    final dim = base?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
    );
    final highlight = base?.copyWith(
      color: theme.colorScheme.onPrimaryContainer,
      backgroundColor: theme.colorScheme.primaryContainer,
    );
    final activePara = _currentPara;

    return SingleChildScrollView(
      controller: _scroll,
      // side padding leaves room for the (auto-hiding) edge arrows
      padding: const EdgeInsets.fromLTRB(40, 12, 40, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < _paras.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: (activePara == -1 || i == activePara)
                  // Reading paragraph (or all, before playback): full brightness
                  // with the current word highlighted.
                  ? Text.rich(
                      TextSpan(children: _paraSpans(_paras[i], highlight)),
                      style: base,
                    )
                  // Other paragraphs are dimmed to keep focus on the reading one.
                  : Text(_paras[i].text.trim(), style: dim),
            ),
          if (widget.footer != null) widget.footer!,
        ],
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 200, maxWidth: 260),
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
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
            ),
          ),
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
