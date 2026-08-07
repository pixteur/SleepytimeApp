import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../domain/models/beat.dart';
import '../../domain/models/series.dart';
import '../common/error_banner.dart';
import '../common/parent_gate.dart';
import 'story_view_screen.dart';

/// A single story's chapter list: start from the beginning or jump to any
/// chapter. For a freshly created story the chapters generate in the background
/// and stream into the list; you can start chapter 1 as soon as it's ready.
/// Replaces the old per-series "tonight begins" screen + archive.
/// See `docs/ui-ux.md`.
class StoryChaptersScreen extends ConsumerStatefulWidget {
  const StoryChaptersScreen({super.key, this.initialIntent, this.initialTwist});

  /// For a brand-new story: how chapter 1 begins (dice / option / typed idea).
  /// Null when opening an existing story from the library.
  final StoryIntent? initialIntent;
  final String? initialTwist;

  @override
  ConsumerState<StoryChaptersScreen> createState() =>
      _StoryChaptersScreenState();
}

class _StoryChaptersScreenState extends ConsumerState<StoryChaptersScreen> {
  static const int _maxChapters = 6;
  bool _building = false;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_build()));
  }

  @override
  void dispose() {
    _active = false;
    super.dispose();
  }

  /// Generate the story to a natural end in the background, one chapter at a
  /// time, refreshing the list as each lands. Chapter 1 uses the chosen opening;
  /// the rest continue. Stops at the cap or the final chapter, and never crashes
  /// the reader.
  Future<void> _build() async {
    final child = ref.read(activeChildProvider);
    final series = ref.read(activeSeriesProvider);
    if (child == null || series == null) return;
    final repo = ref.read(storageRepoProvider);
    final engine = ref.read(storyEngineProvider);

    if (mounted) setState(() => _building = true);
    try {
      var beats = await repo.loadBeats(series.id);
      var first = true;
      while (_active &&
          mounted &&
          beats.length < _maxChapters &&
          !(beats.isNotEmpty && beats.last.isFinal)) {
        final isOpening = beats.isEmpty && first;
        await engine.takeTurn(
          child: child,
          series: series,
          intent: isOpening
              ? (widget.initialIntent ?? StoryIntent.dice)
              : StoryIntent.continued,
          chosenTwist: isOpening ? widget.initialTwist : null,
        );
        first = false;
        if (!_active || !mounted) return;
        ref.invalidate(beatsForSeriesProvider(series.id));
        ref.invalidate(seriesForChildProvider(child.id));
        _warn(engine.lastFallbackReason);
        beats = await repo.loadBeats(series.id);
      }
    } catch (e) {
      if (mounted) {
        showErrorBanner(context, 'Could not finish building the story: $e');
      }
    } finally {
      if (mounted) setState(() => _building = false);
    }
    // Once the text is written, pre-synthesize EVERY chapter's audio into the
    // on-disk cache so the whole story can be re-listened offline with no more
    // API calls. Runs quietly in the background; cache hits are skipped fast.
    unawaited(_prewarmAudio(child.language, series.id));
  }

  /// Warm the audio cache for all chapters of [seriesId], sequentially.
  Future<void> _prewarmAudio(String language, String seriesId) async {
    final tts = ref.read(ttsProvider);
    final repo = ref.read(storageRepoProvider);
    final beats = await repo.loadBeats(seriesId);
    for (final b in beats) {
      if (!_active || !mounted) return;
      try {
        await tts.preload(b.text, language: language);
      } catch (_) {
        return; // best-effort; on-demand synthesis still works
      }
    }
  }

  void _warn(String? reason) {
    if (reason != null && mounted) {
      showErrorBanner(context, 'Story AI used a placeholder. ($reason)');
    }
  }

  /// Bundle this story (text + cached audio + metadata) into a shareable
  /// `.sleepy` file in the app's exports folder.
  Future<void> _export(Series series) async {
    final child = ref.read(activeChildProvider);
    final lang = child?.language ?? 'en';
    final voiceSig = ref.read(ttsProvider).voiceSignature;
    try {
      final path = await ref
          .read(sleepyServiceProvider)
          .exportToFile(series, language: lang, voiceSignature: voiceSig);
      if (mounted) showErrorBanner(context, 'Saved story file: $path');
    } catch (e) {
      if (mounted) showErrorBanner(context, 'Export failed: $e');
    }
  }

  Future<void> _open(Beat beat) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StoryViewScreen(beat: beat)),
    );
  }

  /// Delete a chapter (parent-gated) and renumber the rest so numbering stays
  /// clean (1, 2, 3…). Handy for trimming early placeholder chapters.
  Future<void> _deleteChapter(Beat beat) async {
    final series = ref.read(activeSeriesProvider);
    if (series == null) return;
    if (!await showParentGate(context) || !mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete Chapter ${beat.seq + 1}?'),
        content: const Text('This removes the chapter and its saved text.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final repo = ref.read(storageRepoProvider);
    await repo.deleteBeat(beat.id);
    // Compact seq to 0..n-1 so the list reads 1, 2, 3…
    final remaining = await repo.loadBeats(series.id);
    for (var i = 0; i < remaining.length; i++) {
      if (remaining[i].seq != i) {
        await repo.saveBeat(_withSeq(remaining[i], i));
      }
    }
    if (!mounted) return;
    ref.invalidate(beatsForSeriesProvider(series.id));
  }

  Beat _withSeq(Beat b, int seq) => Beat(
    id: b.id,
    seriesId: b.seriesId,
    childId: b.childId,
    seq: seq,
    intent: b.intent,
    text: b.text,
    summary: b.summary,
    rating: b.rating,
    setting: b.setting,
    chosenTwist: b.chosenTwist,
    characters: b.characters,
    openThreads: b.openThreads,
    language: b.language,
    isFinal: b.isFinal,
  );

  @override
  Widget build(BuildContext context) {
    final series = ref.watch(activeSeriesProvider);
    final theme = Theme.of(context);
    if (series == null) {
      return const Scaffold(body: Center(child: Text('No story selected.')));
    }
    final beats =
        ref.watch(beatsForSeriesProvider(series.id)).asData?.value ??
        const <Beat>[];
    final ended = beats.isNotEmpty && beats.last.isFinal;

    return Scaffold(
      appBar: AppBar(
        title: Text(series.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'Export as .sleepy',
            onPressed: beats.isEmpty ? null : () => _export(series),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: FilledButton.icon(
              onPressed: beats.isEmpty ? null : () => _open(beats.first),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start of story'),
            ),
          ),
          if (_building) const LinearProgressIndicator(),
          Expanded(
            child: beats.isEmpty
                ? const _Writing()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                    itemCount: beats.length,
                    itemBuilder: (_, i) {
                      final b = beats[i];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(child: Text('${b.seq + 1}')),
                          title: Text('Chapter ${b.seq + 1}'),
                          subtitle: Text(
                            b.summary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.volume_up_rounded),
                              PopupMenuButton<String>(
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete chapter'),
                                  ),
                                ],
                                onSelected: (v) {
                                  if (v == 'delete') _deleteChapter(b);
                                },
                              ),
                            ],
                          ),
                          onTap: () => _open(b),
                        ),
                      );
                    },
                  ),
          ),
          if (ended && !_building)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('The End  🌙', style: theme.textTheme.titleMedium),
            ),
        ],
      ),
    );
  }
}

class _Writing extends StatelessWidget {
  const _Writing();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('Writing your story…'),
      ],
    ),
  );
}
