import 'package:flutter/material.dart';

/// Placeholder launch screen showing the nightly choices. Buttons are inert in
/// Phase 0 — profiles, the story engine, and the twist deck wire them up in
/// Phases 1–2. See `docs/ui-ux.md`.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
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
                Text('SleepytimeApp', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text(
                  'Phase 0 — foundation skeleton',
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
        onPressed: null, // wired up in later phases
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
        ),
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}
