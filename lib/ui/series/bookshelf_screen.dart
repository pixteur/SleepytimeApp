import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adapters/prefs/app_prefs.dart';
import '../../app_providers.dart';
import '../../domain/models/series.dart';
import '../../domain/models/world.dart';
import '../story/story_chapters_screen.dart';
import 'new_series_screen.dart';
import '../common/hold_to_delete.dart';
import 'theme_catalog.dart';
import 'world_detail_screen.dart';
import 'world_edit_screen.dart';

const _demoAsset = 'assets/seeds/obsidian_stone.sleepy';

/// The bookshelf: the child's story worlds (each a universe of episodes) plus
/// any standalone single stories. See `docs/ui-ux.md`.
class BookshelfScreen extends ConsumerStatefulWidget {
  const BookshelfScreen({super.key});

  @override
  ConsumerState<BookshelfScreen> createState() => _BookshelfScreenState();
}

class _BookshelfScreenState extends ConsumerState<BookshelfScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoSeed());
  }

  /// The first time a child opens an empty bookshelf, load the bundled demo
  /// story so they have something to read right away.
  Future<void> _maybeAutoSeed() async {
    final child = ref.read(activeChildProvider);
    if (child == null) return;
    final prefs = await AppPrefs.open();
    if (prefs.demoSeeded(child.id)) return;
    final series = await ref.read(seriesServiceProvider).forChild(child.id);
    final worlds = await ref.read(worldServiceProvider).forChild(child.id);
    if (series.isEmpty && worlds.isEmpty) {
      await _importDemo(child.id);
    }
    await prefs.setDemoSeeded(child.id);
  }

  Future<void> _importDemo(String childId) async {
    try {
      // Guard on the demo's WORLD ("Bob and Leo") — not the episode title — so a
      // child who has their own standalone "Obsidian Stone" can still load the
      // demo world.
      final worlds = await ref.read(worldServiceProvider).forChild(childId);
      if (worlds.any((w) => w.name == 'Bob and Leo')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('The “Bob and Leo” world is already on the shelf.'),
            ),
          );
        }
        return;
      }
      final data = await rootBundle.load(_demoAsset);
      await ref
          .read(sleepyServiceProvider)
          .importBytes(data.buffer.asUint8List(), childId);
      if (!mounted) return;
      ref.invalidate(seriesForChildProvider(childId));
      ref.invalidate(worldsForChildProvider(childId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not load demo: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final child = ref.watch(activeChildProvider);
    if (child == null) {
      return const Scaffold(body: Center(child: Text('No child selected.')));
    }
    final worlds = ref.watch(worldsForChildProvider(child.id));
    final seriesAsync = ref.watch(seriesForChildProvider(child.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookshelf'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Add a story',
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'demo',
                child: Text('✨ Load the demo story'),
              ),
              PopupMenuItem(
                value: 'import',
                child: Text('Import a .sleepy file…'),
              ),
            ],
            onSelected: (v) {
              if (v == 'demo') _importDemo(child.id);
              if (v == 'import') _import(context, ref, child.id);
            },
          ),
        ],
      ),
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
              // Said once, where the cards are. A gesture nobody knows about
              // is the same as no gesture, and holding is now the only way to
              // delete anything.
              if (ref.watch(parentModeProvider)) ...[
                const SizedBox(height: 16),
                Text(
                  'Hold a card — or right-click it — to delete a world or a '
                  'story.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _empty(BuildContext context, WidgetRef ref) {
    final child = ref.read(activeChildProvider);
    return Center(
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
          if (child != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _importDemo(child.id),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Load the demo story'),
            ),
          ],
        ],
      ),
    );
  }

  void _newStory(BuildContext context, WidgetRef ref) {
    ref.read(activeWorldProvider.notifier).select(null);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NewSeriesScreen()),
    );
  }

  /// Import a `.sleepy` story from the app's exports folder (drop received files
  /// there to share). Lists what's available and imports the chosen one.
  Future<void> _import(
    BuildContext context,
    WidgetRef ref,
    String childId,
  ) async {
    final svc = ref.read(sleepyServiceProvider);
    final files = await svc.listSleepyFiles();
    if (!context.mounted) return;
    if (files.isEmpty) {
      final dir = await svc.exportsDir();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          showCloseIcon: true,
          content: Text('No .sleepy files found. Put them in:\n${dir.path}'),
        ),
      );
      return;
    }
    final chosen = await showModalBottomSheet<File>(
      context: context,
      showDragHandle: true,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: [
          const ListTile(title: Text('Import a story')),
          for (final f in files)
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: Text(f.uri.pathSegments.last),
              onTap: () => Navigator.pop(context, f),
            ),
        ],
      ),
    );
    if (chosen == null || !context.mounted) return;
    try {
      await svc.importFile(chosen.path, childId);
      ref.invalidate(worldsForChildProvider(childId));
      ref.invalidate(seriesForChildProvider(childId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Story imported to your bookshelf.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    }
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
    // ListTile has no right-click of its own, so the card carries it.
    return GestureDetector(
      onSecondaryTap: () => _holdToDelete(context, ref, episodes),
      child: Card(
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
          onLongPress: () => _holdToDelete(context, ref, episodes),
        ),
      ),
    );
  }
}

