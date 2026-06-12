import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../quiz/quiz_screen.dart';

/// Parent-facing form to create a child account, then hand off to the quiz.
/// Reached through the parent gate. See `docs/ui-ux.md`.
class CreateProfileScreen extends ConsumerStatefulWidget {
  const CreateProfileScreen({super.key});

  @override
  ConsumerState<CreateProfileScreen> createState() =>
      _CreateProfileScreenState();
}

class _CreateProfileScreenState extends ConsumerState<CreateProfileScreen> {
  static const _palette = [
    0xFF6750A4,
    0xFF386A20,
    0xFFB3261E,
    0xFF00639B,
    0xFF7D5260,
    0xFF8C5000,
  ];

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _brief = TextEditingController();
  int _age = 5;
  int _color = _palette.first;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _brief.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final child = await ref
        .read(profileServiceProvider)
        .create(
          displayName: _name.text.trim(),
          age: _age,
          themeColor: _color,
          parentBrief: _brief.text.trim().isEmpty ? null : _brief.text.trim(),
        );
    ref.invalidate(profilesProvider);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => QuizScreen(child: child)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New storyteller')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _name,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: "Child's nickname",
                      helperText:
                          'A nickname is fine — no need for a real name.',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Please enter a name'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Age: $_age',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Slider(
                    value: _age.toDouble(),
                    min: 2,
                    max: 12,
                    divisions: 10,
                    label: '$_age',
                    onChanged: (v) => setState(() => _age = v.round()),
                  ),
                  const SizedBox(height: 16),
                  const Text('Favourite colour'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    children: [
                      for (final c in _palette)
                        GestureDetector(
                          onTap: () => setState(() => _color = c),
                          child: CircleAvatar(
                            backgroundColor: Color(c),
                            radius: 20,
                            child: _color == c
                                ? const Icon(Icons.check, color: Colors.white)
                                : null,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _brief,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: "Parent's brief (optional)",
                      helperText:
                          'Values & tone to weave in, e.g. "kindness wins, '
                          'family matters, nothing scary."',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Start the quiz'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
