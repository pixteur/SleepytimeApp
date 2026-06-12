import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../domain/models/beat.dart';
import 'story_view_screen.dart';

/// The nightly launch for an open series: Continue, Roll the dice, pick from
/// six option cards, or type a story idea. Each runs a story turn through the
/// engine. See `docs/ui-ux.md`.
class SeriesHomeScreen extends ConsumerStatefulWidget {
  const SeriesHomeScreen({super.key});

  @override
  ConsumerState<SeriesHomeScreen> createState() => _SeriesHomeScreenState();
}

class _SeriesHomeScreenState extends ConsumerState<SeriesHomeScreen> {
  final _idea = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _idea.dispose();
    super.dispose();
  }

  Future<void> _runTurn(StoryIntent intent, {String? twist}) async {
    final child = ref.read(activeChildProvider);
    final series = ref.read(activeSeriesProvider);
    if (child == null || series == null) return;
    setState(() => _busy = true);
    final beat = await ref
        .read(storyEngineProvider)
        .takeTurn(
          child: child,
          series: series,
          intent: intent,
          chosenTwist: twist,
        );
    ref.invalidate(beatsForSeriesProvider(series.id));
    ref.invalidate(seriesForChildProvider(child.id));
    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.push(
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
    final beatsAsync = ref.watch(beatsForSeriesProvider(series.id));
    final hasBeats = beatsAsync.asData?.value.isNotEmpty ?? false;
    final deck = ref.read(twistDeckProvider);

    return Scaffold(
      appBar: AppBar(title: Text(series.title)),
      body: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text('🌙', style: theme.textTheme.displayMedium),
                  const SizedBox(height: 8),
                  Text(
                    'How does tonight begin?',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
                  if (hasBeats)
                    FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _runTurn(StoryIntent.continued),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Continue our story'),
                    ),
                  if (hasBeats) const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: _busy
                        ? null
                        : () => _runTurn(
                            StoryIntent.dice,
                            twist: deck.roll().hint,
                          ),
                    icon: const Icon(Icons.casino_rounded),
                    label: const Text('Roll the dice'),
                  ),
                  const SizedBox(height: 24),
                  Text('…or pick a path', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final twist in deck.options())
                        ActionChip(
                          label: Text(twist.label),
                          onPressed: _busy
                              ? null
                              : () => _runTurn(
                                  StoryIntent.option,
                                  twist: twist.hint,
                                ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _idea,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Tell a story idea…',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.send_rounded),
                        onPressed: _busy ? null : _submitIdea,
                      ),
                    ),
                    onSubmitted: (_) => _submitIdea(),
                  ),
                ],
              ),
            ),
          ),
          if (_busy)
            const ColoredBox(
              color: Color(0x88000000),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('The storyteller is thinking…'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _submitIdea() {
    final text = _idea.text.trim();
    if (text.isEmpty) return;
    _idea.clear();
    _runTurn(StoryIntent.request, twist: text);
  }
}
