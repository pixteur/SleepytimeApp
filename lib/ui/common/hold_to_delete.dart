import 'package:flutter/material.dart';

import 'confirm_destructive.dart';

/// Hold a card to delete what it stands for — a child, a story, a world.
///
/// Modelled on deleting an app on a phone, because that is the gesture a
/// grown-up already knows: nothing is offered on a tap, and holding reveals a
/// single destructive action rather than performing one. A child who holds a
/// card by accident sees a sheet they can dismiss, and could not get past the
/// parent gate behind it anyway.
///
/// [enabled] is the parent-mode switch. Off, holding does nothing at all —
/// not a disabled menu, not a locked dialog. There is nothing to find.
///
/// Returns true only if something was actually deleted. See `docs/ui-ux.md`.
Future<bool> holdToDelete(
  BuildContext context, {
  required bool enabled,
  required String what,
  required String warning,
  required Future<void> Function() onDelete,
  String? icon,
}) async {
  if (!enabled) return false;

  final chosen = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final scheme = Theme.of(sheetContext).colorScheme;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: icon == null
                  ? null
                  : Text(icon, style: const TextStyle(fontSize: 24)),
              title: Text(
                what,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.delete_outline, color: scheme.error),
              title: Text('Delete', style: TextStyle(color: scheme.error)),
              subtitle: const Text('This cannot be undone'),
              onTap: () => Navigator.pop(sheetContext, true),
            ),
            ListTile(
              leading: const Icon(Icons.close_rounded),
              title: const Text('Keep it'),
              onTap: () => Navigator.pop(sheetContext, false),
            ),
          ],
        ),
      );
    },
  );
  if (chosen != true || !context.mounted) return false;

  // The gate and the two questions live here, so every hold-to-delete asks
  // exactly the same way.
  final sure = await confirmDestructive(
    context,
    title: 'Delete $what?',
    message: warning,
    confirmLabel: 'Delete',
    doubleCheck: '$what will be gone forever. Delete it?',
  );
  if (!sure) return false;
  await onDelete();
  return true;
}
