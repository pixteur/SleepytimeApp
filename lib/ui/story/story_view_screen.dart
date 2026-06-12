import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adapters/tts/tts_provider.dart';
import '../../app_providers.dart';
import '../../domain/models/beat.dart';

/// Displays a chapter and reads it aloud (auto-plays on open) with playback
/// controls. "Continue" runs another turn. Character voices + cloud narration
/// come in Phase 3b. See `docs/voice-tts.md`.
class StoryViewScreen extends ConsumerStatefulWidget {
  const StoryViewScreen({
    super.key,
    required this.beat,
    this.canContinue = true,
  });

  final Beat beat;

  /// False when viewing an old chapter from the archive (no "Continue").
  final bool canContinue;

  @override
  ConsumerState<StoryViewScreen> createState() => _StoryViewScreenState();
}

class _StoryViewScreenState extends ConsumerState<StoryViewScreen> {
  late final TtsProvider _tts;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tts = ref.read(ttsProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _speak());
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  String get _lang => ref.read(activeChildProvider)?.language ?? 'en';

  Future<void> _speak() => _tts.speak(widget.beat.text, language: _lang);

  Future<void> _continue() async {
    final child = ref.read(activeChildProvider);
    final series = ref.read(activeSeriesProvider);
    if (child == null || series == null) return;
    await _tts.stop();
    setState(() => _busy = true);
    final beat = await ref
        .read(storyEngineProvider)
        .takeTurn(child: child, series: series, intent: StoryIntent.continued);
    ref.invalidate(beatsForSeriesProvider(series.id));
    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => StoryViewScreen(beat: beat)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Chapter ${widget.beat.seq + 1}')),
      body: Center(
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
                  onStop: _tts.stop,
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  children: [
                    Text(
                      widget.beat.text,
                      style: theme.textTheme.titleMedium?.copyWith(height: 1.6),
                    ),
                    const SizedBox(height: 32),
                    if (widget.canContinue)
                      FilledButton.icon(
                        onPressed: _busy ? null : _continue,
                        icon: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.arrow_forward_rounded),
                        label: const Text('Continue the story'),
                      ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      child: const Text('Back'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaybackBar extends StatelessWidget {
  const _PlaybackBar({
    required this.state,
    required this.onPlay,
    required this.onPause,
    required this.onStop,
  });

  final TtsState state;
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final speaking = state == TtsState.speaking;
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
              tooltip: speaking
                  ? 'Pause'
                  : (state == TtsState.paused ? 'Replay' : 'Read aloud'),
              onPressed: speaking ? onPause : onPlay,
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
