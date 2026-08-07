import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../common/parent_gate.dart';
import '../series/bookshelf_screen.dart';
import '../series/new_series_screen.dart';
import '../settings/settings_screen.dart';

/// The per-child hub: choose between the existing story Library or building a
/// New story. Shown right after a child is picked. See `docs/ui-ux.md`.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(activeChildProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          child == null ? 'Stories' : '${child.displayName}\'s stories',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Grown-up settings',
            onPressed: () async {
              if (!await showParentGate(context) || !context.mounted) return;
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              _HubCard(
                emoji: '📚',
                title: 'Bookshelf',
                subtitle: 'Your worlds and stories',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BookshelfScreen()),
                ),
              ),
              const SizedBox(height: 16),
              _HubCard(
                emoji: '✨',
                title: 'New story',
                subtitle: 'A world, an episode, or a one-off tale',
                onTap: () {
                  ref.read(activeWorldProvider.notifier).select(null);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NewSeriesScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  const _HubCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 40)),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(subtitle, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
