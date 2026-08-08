import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The bedtime stop: narration winds down on its own so a child who has fallen
/// asleep isn't woken by the story rolling on, and one who hasn't doesn't get
/// an endless supply.
///
/// Lives in a provider rather than the reader widget because the reader is
/// replaced on every chapter change — a timer held there would die at the page
/// turn. See `docs/ui-ux.md`.
enum SleepTimerMode {
  /// No limit; chapters keep auto-advancing.
  off,

  /// Stop when the current chapter ends — no new chapter starts.
  endOfChapter,

  /// Stop when the clock runs out, wherever we are.
  countdown,
}

class SleepTimer {
  const SleepTimer({this.mode = SleepTimerMode.off, this.endsAt});

  final SleepTimerMode mode;

  /// When [mode] is [SleepTimerMode.countdown], the moment narration stops.
  final DateTime? endsAt;

  bool get isOn => mode != SleepTimerMode.off;

  /// Whether the story should stop rather than roll into another chapter.
  bool get blocksNextChapter =>
      mode == SleepTimerMode.endOfChapter ||
      (mode == SleepTimerMode.countdown && expired);

  bool get expired => endsAt != null && !DateTime.now().isBefore(endsAt!);

  Duration? get remaining {
    if (endsAt == null) return null;
    final left = endsAt!.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  /// Short label for the reader's app bar, e.g. "18m" or "chapter".
  String get label => switch (mode) {
    SleepTimerMode.off => '',
    SleepTimerMode.endOfChapter => 'chapter',
    SleepTimerMode.countdown => '${(remaining?.inMinutes ?? 0) + 1}m',
  };
}

final sleepTimerProvider = NotifierProvider<SleepTimerController, SleepTimer>(
  SleepTimerController.new,
);

class SleepTimerController extends Notifier<SleepTimer> {
  Timer? _tick;
  Timer? _deadline;

  @override
  SleepTimer build() {
    ref.onDispose(_cancel);
    return const SleepTimer();
  }

  void _cancel() {
    _tick?.cancel();
    _deadline?.cancel();
    _tick = null;
    _deadline = null;
  }

  void off() {
    _cancel();
    state = const SleepTimer();
  }

  void endOfChapter() {
    _cancel();
    state = const SleepTimer(mode: SleepTimerMode.endOfChapter);
  }

  /// Stop in [minutes]. Two timers: a coarse one to keep the countdown label
  /// fresh, and an exact one so the story stops on time rather than up to a
  /// tick late. Neither touches audio — the reader watches this and decides.
  void countdown(int minutes) {
    _cancel();
    final duration = Duration(minutes: minutes);
    state = SleepTimer(
      mode: SleepTimerMode.countdown,
      endsAt: DateTime.now().add(duration),
    );
    _tick = Timer.periodic(const Duration(seconds: 30), (_) => _reemit());
    _deadline = Timer(duration, () {
      _cancel();
      _reemit();
    });
  }

  /// Re-publish the same deadline so watchers rebuild with a fresh `remaining`.
  void _reemit() => state = SleepTimer(mode: state.mode, endsAt: state.endsAt);
}
