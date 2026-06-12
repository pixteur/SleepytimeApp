import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../domain/models/series.dart';
import '../story/series_home_screen.dart';
import 'new_series_screen.dart';
import 'theme_catalog.dart';

/// The child's shelf of storylines. Continue one, or start a new series.
/// See `docs/ui-ux.md`.
class StoryLibraryScreen extends ConsumerWidget {
  const StoryLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(activeChildProvider);
    if (child == null) {
      return const Scaffold(body: Center(child: Text('No child selected.')));
    }
    final seriesAsync = ref.watch(seriesForChildProvider(child.id));

    return Scaffold(
      appBar: AppBar(title: Text("${child.displayName}'s stories")),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _newSeries(context, ref),
        icon: const Icon(Icons.auto_stories),
        label: const Text('New story'),
      ),
      body: seriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load stories:\n$e')),
        data: (series) => series.isEmpty
            ? _empty(context, ref)
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [for (final s in series) _SeriesCard(series: s)],
              ),
      ),
    );
  }

  Widget _empty(BuildContext context, WidgetRef ref) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('📖', style: Theme.of(context).textTheme.displayMedium),
        const SizedBox(height: 12),
        const Text('No stories yet.'),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => _newSeries(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('Start your first story'),
        ),
      ],
    ),
  );

  Future<void> _newSeries(BuildContext context, WidgetRef ref) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NewSeriesScreen()),
    );
  }
}

class _SeriesCard extends ConsumerWidget {
  const _SeriesCard({required this.series});

  final Series series;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = metaFor(series.theme);
    return Card(
      child: ListTile(
        leading: Text(meta.emoji, style: const TextStyle(fontSize: 28)),
        title: Text(series.title),
        subtitle: Text(meta.label),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          ref.read(activeSeriesProvider.notifier).select(series);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SeriesHomeScreen()),
          );
        },
      ),
    );
  }
}
