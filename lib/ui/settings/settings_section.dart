import 'package:flutter/material.dart';

/// A titled block on the settings page. Every section looks the same so the
/// page reads as one list rather than several bolted-together screens.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }
}

/// The one control both sections use to pick a provider / engine, so the two
/// choosers look identical. Wraps rather than segments, because the labels are
/// different lengths and the app runs at phone width.
class OptionChips<T> extends StatelessWidget {
  const OptionChips({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    this.enabled = true,
  });

  final String label;
  final List<T> options;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in options)
              ChoiceChip(
                label: Text(labelOf(o)),
                selected: selected == o,
                onSelected: enabled ? (_) => onSelected(o) : null,
              ),
          ],
        ),
      ],
    );
  }
}
