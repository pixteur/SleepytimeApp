import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../domain/models/child_profile.dart';
import '../../domain/models/quiz_question.dart';
import '../../domain/quiz_service.dart';
import '../home/home_screen.dart';

/// One-question-at-a-time onboarding quiz. Collects answers, then submits to
/// [QuizService] (which derives the seed + seeds interests) and updates the
/// child's detail level. See `build-plan/phase-1-profiles-quiz.md`.
class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key, required this.child});

  final ChildProfile child;

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  static const _questions = QuizService.fullQuiz;

  final _answers = <String, String>{};
  final _textController = TextEditingController();
  int _index = 0;
  bool _submitting = false;

  QuizQuestion get _q => _questions[_index];
  bool get _isLast => _index == _questions.length - 1;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _captureText() {
    if (_q.type == QuizAnswerType.freeText) {
      final t = _textController.text.trim();
      if (t.isEmpty) {
        _answers.remove(_q.id);
      } else {
        _answers[_q.id] = t;
      }
    }
  }

  void _goTo(int index) {
    setState(() {
      _index = index;
      _textController.text = _answers[_questions[index].id] ?? '';
    });
  }

  void _choose(String value) {
    _answers[_q.id] = value;
    if (_isLast) {
      _finish();
    } else {
      _goTo(_index + 1);
    }
  }

  void _next() {
    _captureText();
    if (_isLast) {
      _finish();
    } else {
      _goTo(_index + 1);
    }
  }

  void _back() {
    _captureText();
    if (_index == 0) {
      Navigator.pop(context);
    } else {
      _goTo(_index - 1);
    }
  }

  Future<void> _finish() async {
    setState(() => _submitting = true);
    final outcome = await ref
        .read(quizServiceProvider)
        .submit(
          childId: widget.child.id,
          answers: _answers,
          parentBrief: widget.child.parentBrief,
        );
    final updated = widget.child.copyWith(detailLevel: outcome.detailLevel);
    await ref.read(profileServiceProvider).update(updated);
    ref.read(activeChildProvider.notifier).select(updated);
    ref.invalidate(profilesProvider);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Getting to know ${widget.child.displayName}'),
        leading: BackButton(onPressed: _submitting ? null : _back),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinearProgressIndicator(
                  value: (_index + 1) / _questions.length,
                ),
                const SizedBox(height: 8),
                Text(
                  'Question ${_index + 1} of ${_questions.length}',
                  style: theme.textTheme.labelMedium,
                ),
                const SizedBox(height: 24),
                Text(_q.prompt, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 24),
                Expanded(child: SingleChildScrollView(child: _answerArea())),
                if (_submitting)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _answerArea() {
    if (_q.type == QuizAnswerType.choice) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final option in _q.options)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FilledButton.tonal(
                onPressed: _submitting ? null : () => _choose(option),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                child: Text(option),
              ),
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _textController,
          autofocus: true,
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Type an answer… (you can skip this one)',
          ),
          onSubmitted: (_) => _next(),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _submitting
                  ? null
                  : () {
                      _answers.remove(_q.id);
                      _textController.clear();
                      _next();
                    },
              child: const Text('Skip'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _submitting ? null : _next,
              child: Text(_isLast ? 'Finish' : 'Next'),
            ),
          ],
        ),
      ],
    );
  }
}
