import 'package:flutter/material.dart' hide HeroMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../domain/models/series.dart';
import '../story/series_home_screen.dart';
import 'theme_catalog.dart';

/// New-series setup: pick a theme, then the hero. The seed comes from the
/// child's latest quiz. (Bilingual toggle + custom-theme text come in 2b.)
/// See `docs/ui-ux.md`.
class NewSeriesScreen extends ConsumerStatefulWidget {
  const NewSeriesScreen({super.key});

  @override
  ConsumerState<NewSeriesScreen> createState() => _NewSeriesScreenState();
}

class _NewSeriesScreenState extends ConsumerState<NewSeriesScreen> {
  final _title = TextEditingController(text: 'Our New Story');
  final _heroName = TextEditingController();
  StoryTheme _theme = StoryTheme.cozy;
  HeroMode _heroMode = HeroMode.childAsHero;
  bool _creating = false;

  @override
  void dispose() {
    _title.dispose();
    _heroName.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final child = ref.read(activeChildProvider);
    if (child == null) return;
    setState(() => _creating = true);

    // Seed the series from the child's most recent quiz.
    final quiz = await ref.read(storageRepoProvider).latestQuizResult(child.id);
    final seed = quiz?.seedSummary ?? '';

    final series = await ref
        .read(seriesServiceProvider)
        .create(
          childId: child.id,
          title: _title.text.trim().isEmpty
              ? 'Our New Story'
              : _title.text.trim(),
          theme: _theme,
          heroMode: _heroMode,
          heroName: _heroMode == HeroMode.namedHero
              ? _heroName.text.trim()
              : null,
          seedSummary: seed,
        );
    ref.invalidate(seriesForChildProvider(child.id));
    ref.read(activeSeriesProvider.notifier).select(series);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SeriesHomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New story')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Story name'),
          ),
          const SizedBox(height: 24),
          Text('Pick a theme', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final entry in themeGroups.entries) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(
                entry.key,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final meta in entry.value)
                  ChoiceChip(
                    label: Text('${meta.emoji} ${meta.label}'),
                    selected: _theme == meta.theme,
                    onSelected: (_) => setState(() => _theme = meta.theme),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'Who is the hero?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          SegmentedButton<HeroMode>(
            segments: const [
              ButtonSegment(
                value: HeroMode.childAsHero,
                label: Text('The child'),
              ),
              ButtonSegment(
                value: HeroMode.namedHero,
                label: Text('A named hero'),
              ),
              ButtonSegment(value: HeroMode.surprise, label: Text('Surprise')),
            ],
            selected: {_heroMode},
            onSelectionChanged: (s) => setState(() => _heroMode = s.first),
          ),
          if (_heroMode == HeroMode.namedHero) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _heroName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: "Hero's name"),
            ),
          ],
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _creating ? null : _create,
            icon: _creating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: const Text('Create story'),
          ),
        ],
      ),
    );
  }
}
