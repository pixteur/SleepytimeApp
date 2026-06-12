import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../domain/models/beat.dart';

/// Displays a generated chapter. "Continue" runs another turn; voice playback
/// arrives in Phase 3. Streaming text is a 2b enhancement. See `docs/ui-ux.md`.
class StoryViewScreen extends ConsumerStatefulWidget {
  const StoryViewScreen({super.key, required this.beat});

  final Beat beat;

  @override
  ConsumerState<StoryViewScreen> createState() => _StoryViewScreenState();
}

class _StoryViewScreenState extends ConsumerState<StoryViewScreen> {
  bool _busy = false;

  Future<void> _continue() async {
    final child = ref.read(activeChildProvider);
    final series = ref.read(activeSeriesProvider);
    if (child == null || series == null) return;
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
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                widget.beat.text,
                style: theme.textTheme.titleMedium?.copyWith(height: 1.6),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _busy ? null : _continue,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_forward_rounded),
                label: const Text('Continue the story'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _busy ? null : () => Navigator.pop(context),
                child: const Text('Back to choices'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
