import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adapters/ai/provider_exceptions.dart';
import '../../adapters/tts/tts_provider.dart';
import '../../app_providers.dart';
import '../../domain/models/beat.dart';
import '../common/error_banner.dart';
import '../common/marquee_text.dart';

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
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _doneSub?.cancel();
    _tts.stop();
    super.dispose();
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
      await _tts.speak(
        widget.beat.text,
        language: _lang,
        notes: widget.beat.narration,
      );
    } catch (e) {
      if (mounted) showErrorBanner(context, friendlyProviderError(e));
    } finally {
      // Backstop in case audio never actually started (e.g. empty text).
      if (mounted && _buffering) setState(() => _buffering = false);
    }
  }

  /// Play, pause, or pick up where the reading stopped — never start again
  /// from the top. Starting over is a separate, confirmed action, because
  /// losing your place ten minutes into a chapter at bedtime is miserable.
  void _togglePlay(TtsState state) {
    if (_buffering) return;
    switch (state) {
      case TtsState.speaking:
        _tts.pause();
      case TtsState.paused:
        _tts.resume();
      case TtsState.idle:
        _speak();
    }
  }

  /// Back to the first word of this chapter, on purpose.
  Future<void> _startOver() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Start this chapter again?'),
        content: const Text(
          'The reading will go back to the beginning of the chapter.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep listening'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Start over'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _stop();
    if (mounted) await _speak();
  }

  /// Warm the next chapter's audio while this one plays, so paging/auto-advancing
  /// forward has no synthesis pause. Best-effort; ignores errors.
  Future<void> _preloadNext() async {
    final id = _seriesId;
    if (id == null || widget.beat.isFinal) return;
    try {
      final beats = await ref.read(storageRepoProvider).loadBeats(id);
      final next = _find(beats, widget.beat.seq + 1);
      // Warm with the next chapter's own direction, or the cache fills with
      // undirected audio that playback then misses.
      if (next != null) {
        await _tts.preload(
          next.text,
          language: _lang,
          notes: next.narration,
        );
      }
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

  /// Back to this story's chapter list (the screen below the reader).
  Future<void> _toChapters() async {
    await _tts.stop();
    if (mounted) Navigator.of(context).maybePop();
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
            Tooltip(
              message: 'Chapter list',
              child: InkWell(
                onTap: _busy ? null : _toChapters,
                customBorder: const CircleBorder(),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: const Icon(Icons.menu_book_rounded, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarqueeText(
                    worldName == null ? storyTitle : '$worldName · $storyTitle',
                    style: theme.textTheme.titleMedium,
                  ),
                  InkWell(
                    onTap: _busy ? null : () => _pickChapter(beats),
                    borderRadius: BorderRadius.circular(6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          // The title is blank on fallback chapters and on
                          // anything written before chapter titles existed, so
                          // the number always stands on its own.
                          child: MarqueeText(
                            widget.beat.title.trim().isEmpty
                                ? 'Chapter ${widget.beat.seq + 1}'
                                : 'Chapter ${widget.beat.seq + 1} · '
                                      '${widget.beat.title.trim()}',
                            style: theme.textTheme.bodySmall,
                          ),
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
            onToggle: _togglePlay,
            onStartOver: _startOver,
          ),
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: _onSwipe,
        // Column + Expanded forces the reading area to full height so the text
        // always lays out (a bare Stack collapsed and hid the text).
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _ReadingText(
                      text: widget.beat.text,
                      progress: _tts.progressStream,
                      style: theme.textTheme.titleMedium?.copyWith(height: 1.6),
                      footer: footer,
                    ),
                  ),
                  // Edge arrows, vertically centred at each side, always visible.
                  if (widget.beat.seq > 0)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _NavArrow(
                          icon: Icons.chevron_left_rounded,
                          onTap: _busy ? null : _back,
                        ),
                      ),
                    ),
                  if (hasNext || canGenerate)
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _NavArrow(
                          icon: Icons.chevron_right_rounded,
                          onTap: _busy ? null : _next,
                        ),
                      ),
                    ),
                  if (_buffering) const _BufferingPopup(),
                ],
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
  late final List<List<int>> _sentences; // [start, end) offsets into the text
  late final List<_Para> _paras;
  late final List<GlobalKey> _paraKeys;
  StreamSubscription<double>? _sub;
  int _current = -1; // current sentence index (-1 = not started)
  int _lastPara = -1;

  /// How far through the chapter the reading has actually got, 0–1. Only ever
  /// increases, so a stale or out-of-order position report can't rewind the
  /// highlight.
  double _read = 0;

  /// A single tick can't credibly advance more than this much of a chapter —
  /// anything larger is a chunk boundary reporting against the wrong clip.
  static const double _maxJump = 0.2;

  // Auto-scroll follows the reader, but pauses when the user scrolls by hand and
  // gently snaps back to the reading spot a few seconds later.
  bool _autoScroll = true;
  bool _programmatic = false; // true while WE are animating the scroll
  Timer? _resumeTimer;

  @override
  void initState() {
    super.initState();
    _sentences = _splitSentences(widget.text);
    _paras = _splitParagraphs(widget.text);
    _paraKeys = List.generate(_paras.length, (_) => GlobalKey());
    _sub = widget.progress.listen(_onProgress);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _resumeTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  /// Split into sentences (ranges), so we can highlight a whole sentence — much
  /// steadier than per-word when timing is only estimated.
  static List<List<int>> _splitSentences(String text) {
    final out = <List<int>>[];
    for (final m in RegExp(r'[^.!?]*[.!?]+').allMatches(text)) {
      if (text.substring(m.start, m.end).trim().isNotEmpty) {
        out.add([m.start, m.end]);
      }
    }
    final lastEnd = out.isEmpty ? 0 : out.last[1];
    if (lastEnd < text.length && text.substring(lastEnd).trim().isNotEmpty) {
      out.add([lastEnd, text.length]);
    }
    if (out.isEmpty) out.add([0, text.length]);
    return out;
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
    if (!mounted || _sentences.isEmpty) return;
    if (fraction <= 0) {
      if (_current != -1) setState(() => _current = -1);
      _lastPara = -1;
      _read = 0;
      return;
    }
    // Playback is chunked, and at a chunk boundary the position can briefly
    // report against the chunk that just finished — a fraction far ahead of
    // where the reading actually is. Read literally that highlights the last
    // sentence and yanks the view to the bottom of the chapter before the next
    // tick drags it back. Reading only ever moves forward, and only ever a
    // little between ticks, so a leap is noise and a step backwards is stale.
    if (fraction - _read > _maxJump) return;
    if (fraction > _read) _read = fraction;
    final chars = _read * widget.text.length;
    var idx = 0;
    for (var i = 0; i < _sentences.length; i++) {
      if (_sentences[i][0] <= chars) {
        idx = i;
      } else {
        break;
      }
    }
    if (idx != _current) setState(() => _current = idx);
    // Scroll by PARAGRAPH (keep the reading paragraph in view) rather than a
    // blind proportional scroll — this keeps the highlight visible even when the
    // per-word estimate drifts a little.
    final para = _currentPara;
    if (para != _lastPara) {
      _lastPara = para;
      if (_autoScroll) _scrollToPara(para);
    }
  }

  Future<void> _scrollToPara(int para) async {
    if (para < 0 || para >= _paraKeys.length) return;
    final ctx = _paraKeys[para].currentContext;
    if (ctx == null) return;
    _programmatic = true;
    try {
      await Scrollable.ensureVisible(
        ctx,
        alignment: 0.28, // keep the reading paragraph near the top third
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );
    } catch (_) {
      /* context may have gone away */
    } finally {
      _programmatic = false;
    }
  }

  /// The user scrolled by hand: stop auto-following, then resume + snap back to
  /// the reading spot after a few seconds of no manual scrolling.
  void _onUserScroll() {
    _autoScroll = false;
    _resumeTimer?.cancel();
    _resumeTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      _autoScroll = true;
      _scrollToPara(_currentPara);
    });
  }

  int get _currentPara {
    if (_current < 0) return -1;
    final c = _sentences[_current][0];
    // The first paragraph that ENDS after this offset — not the one that
    // strictly contains it. A sentence can begin inside the blank line between
    // two paragraphs, which belongs to no paragraph's range; that offset is the
    // start of the paragraph coming next. Matching only on containment left
    // those sentences unmatched and fell through to the last paragraph, which
    // yanked the view to the bottom of the chapter and back on every one.
    for (var i = 0; i < _paras.length; i++) {
      if (c < _paras[i].end) return i;
    }
    return _paras.length - 1;
  }

  /// Spans for one paragraph, highlighting the part of the current SENTENCE that
  /// falls within it (colour + background only — no weight change, no shift).
  List<InlineSpan> _paraSpans(_Para para, TextStyle? highlight) {
    final text = widget.text;
    if (_current < 0) {
      return [TextSpan(text: text.substring(para.start, para.end))];
    }
    final hlStart = _sentences[_current][0].clamp(para.start, para.end);
    final hlEnd = _sentences[_current][1].clamp(para.start, para.end);
    if (hlStart >= hlEnd) {
      return [TextSpan(text: text.substring(para.start, para.end))];
    }
    return [
      if (para.start < hlStart)
        TextSpan(text: text.substring(para.start, hlStart)),
      TextSpan(text: text.substring(hlStart, hlEnd), style: highlight),
      if (hlEnd < para.end) TextSpan(text: text.substring(hlEnd, para.end)),
    ];
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

    return NotificationListener<ScrollNotification>(
      // A scroll we didn't start (drag or mouse wheel) is the user taking over.
      onNotification: (n) {
        if (n is ScrollUpdateNotification && !_programmatic) _onUserScroll();
        return false;
      },
      child: SingleChildScrollView(
        controller: _scroll,
        // side padding leaves room for the (auto-hiding) edge arrows
        padding: const EdgeInsets.fromLTRB(40, 12, 40, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < _paras.length; i++)
              Padding(
                key: _paraKeys[i],
                padding: const EdgeInsets.only(bottom: 16),
                child: (activePara == -1 || i == activePara)
                    // Reading paragraph (or all, before playback): full
                    // brightness with the current word highlighted.
                    ? Text.rich(
                        TextSpan(children: _paraSpans(_paras[i], highlight)),
                        style: base,
                      )
                    // Other paragraphs dim to keep focus on the reading one.
                    : Text(_paras[i].text.trim(), style: dim),
              ),
            if (widget.footer != null) widget.footer!,
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
    required this.onStartOver,
  });

  final TtsState state;
  final bool buffering;
  final void Function(TtsState) onToggle;
  final Future<void> Function() onStartOver;

  @override
  Widget build(BuildContext context) {
    final speaking = state == TtsState.speaking && !buffering;
    final paused = state == TtsState.paused && !buffering;
    // Start over only exists once there is a place to lose — it would do
    // nothing from idle, where the main button already starts at the top.
    final started = (speaking || paused) && !buffering;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      // Row (not Center) so this bar hugs the button's height — a Center here
      // would expand to fill the whole screen and squash the story text.
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (started) ...[
            IconButton.filledTonal(
              onPressed: onStartOver,
              icon: const Icon(Icons.replay_rounded),
              tooltip: 'Start this chapter again',
            ),
            const SizedBox(width: 12),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 200, maxWidth: 260),
            child: FilledButton.icon(
              onPressed: buffering ? null : () => onToggle(state),
              icon: buffering
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      speaking
                          ? Icons.pause_rounded
                          : paused
                          ? Icons.play_arrow_rounded
                          : Icons.volume_up_rounded,
                    ),
              label: Text(
                speaking
                    ? 'PAUSE'
                    : paused
                    ? 'RESUME'
                    : 'LISTEN',
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
        ],
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
