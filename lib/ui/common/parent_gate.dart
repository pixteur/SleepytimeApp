import 'dart:math';

import 'package:flutter/material.dart';

/// A lightweight "grown-ups only" gate — a simple arithmetic question kids
/// can't easily answer. Not security; just a speed bump in front of
/// profile/admin/settings actions. See `docs/ui-ux.md`.
Future<bool> showParentGate(BuildContext context) async {
  final rng = Random();
  final a = rng.nextInt(8) + 2; // 2..9
  final b = rng.nextInt(8) + 2;
  final controller = TextEditingController();

  final ok = await showDialog<bool>(
    context: context,
    builder: (context) {
      String? error;
      return StatefulBuilder(
        builder: (context, setState) {
          void submit() {
            if (controller.text.trim() == '${a + b}') {
              Navigator.pop(context, true);
            } else {
              setState(() => error = 'Not quite — ask a grown-up.');
            }
          }

          return AlertDialog(
            title: const Text('Grown-ups only 🔒'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ask a grown-up to help continue.'),
                const SizedBox(height: 16),
                Text(
                  'What is $a + $b?',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: InputDecoration(errorText: error),
                  onSubmitted: (_) => submit(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(onPressed: submit, child: const Text('Continue')),
            ],
          );
        },
      );
    },
  );
  return ok ?? false;
}
