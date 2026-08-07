import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../domain/models/series.dart';
import '../story/story_chapters_screen.dart';
import 'new_series_screen.dart';
import 'theme_catalog.dart';
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
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in world.allThemes)
                Chip(
                  label: Text('${metaFor(t).emoji} ${metaFor(t).label}'),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
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
              Card(
                child: ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text(s.title),
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
                ),
              ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
