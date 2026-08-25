import 'package:flutter/material.dart';

import '../../domain/models/series.dart';
import '../common/language_choices.dart';

/// What a grown-up chose in [showStoryLanguageSheet].
class StoryLanguages {
  const StoryLanguages({
    required this.baseLanguage,
    required this.bilingualEnabled,
    required this.secondaryLanguage,
    required this.bilingualBlend,
  });

  /// Null means "the child's own language".
  final String? baseLanguage;
  final bool bilingualEnabled;
  final String? secondaryLanguage;
  final BilingualBlend? bilingualBlend;
}

/// Change the languages a story already in progress is told in.
///
/// The creator asks this once; before this sheet existed there was no way back
/// to it, so a story begun in the wrong language stayed that way for good. The
/// wording matches the creator deliberately — the same three choices, in the
/// same order, so it reads as returning to a decision rather than meeting a
/// new one. See `docs/ui-ux.md`.
Future<StoryLanguages?> showStoryLanguageSheet(
  BuildContext context, {
  required Series series,
  required String childLanguage,
}) {
  return showModalBottomSheet<StoryLanguages>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) =>
        _Sheet(series: series, childLanguage: childLanguage),
  );
}

/// How a story handles its second language. Mirrors the creator's choices;
/// `phrases` stays reachable for a story already saved with it.
enum _Mode { one, sprinkle, halfAndHalf }

class _Sheet extends StatefulWidget {
  const _Sheet({required this.series, required this.childLanguage});

  final Series series;
  final String childLanguage;

  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> {
  late String _base = widget.series.baseLanguage ?? '';
  late _Mode _mode = !widget.series.bilingualEnabled
      ? _Mode.one
      : widget.series.bilingualBlend == BilingualBlend.alternating
      ? _Mode.halfAndHalf
      : _Mode.sprinkle;
  late String _second = widget.series.secondaryLanguage ?? 'es';

  String get _main => _base.isNotEmpty ? _base : widget.childLanguage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Languages', style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Chapters already written keep the words they were written '
                'in. This steers the ones still to come.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _base,
                decoration: const InputDecoration(
                  labelText: 'Told in',
                  border: OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: '',
                    child: Text(
                      'Same as the child (${languageLabel(widget.childLanguage)})',
                    ),
                  ),
                  for (final entry in languageChoices.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: (v) => setState(() {
                  _base = v ?? '';
                  // Never offer the same language twice.
                  if (_second == _main) _second = _main == 'es' ? 'fr' : 'es';
                }),
              ),
              const SizedBox(height: 12),
              SegmentedButton<_Mode>(
                segments: const [
                  ButtonSegment(value: _Mode.one, label: Text('One')),
                  ButtonSegment(
                    value: _Mode.sprinkle,
                    label: Text('A few words'),
                  ),
                  ButtonSegment(
                    value: _Mode.halfAndHalf,
                    label: Text('Half & half'),
                  ),
                ],
                selected: {_mode},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() {
                  _mode = s.first;
                  if (_second == _main) _second = _main == 'es' ? 'fr' : 'es';
                }),
              ),
              if (_mode != _Mode.one) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _second,
                  decoration: const InputDecoration(
                    labelText: 'Second language',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final entry in languageChoices.entries)
                      if (entry.key != _main)
                        DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                  ],
                  onChanged: (v) => setState(() => _second = v ?? _second),
                ),
              ],
              const SizedBox(height: 8),
              // Narration is keyed by language as well as voice, so this is
              // the same trap as changing voice — worth saying before it looks
              // like the audio vanished.
              if ((_base.isEmpty ? null : _base) != widget.series.baseLanguage)
                Text(
                  'Changing the language a story is told in means its saved '
                  'narration no longer matches. The recordings are kept, and '
                  'come back if you change it back.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(
                      context,
                      StoryLanguages(
                        baseLanguage: _base.isEmpty ? null : _base,
                        bilingualEnabled: _mode != _Mode.one,
                        secondaryLanguage: _mode == _Mode.one ? null : _second,
                        bilingualBlend: switch (_mode) {
                          _Mode.one => null,
                          _Mode.sprinkle => BilingualBlend.sprinkle,
                          _Mode.halfAndHalf => BilingualBlend.alternating,
                        },
                      ),
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
