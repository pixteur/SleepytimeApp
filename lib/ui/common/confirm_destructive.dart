import 'package:flutter/material.dart';

import 'parent_gate.dart';

/// A three-step guard in front of anything that can't be undone: the parent
/// gate, a dialog explaining exactly what will be lost, and a final
/// double-check. Kids tap fast — nothing should vanish on one tap.
///
/// Returns true only if a grown-up got all the way through. See `docs/ui-ux.md`.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,

  /// The second-pass question, e.g. "Really delete Splat the Cat?".
  required String doubleCheck,
}) async {
  if (!await showParentGate(context) || !context.mounted) return false;

  final first = await _ask(
    context,
    title: title,
    message: message,
    confirmLabel: confirmLabel,
  );
  if (first != true || !context.mounted) return false;

  final second = await _ask(
    context,
    title: 'Are you sure?',
    message: doubleCheck,
    confirmLabel: 'Yes, I\'m sure',
  );
  return second == true;
}

Future<bool?> _ask(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) {
  final scheme = Theme.of(context).colorScheme;
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Keep it'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}
