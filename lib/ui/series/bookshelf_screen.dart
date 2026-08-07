import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../domain/models/series.dart';
import '../../domain/models/world.dart';
import '../common/parent_gate.dart';
import '../story/story_chapters_screen.dart';
import 'new_series_screen.dart';
import 'theme_catalog.dart';
import 'world_detail_screen.dart';

/// The bookshelf: the child's story worlds (each a universe of episodes) plus
/// any standalone single stories. See `docs/ui-ux.md`.
class BookshelfScreen extends ConsumerWidget {
  const BookshelfScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(activeChildProvider);
    if (child == null) {
      return const Scaffold(body: Center(child: Text('No child selected.')));
    }
    final worlds = ref.watch(worldsForChildProvider(child.id));
    final seriesAsync = ref.watch(seriesForChildProvider(child.id));

    return Scaffold(
      appBar: AppBar(title: const Text('Bookshelf')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _newStory(context, ref),
        icon: const Icon(Icons.auto_stories),
        label: const Text('New story'),
      ),
      body: worlds.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load worlds:\n$e')),
        data: (worldList) {
          final standalone = (seriesAsync.asData?.value ?? const <Series>[])
              .where((s) => s.worldId == null)
              .toList();
          if (worldList.isEmpty && standalone.isEmpty) {
            return _empty(context, ref);
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (worldList.isNotEmpty) ...[
                Text('Worlds', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final w in worldList) _WorldCard(world: w),
              ],
              if (standalone.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Single stories',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (final s in standalone) _StoryCard(series: s),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _empty(BuildContext context, WidgetRef ref) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('📚', style: Theme.of(context).textTheme.displayMedium),
        const SizedBox(height: 12),
        const Text('Your bookshelf is empty.'),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => _newStory(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('Create your first story'),
        ),
      ],
    ),
  );

  void _newStory(BuildContext context, WidgetRef ref) {
    ref.read(activeWorldProvider.notifier).select(null);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NewSeriesScreen()),
    );
  }
}

class _WorldCard extends ConsumerWidget {
  const _WorldCard({required this.world});

  final World world;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = metaFor(world.theme);
    final episodes =
        (ref.watch(seriesForChildProvider(world.childId)).asData?.value ??
                const <Series>[])
            .where((s) => s.worldId == world.id)
            .length;
    return Card(
      child: ListTile(
        leading: Text(meta.emoji, style: const TextStyle(fontSize: 28)),
        title: Text(world.name),
        subtitle: Text('$episodes ${episodes == 1 ? 'episode' : 'episodes'}'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () {
          ref.read(activeWorldProvider.notifier).select(world);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WorldDetailScreen()),
          );
        },
      ),
    );
  }
}

class _StoryCard extends ConsumerWidget {
  const _StoryCard({required this.series});

  final Series series;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = metaFor(series.theme);
    return Card(
      child: ListTile(
        leading: Text(meta.emoji, style: const TextStyle(fontSize: 28)),
        title: Text(series.title),
        subtitle: Text(meta.label),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'delete', child: Text('Delete story')),
          ],
          onSelected: (v) {
            if (v == 'delete') _confirmDelete(context, ref);
          },
        ),
        onTap: () {
          ref.read(activeSeriesProvider.notifier).select(series);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StoryChaptersScreen()),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    if (!await showParentGate(context) || !context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete story?'),
        content: Text('Delete "${series.title}" and all its chapters?'),
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
    if (ok != true || !context.mounted) return;
    await ref.read(seriesServiceProvider).delete(series.id);
    ref.invalidate(seriesForChildProvider(series.childId));
  }
}