extension on _WorldCard {
  Future<void> _holdToDelete(
    BuildContext context,
    WidgetRef ref,
    int episodes,
  ) => holdToDelete(
    context,
    enabled: ref.read(parentModeProvider),
    what: world.name,
    icon: metaFor(world.theme).emoji,
    warning:
        'This deletes the world "${world.name}", its characters, and the '
        '$episodes ${episodes == 1 ? "episode" : "episodes"} inside it.',
    onDelete: () async {
      await ref.read(worldServiceProvider).delete(world.id);
      ref.invalidate(worldsForChildProvider(world.childId));
      ref.invalidate(seriesForChildProvider(world.childId));
    },
  );
}

class _StoryCard extends ConsumerWidget {
  const _StoryCard({required this.series});

  final Series series;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = metaFor(series.theme);
    final parentMode = ref.watch(parentModeProvider);
    // ListTile has no right-click of its own, so the card carries it.
    return GestureDetector(
      onSecondaryTap: () => _holdToDelete(context, ref),
      child: Card(
        child: ListTile(
          leading: Text(meta.emoji, style: const TextStyle(fontSize: 28)),
          title: Text(series.title),
          subtitle: Text(
            series.isInProgress
                ? 'Continue — chapter ${series.lastReadSeq! + 1}'
                : meta.label,
          ),
          trailing: parentMode
              ? PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  // Deleting is the hold gesture now, the same as everywhere
                  // else; the menu keeps only what nothing else offers.
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'world',
                      child: Text('Make this a world'),
                    ),
                  ],
                  onSelected: (v) {
                    if (v == 'world') _convertToWorld(context, ref);
                  },
                )
              : null,
          onTap: () {
            ref.read(activeSeriesProvider.notifier).select(series);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StoryChaptersScreen()),
            );
          },
          // The same gesture as deleting an app, for the same reason: it is
          // reachable without hunting for a menu, and impossible to hit by
          // accident. Parent mode only.
          onLongPress: () => _holdToDelete(context, ref),
        ),
      ),
    );
  }

  /// Turn a one-off story into a world, so it can keep going as a series of
  /// episodes. The story becomes episode one; its cast and recap seed the
  /// world, which then opens for polishing.
  Future<void> _convertToWorld(BuildContext context, WidgetRef ref) async {
    final nameC = TextEditingController(text: series.title);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Make this a world'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${series.title}" becomes the first episode of a world, and its '
              'characters are saved so every new episode keeps them. You can '
              'tidy the name, premise, and cast next.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameC,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'World name'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create world'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final world = await ref
        .read(worldServiceProvider)
        .fromSeries(series, name: nameC.text);
    ref.invalidate(worldsForChildProvider(series.childId));
    ref.invalidate(seriesForChildProvider(series.childId));
    ref.invalidate(charactersForWorldProvider(world.id));
    if (!context.mounted) return;
    ref.read(activeWorldProvider.notifier).select(world);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WorldEditScreen(world: world)),
    );
  }

  Future<void> _holdToDelete(BuildContext context, WidgetRef ref) async {
    final chapters =
        (await ref.read(storageRepoProvider).loadBeats(series.id)).length;
    if (!context.mounted) return;
    await holdToDelete(
      context,
      enabled: ref.read(parentModeProvider),
      what: series.title,
      icon: metaFor(series.theme).emoji,
      warning:
          'This deletes "${series.title}" and its '
          '$chapters ${chapters == 1 ? "chapter" : "chapters"}.',
      onDelete: () async {
        await ref.read(seriesServiceProvider).delete(series.id);
        ref.invalidate(seriesForChildProvider(series.childId));
      },
    );
  }
}
