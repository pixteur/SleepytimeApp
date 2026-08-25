import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../domain/models/series.dart';
import '../common/hold_to_delete.dart';
import '../story/story_chapters_screen.dart';
import 'new_series_screen.dart';
import 'world_edit_screen.dart';

/// A single world (universe): what it's about and the episodes told in it, plus
/// a way to spin up a new one. Everything a grown-up can change — the cast, the
/// flavours, the world itself — lives behind "Edit world", so this page stays a
/// child's reading list. See `docs/ui-ux.md`.
class WorldDetailScreen extends ConsumerWidget {
  const WorldDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final world = ref.watch(activeWorldProvider);
    if (world == null) {
      return const Scaffold(body: Center(child: Text('No world selected.')));
    }
    final episodes =
        (ref.watch(seriesForChildProvider(world.childId)).asData?.value ??
                const <Series>[])
            .where((s) => s.worldId == world.id)
            .toList();
    final theme = Theme.of(context);
    final parentMode = ref.watch(parentModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(world.name),
        actions: [
          if (parentMode)
            TextButton.icon(
              icon: const Icon(Icons.tune),
              label: const Text('Edit world'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WorldEditScreen(world: world),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NewSeriesScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New episode'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (world.premise.trim().isNotEmpty) ...[
            Text(world.premise, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: 24),
          Text('Episodes', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (episodes.isEmpty)
            Text(
              'No episodes yet — tap “New episode” to write the first one.',
              style: theme.textTheme.bodySmall,
            )
          else
            for (final s in episodes)
              // ListTile has no right-click of its own, so the card carries it.
              GestureDetector(
                onSecondaryTap: () => _deleteEpisode(context, ref, s),
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.menu_book_outlined),
                    title: Text(s.title),
                    subtitle: s.isInProgress
                        ? Text('Continue — chapter ${s.lastReadSeq! + 1}')
                        : null,
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      ref.read(activeSeriesProvider.notifier).select(s);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const StoryChaptersScreen(),
                        ),
                      );
                    },
                    // An episode is deleted the same way as everything else.
                    // Before this it could not be deleted at all: the
                    // bookshelf only lists standalone stories, so an episode
                    // had nowhere to be held.
                    onLongPress: () => _deleteEpisode(context, ref, s),
                  ),
                ),
              ),
          if (parentMode && episodes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Hold an episode — or right-click it — to delete it.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Future<void> _deleteEpisode(
    BuildContext context,
    WidgetRef ref,
    Series episode,
  ) async {
    final chapters =
        (await ref.read(storageRepoProvider).loadBeats(episode.id)).length;
    if (!context.mounted) return;
    await holdToDelete(
      context,
      enabled: ref.read(parentModeProvider),
      what: episode.title,
      icon: '📖',
      warning:
          'This deletes the episode "${episode.title}" and its '
          '$chapters ${chapters == 1 ? "chapter" : "chapters"}. The world and '
          'its other episodes are left alone.',
      onDelete: () async {
        await ref.read(seriesServiceProvider).delete(episode.id);
        ref.invalidate(seriesForChildProvider(episode.childId));
      },
    );
  }
}
