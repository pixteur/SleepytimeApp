import 'package:flutter/material.dart' hide HeroMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../domain/models/beat.dart';
import '../../domain/models/child_profile.dart';
import '../../domain/models/series.dart';
import '../../domain/twist_deck.dart';
import '../story/story_chapters_screen.dart';
import 'theme_catalog.dart';

/// The single story creator: name + theme + hero + length + how tonight begins
/// (dice / option / typed idea), optionally based on a previous story. Builds a
/// brand-new story and opens its chapter list (chapters generate in the
/// background). See `docs/ui-ux.md`.
class NewSeriesScreen extends ConsumerStatefulWidget {
  const NewSeriesScreen({super.key});

  @override
  ConsumerState<NewSeriesScreen> createState() => _NewSeriesScreenState();
}

class _NewSeriesScreenState extends ConsumerState<NewSeriesScreen> {
  final _title = TextEditingController(text: 'Our New Story');
  final _heroName = TextEditingController();
  final _idea = TextEditingController();
  StoryTheme _theme = StoryTheme.cozy;
  HeroMode _heroMode = HeroMode.childAsHero;

  /// The opening choice: a twist-card id, or 'dice' for a random surprise.
  String _opening = 'dice';

  /// When set, the new story is based on (branched from) this existing series.
  String? _baseSeriesId;

  bool _creating = false;

  @override
  void dispose() {
    _title.dispose();
    _heroName.dispose();
    _idea.dispose();
    super.dispose();
  }

  Future<void> _setLength(DetailLevel level) async {
    final child = ref.read(activeChildProvider);
    if (child == null || child.detailLevel == level) return;
    final updated = child.copyWith(detailLevel: level);
    await ref.read(profileServiceProvider).update(updated);
    ref.read(activeChildProvider.notifier).select(updated);
    ref.invalidate(profilesProvider);
  }

  Future<void> _create(List<Series> existing) async {
    final child = ref.read(activeChildProvider);
    if (child == null) return;
    setState(() => _creating = true);
    final svc = ref.read(seriesServiceProvider);
    final title = _title.text.trim().isEmpty
        ? 'Our New Story'
        : _title.text.trim();

    Series series;
    final base = _baseSeriesId == null
        ? null
        : existing.where((s) => s.id == _baseSeriesId).firstOrNull;
    if (base != null) {
      series = await svc.branch(from: base, title: title);
    } else {
      final quiz = await ref
          .read(storageRepoProvider)
          .latestQuizResult(child.id);
      series = await svc.create(
        childId: child.id,
        title: title,
        theme: _theme,
        heroMode: _heroMode,
        heroName: _heroMode == HeroMode.namedHero
            ? _heroName.text.trim()
            : null,
        seedSummary: quiz?.seedSummary ?? '',
      );
    }

    // Resolve how chapter 1 begins.
    final idea = _idea.text.trim();
    final StoryIntent intent;
    final String? twist;
    if (idea.isNotEmpty) {
      intent = StoryIntent.request;
      twist = idea;
    } else if (_opening == 'dice') {
      intent = StoryIntent.dice;
      twist = const TwistDeck().roll().hint;
    } else {
      intent = StoryIntent.option;
      twist = const TwistDeck().byId(_opening)?.hint;
    }

    ref.invalidate(seriesForChildProvider(child.id));
    ref.read(activeSeriesProvider.notifier).select(series);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            StoryChaptersScreen(initialIntent: intent, initialTwist: twist),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final child = ref.watch(activeChildProvider);
    final existing =
        ref.watch(seriesForChildProvider(child?.id ?? '')).asData?.value ??
        const <Series>[];
    final basing = _baseSeriesId != null;

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

          if (existing.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Base it on…', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              initialValue: _baseSeriesId,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('A fresh story'),
                ),
                for (final s in existing)
                  DropdownMenuItem(
                    value: s.id,
                    child: Text(
                      'Same world as “${s.title}”',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _baseSeriesId = v),
            ),
          ],

          // Theme + hero only matter for a fresh story; a based-on story
          // inherits them from the original.
          if (!basing) ...[
            const SizedBox(height: 24),
            Text('Pick a theme', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final entry in themeGroups.entries) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text(entry.key, style: theme.textTheme.labelLarge),
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
            Text('Who is the hero?', style: theme.textTheme.titleMedium),
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
                ButtonSegment(
                  value: HeroMode.surprise,
                  label: Text('Surprise'),
                ),
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
          ],

          const SizedBox(height: 24),
          Text('Story length', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<DetailLevel>(
            segments: const [
              ButtonSegment(value: DetailLevel.short, label: Text('Short')),
              ButtonSegment(value: DetailLevel.medium, label: Text('Medium')),
              ButtonSegment(value: DetailLevel.long, label: Text('Long')),
            ],
            selected: {child?.detailLevel ?? DetailLevel.medium},
            onSelectionChanged: _creating ? null : (s) => _setLength(s.first),
          ),

          const SizedBox(height: 24),
          Text('How does it begin?', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('🎲 Surprise me'),
                selected: _opening == 'dice',
                onSelected: (_) => setState(() => _opening = 'dice'),
              ),
              for (final t in const TwistDeck().options())
                ChoiceChip(
                  label: Text(t.label),
                  selected: _opening == t.id,
                  onSelected: (_) => setState(() => _opening = t.id),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _idea,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: '…or describe the first scene',
              helperText: 'Overrides the choice above when filled',
            ),
          ),

          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _creating ? null : () => _create(existing),
            icon: _creating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_stories),
            label: const Text('Create & build story'),
          ),
        ],
      ),
    );
  }
}
