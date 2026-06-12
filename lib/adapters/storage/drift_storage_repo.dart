import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/models/child_profile.dart';
import '../../domain/models/interest.dart';
import '../../domain/models/learned_profile.dart';
import '../../domain/models/quiz_result.dart';
import 'app_database.dart';
import 'storage_repo.dart';

/// Drift-backed implementation of [StorageRepo]. All row↔domain mapping lives
/// here so the rest of the app stays free of Drift types. See `docs/data-model.md`.
class DriftStorageRepo implements StorageRepo {
  DriftStorageRepo(this._db);

  final AppDatabase _db;

  // ── Child profiles ──────────────────────────────────────────────
  @override
  Future<List<ChildProfile>> loadProfiles() async {
    final rows = await _db.select(_db.childProfiles).get();
    return rows.map(_toProfile).toList();
  }

  @override
  Future<ChildProfile?> loadProfile(String id) async {
    final row = await (_db.select(
      _db.childProfiles,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toProfile(row);
  }

  @override
  Future<void> saveProfile(ChildProfile profile) async {
    await _db
        .into(_db.childProfiles)
        .insertOnConflictUpdate(
          ChildProfilesCompanion.insert(
            id: profile.id,
            displayName: profile.displayName,
            age: profile.age,
            detailLevel: profile.detailLevel,
            language: Value(profile.language),
            themeColor: Value(profile.themeColor),
            parentBrief: Value(profile.parentBrief),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  @override
  Future<void> deleteProfile(String id) async {
    await (_db.delete(_db.childProfiles)..where((t) => t.id.equals(id))).go();
  }

  ChildProfile _toProfile(ChildProfileRow r) => ChildProfile(
    id: r.id,
    displayName: r.displayName,
    age: r.age,
    language: r.language,
    detailLevel: r.detailLevel,
    themeColor: r.themeColor,
    parentBrief: r.parentBrief,
  );

  // ── Quiz results ────────────────────────────────────────────────
  @override
  Future<void> saveQuizResult(QuizResult result) async {
    await _db
        .into(_db.quizResults)
        .insertOnConflictUpdate(
          QuizResultsCompanion.insert(
            id: result.id,
            childId: result.childId,
            kind: result.kind,
            answers: result.answers,
            seedSummary: result.seedSummary,
            version: Value(result.version),
          ),
        );
  }

  @override
  Future<QuizResult?> latestQuizResult(String childId) async {
    final row =
        await (_db.select(_db.quizResults)
              ..where((t) => t.childId.equals(childId))
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return null;
    return QuizResult(
      id: row.id,
      childId: row.childId,
      kind: row.kind,
      answers: row.answers,
      seedSummary: row.seedSummary,
      version: row.version,
    );
  }

  // ── Interests ───────────────────────────────────────────────────
  @override
  Future<List<Interest>> loadInterests(String childId) async {
    final rows = await (_db.select(
      _db.interests,
    )..where((t) => t.childId.equals(childId))).get();
    return rows
        .map(
          (r) => Interest(
            id: r.id,
            childId: r.childId,
            label: r.label,
            weight: r.weight,
            active: r.active,
            source: r.source,
          ),
        )
        .toList();
  }

  @override
  Future<void> saveInterest(Interest interest) async {
    await _db
        .into(_db.interests)
        .insertOnConflictUpdate(
          InterestsCompanion.insert(
            id: interest.id,
            childId: interest.childId,
            label: interest.label,
            source: interest.source,
            weight: Value(interest.weight),
            active: Value(interest.active),
          ),
        );
  }

  @override
  Future<void> deleteInterest(String id) async {
    await (_db.delete(_db.interests)..where((t) => t.id.equals(id))).go();
  }

  // ── Learned profile ─────────────────────────────────────────────
  @override
  Future<LearnedProfile?> loadLearnedProfile(String childId) async {
    final row = await (_db.select(
      _db.learnedProfiles,
    )..where((t) => t.childId.equals(childId))).getSingleOrNull();
    if (row == null) return null;
    return _toLearned(childId, row.dataJson);
  }

  @override
  Future<void> saveLearnedProfile(LearnedProfile profile) async {
    await _db
        .into(_db.learnedProfiles)
        .insertOnConflictUpdate(
          LearnedProfilesCompanion.insert(
            childId: profile.childId,
            dataJson: Value(_learnedJson(profile)),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  LearnedProfile _toLearned(String childId, String dataJson) {
    final m = jsonDecode(dataJson) as Map<String, dynamic>;
    return LearnedProfile(
      childId: childId,
      twistAffinity:
          (m['twistAffinity'] as Map?)?.map(
            (k, v) => MapEntry(k as String, (v as num).toInt()),
          ) ??
          const {},
      favorites: (m['favorites'] as List?)?.cast<String>() ?? const [],
      inferredInterests:
          (m['inferredInterests'] as List?)?.cast<String>() ?? const [],
      observedTone: m['observedTone'] as String? ?? '',
    );
  }

  String _learnedJson(LearnedProfile p) => jsonEncode({
    'twistAffinity': p.twistAffinity,
    'favorites': p.favorites,
    'inferredInterests': p.inferredInterests,
    'observedTone': p.observedTone,
  });
}
