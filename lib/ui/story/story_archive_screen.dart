import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import 'story_view_screen.dart';

/// The archive: every past chapter of a series with its short recap. Tap one to
/// re-read and replay it aloud. See `docs/voice-tts.md`, `docs/data-model.md`.
class StoryArchiveScreen extends ConsumerWidget {
  const StoryArchiveScreen({
    super.key,
    required this.seriesId,
    required this.seriesTitle,
  });

  final String seriesId;
  final String seriesTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final beatsAsync = ref.watch(beatsForSeriesProvider(seriesId));
    return Scaffold(
      appBar: AppBar(title: Text('$seriesTitle — past chapters')),
      body: beatsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load chapters:\n$e')),
        data: (beats) => beats.isEmpty
            ? const Center(child: Text('No chapters yet.'))
            : ListView(
                padding: const EdgeInsets.all(8),
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
                      trailing: const Icon(Icons.volume_up_rounded),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              StoryViewScreen(beat: b, canContinue: false),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
