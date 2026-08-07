import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../domain/models/series.dart';
import '../../domain/models/story_character.dart';
import '../common/parent_gate.dart';
import '../story/story_chapters_screen.dart';
import 'new_series_screen.dart';

/// A single world (universe): its saved characters and its episodes, plus a way
/// to spin up a new episode in the same world. See `docs/ui-ux.md`.
class WorldDetailScreen extends ConsumerWidget {
  const WorldDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final world = ref.watch(activeWorldProvider);
    if (world == null) {
      return const Scaffold(body: Center(child: Text('No world selected.')));
    }
    final characters = ref.watch(charactersForWorldProvider(world.id));
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
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete world',
              onPressed: () => _deleteWorld(context, ref),
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
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Text('Characters', style: theme.textTheme.titleMedium),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _editCharacter(context, ref, world.id),
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          characters.when(
            loading: () =>
                const Padding(padding: EdgeInsets.all(8), child: Text('…')),
            error: (e, _) => Text('Could not load characters: $e'),
            data: (list) => list.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No saved characters yet. Add one so every episode keeps '
                      'them consistent.',
                      style: theme.textTheme.bodySmall,
                    ),
                  )
                : Column(
                    children: [
                      for (final c in list)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.person_outline),
                            title: Text(c.name),
                            subtitle: c.description.trim().isEmpty
                                ? null
                                : Text(c.description),
                            trailing: parentMode
                                ? PopupMenuButton<String>(
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Text('Edit'),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Delete'),
                                      ),
                                    ],
                                    onSelected: (v) async {
                                      if (v == 'edit') {
                                        _editCharacter(
                                          context,
                                          ref,
                                          world.id,
                                          c,
                                        );
                                      } else if (v == 'delete') {
                                        await ref
                                            .read(characterServiceProvider)
                                            .delete(c.id);
                                        ref.invalidate(
                                          charactersForWorldProvider(world.id),
                                        );
                                      }
                                    },
                                  )
                                : null,
                          ),
                        ),
                    ],
                  ),
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

  Future<void> _editCharacter(
    BuildContext context,
    WidgetRef ref,
    String worldId, [
    StoryCharacter? existing,
  ]) async {
    final nameC = TextEditingController(text: existing?.name ?? '');
    final descC = TextEditingController(text: existing?.description ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? 'Add character' : 'Edit character'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameC,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descC,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description (who are they?)',
              ),
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
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved != true || nameC.text.trim().isEmpty) return;
    final svc = ref.read(characterServiceProvider);
    if (existing == null) {
      await svc.create(
        worldId: worldId,
        name: nameC.text.trim(),
        description: descC.text.trim(),
      );
    } else {
      await svc.update(
        existing.copyWith(
          name: nameC.text.trim(),
          description: descC.text.trim(),
        ),
      );
    }
    ref.invalidate(charactersForWorldProvider(worldId));
  }

  Future<void> _deleteWorld(BuildContext context, WidgetRef ref) async {
    final world = ref.read(activeWorldProvider);
    if (world == null) return;
    if (!await showParentGate(context) || !context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete world?'),
        content: Text(
          'Delete "${world.name}", its characters, and ALL its episodes? '
          'This can\'t be undone.',
        ),
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
    await ref.read(worldServiceProvider).delete(world.id);
    ref.invalidate(worldsForChildProvider(world.childId));
    ref.invalidate(seriesForChildProvider(world.childId));
    if (context.mounted) Navigator.pop(context);
  }
}
