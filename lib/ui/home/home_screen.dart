import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';

/// The nightly launch screen for the selected child. The three choices are
/// inert in Phase 1 — the story engine + twist deck wire them up in Phase 2.
/// See `docs/ui-ux.md`.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final child = ref.watch(activeChildProvider);
    final name = child?.displayName ?? 'friend';

    return Scaffold(
      appBar: AppBar(title: const Text('SleepytimeApp')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('🌙', style: theme.textTheme.displayLarge),
                const SizedBox(height: 8),
                Text(
                  'Good evening, $name!',
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Stories begin in Phase 2.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                const _LaunchButton(
                  icon: Icons.play_arrow_rounded,
                  label: 'Continue our story…',
                ),
                const SizedBox(height: 12),
                const _LaunchButton(
                  icon: Icons.casino_rounded,
                  label: 'Roll the dice',
                ),
                const SizedBox(height: 12),
                const _LaunchButton(
                  icon: Icons.edit_rounded,
                  label: 'Tell a story idea…',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LaunchButton extends StatelessWidget {
  const _LaunchButton({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.tonalIcon(
        onPressed: null, // wired up in Phase 2
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
        ),
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}
