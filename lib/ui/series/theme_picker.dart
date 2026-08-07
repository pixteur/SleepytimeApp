import 'package:flutter/material.dart';

import '../../domain/models/series.dart';
import 'theme_catalog.dart';

/// The grouped theme chips, letting a story blend up to [maxThemes] flavours.
/// [selected] is pick-ordered: the first is the lead theme, the rest colour it.
/// Shared by the story creator and the world editor. See `docs/ui-ux.md`.
class ThemePicker extends StatelessWidget {
  const ThemePicker({
    super.key,
    required this.selected,
    required this.onToggle,
    this.maxThemes = 3,
  });

  /// The most flavours a story can blend at once.
  static const int defaultMax = 3;

  final List<StoryTheme> selected;
  final ValueChanged<StoryTheme> onToggle;
  final int maxThemes;

  /// Apply a tap to a pick-ordered list: add if there's room, remove unless
  /// it's the last one standing. Pure, so callers can reuse it in setState.
  static List<StoryTheme> toggled(
    List<StoryTheme> current,
    StoryTheme t, {
    int maxThemes = defaultMax,
  }) {
    final next = [...current];
    if (next.contains(t)) {
      if (next.length > 1) next.remove(t);
    } else if (next.length < maxThemes) {
      next.add(t);
    }
    return next;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Pick up to $maxThemes themes',
              style: theme.textTheme.titleMedium,
            ),
            const Spacer(),
            Text(
              '${selected.length}/$maxThemes',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        Text(
          selected.length > 1
              ? 'Leading with ${metaFor(selected.first).label} — the others '
                    'colour the story.'
              : 'Tap another to blend two or three flavours together.',
          style: theme.textTheme.bodySmall,
        ),
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
                FilterChip(
                  label: Text('${meta.emoji} ${meta.label}'),
                  selected: selected.contains(meta.theme),
                  // A full hand still lets you deselect, just not add.
                  onSelected:
                      selected.length >= maxThemes &&
                          !selected.contains(meta.theme)
                      ? null
                      : (_) => onToggle(meta.theme),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
