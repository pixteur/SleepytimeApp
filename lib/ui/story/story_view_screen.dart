import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adapters/ai/provider_exceptions.dart';
import '../../adapters/tts/tts_provider.dart';
import '../../app_providers.dart';
import '../../domain/models/beat.dart';
import '../common/error_banner.dart';
import 'sleep_timer.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markRead();
      _speak();
    });
  }

  /// Remember this chapter as where the story got to, so the bookshelf can
  /// offer to pick it back up.
  Future<void> _markRead() async {
    final series = ref.read(activeSeriesProvider);
    if (series == null) return;
    final updated = await ref
        .read(seriesServiceProvider)
        .markRead(series, widget.beat.seq);
    if (!mounted) return;
    ref.read(activeSeriesProvider.notifier).select(updated);
    ref.invalidate(seriesForChildProvider(series.childId));
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
      await _tts.speak(widget.beat.text, language: _lang);
    } catch (e) {
      if (mounted) showErrorBanner(context, friendlyProviderError(e));
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
    // The sleep timer only ever stops the story *between* chapters when set to
    // "end of chapter" — a chapter is always allowed to finish its sentence.
    if (ref.read(sleepTimerProvider).blocksNextChapter) {
      ref.read(sleepTimerProvider.notifier).off();
      if (mounted) showErrorBanner(context, 'Goodnight 🌙 See you tomorrow.');
      return;
    }
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

  /// Offer the sleep timer: stop at the end of this chapter, or after a while.
  Future<void> _pickSleepTimer() async {
    final current = ref.read(sleepTimerProvider);
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              leading: Icon(Icons.bedtime_rounded),
              title: Text('Stop the story…'),
              subtitle: Text('Narration winds down on its own'),
            ),
            const Divider(height: 1),
            ListTile(
              title: const Text('At the end of this chapter'),
              selected: current.mode == SleepTimerMode.endOfChapter,
              onTap: () => Navigator.pop(context, 'chapter'),
            ),
            for (final minutes in [10, 20, 30])
              ListTile(
                title: Text('In $minutes minutes'),
                onTap: () => Navigator.pop(context, '$minutes'),
              ),
            if (current.isOn)
              ListTile(
                leading: const Icon(Icons.close_rounded),
                title: const Text('Turn the timer off'),
                onTap: () => Navigator.pop(context, 'off'),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    final timer = ref.read(sleepTimerProvider.notifier);
    switch (choice) {
      case 'off':
        timer.off();
      case 'chapter':
        timer.endOfChapter();
      default:
        timer.countdown(int.parse(choice));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final listening = ref.watch(listeningModeProvider);
    final sleepTimer = ref.watch(sleepTimerProvider);

    // The countdown ran out mid-chapter: hush the story where it stands.
    ref.listen<SleepTimer>(sleepTimerProvider, (_, next) {
      if (next.mode == SleepTimerMode.countdown && next.expired) {
        _stop();
        ref.read(sleepTimerProvider.notifier).off();
        if (mounted) showErrorBanner(context, 'Goodnight 🌙 See you tomorrow.');
      }
    });

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

    // Listening mode drops the whole screen to near-black: the point is that
    // there is nothing to look at.
    const night = Color(0xFF07070C);
    return Scaffold(
      backgroundColor: listening ? night : null,
      // ── One compact top bar: story name once, chapter under it ──
      appBar: AppBar(
        backgroundColor: listening ? night : null,
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
            icon: Icon(
              listening ? Icons.visibility_off_rounded : Icons.nightlight_round,
            ),
            tooltip: listening ? 'Show the words' : 'Listen with eyes closed',
            onPressed: () => ref.read(listeningModeProvider.notifier).toggle(),
          ),
          // The timer's label doubles as its "it's on" indicator.
          sleepTimer.isOn
              ? TextButton.icon(
                  onPressed: _pickSleepTimer,
                  icon: const Icon(Icons.bedtime_rounded, size: 18),
                  label: Text(sleepTimer.label),
                )
              : IconButton(
                  icon: const Icon(Icons.bedtime_outlined),
                  tooltip: 'Sleep timer',
                  onPressed: _pickSleepTimer,
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
        onHorizontalDragEnd: _onSwipe,
        // Column + Expanded forces the reading area to full height so the text
        // always lays out (a bare Stack collapsed and hid the text).
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: listening
                        ? _ListeningView(
                            chapter: widget.beat.seq + 1,
                            progress: _tts.progressStream,
                          )
                        : _ReadingText(
                            text: widget.beat.text,
                            progress: _tts.progressStream,
                            style: theme.textTheme.titleMedium?.copyWith(
                              height: 1.6,
                            ),
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

/// Listening mode: no words, no glare. A dim moon, the chapter number, and a
/// hairline showing how far through the chapter the voice has got — enough to
/// tell it's still playing, not enough to look at. See `docs/ui-ux.md`.
class _ListeningView extends StatelessWidget {
  const _ListeningView({required this.chapter, required this.progress});

  final int chapter;
  final Stream<double> progress;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF6E6E85); // dim enough for a dark room
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🌙', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 20),
          Text(
            'Chapter $chapter',
            style: const TextStyle(color: ink, fontSize: 16, letterSpacing: 1),
          ),
          const SizedBox(height: 28),
          StreamBuilder<double>(
            stream: progress,
            initialData: 0,
            builder: (context, snap) => ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: (snap.data ?? 0).clamp(0.0, 1.0),
                minHeight: 3,
                backgroundColor: const Color(0xFF17171F),
                valueColor: const AlwaysStoppedAnimation(ink),
              ),
            ),
          ),
        ],
      ),
    );
  }
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
      return;
    }
    final chars = fraction * widget.text.length;
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
    for (var i = 0; i < _paras.length; i++) {
      if (c >= _paras[i].start && c < _paras[i].end) return i;
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
      // Row (not Center) so this bar hugs the button's height — a Center here
      // would expand to fill the whole screen and squash the story text.
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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
                      showStop ? Icons.stop_rounded : Icons.volume_up_rounded,
                    ),
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
