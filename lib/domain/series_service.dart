import 'package:uuid/uuid.dart';

import '../adapters/storage/storage_repo.dart';
import 'models/series.dart';

/// Manages a child's storylines: list (the library), create (with theme + hero),
/// archive, and branch (a new series, optionally forked from a beat).
/// See `docs/architecture.md`, `docs/data-model.md`.
class SeriesService {
  SeriesService(this._repo, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final StorageRepo _repo;
  final Uuid _uuid;

  /// Active series for a child (the library), newest first.
  Future<List<Series>> forChild(String childId) async {
    final all = await _repo.loadSeries(childId);
    return all.where((s) => s.status == SeriesStatus.active).toList();
  }

  Future<List<Series>> archived(String childId) async {
    final all = await _repo.loadSeries(childId);
    return all.where((s) => s.status == SeriesStatus.archived).toList();
  }

  Future<Series> create({
    required String childId,
    required String title,
    required StoryTheme theme,
    List<StoryTheme> extraThemes = const [],
    bool autoTitle = false,
    String? worldId,
    String? customTheme,
    HeroMode heroMode = HeroMode.surprise,
    String? heroName,
    String seedSummary = '',
    bool bilingualEnabled = false,
    String? secondaryLanguage,
    BilingualBlend? bilingualBlend,
    String? branchedFromBeatId,
  }) async {
    final series = Series(
      id: _uuid.v4(),
      childId: childId,
      title: title,
      theme: theme,
      extraThemes: extraThemes,
      autoTitle: autoTitle,
      worldId: worldId,
      customTheme: customTheme,
      heroMode: heroMode,
      heroName: heroName,
      seedSummary: seedSummary,
      bilingualEnabled: bilingualEnabled,
      secondaryLanguage: secondaryLanguage,
      bilingualBlend: bilingualBlend,
      branchedFromBeatId: branchedFromBeatId,
    );
    await _repo.saveSeries(series);
    return series;
  }

  Future<void> archive(Series series) =>
      _repo.saveSeries(series.copyWith(status: SeriesStatus.archived));

  /// Remember where the child got to. Called when a chapter is opened, so the
  /// bookshelf can offer to pick the story back up. Reading an earlier chapter
  /// again doesn't rewind the mark — the furthest point reached is the useful
  /// one to resume from.
  Future<Series> markRead(Series series, int seq) async {
    final furthest = seq > (series.lastReadSeq ?? -1)
        ? seq
        : series.lastReadSeq!;
    final updated = series.copyWith(
      lastReadSeq: furthest,
      lastReadAt: DateTime.now(),
    );
    await _repo.saveSeries(updated);
    return updated;
  }

  /// Permanently delete a series and its chapters (FK cascade).
  Future<void> delete(String id) => _repo.deleteSeries(id);

  /// Branch a new series from an existing one, optionally forking from a beat.
  Future<Series> branch({
    required Series from,
    required String title,
    String? fromBeatId,
  }) {
    return create(
      childId: from.childId,
      title: title,
      theme: from.theme,
      extraThemes: from.extraThemes,
      customTheme: from.customTheme,
      heroMode: from.heroMode,
      heroName: from.heroName,
      seedSummary: from.seedSummary,
      bilingualEnabled: from.bilingualEnabled,
      secondaryLanguage: from.secondaryLanguage,
      bilingualBlend: from.bilingualBlend,
      branchedFromBeatId: fromBeatId,
    );
  }
}
