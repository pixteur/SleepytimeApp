import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../domain/models/beat.dart';
import '../common/error_banner.dart';
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
  }

  void _warn(String? reason) {
    if (reason != null && mounted) {
      showErrorBanner(context, 'Story AI used a placeholder. ($reason)');
    }
  }

  Future<void> _open(Beat beat) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StoryViewScreen(beat: beat)),
    );
  }

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
      appBar: AppBar(title: Text(series.title)),
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
                          trailing: const Icon(Icons.volume_up_rounded),
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
