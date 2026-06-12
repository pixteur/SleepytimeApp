import '../adapters/storage/storage_repo.dart';
import 'models/beat.dart';

/// The rolling context assembled for a story turn.
class StoryContext {
  const StoryContext({required this.recentBeats, required this.nextSeq});

  /// The last few beats, oldest→newest, for immediate continuity.
  final List<Beat> recentBeats;

  /// The `seq` the next beat should use.
  final int nextSeq;
}

/// Reads/writes beats and assembles the per-series context window for
/// "continue where we left off". See `docs/data-model.md`.
class BeatStore {
  BeatStore(this._repo, {this.recentWindow = 3});

  final StorageRepo _repo;

  /// How many recent beats to include verbatim.
  final int recentWindow;

  Future<StoryContext> recentContext(String seriesId) async {
    final all = await _repo.loadBeats(seriesId); // ordered by seq asc
    final recent = all.length <= recentWindow
        ? all
        : all.sublist(all.length - recentWindow);
    final nextSeq = all.isEmpty ? 0 : all.last.seq + 1;
    return StoryContext(recentBeats: recent, nextSeq: nextSeq);
  }

  Future<List<Beat>> all(String seriesId) => _repo.loadBeats(seriesId);

  Future<void> append(Beat beat) => _repo.saveBeat(beat);
}
