import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/models/beat.dart';
import '../../domain/models/child_profile.dart';
import '../../domain/models/interest.dart';
import '../../domain/models/quiz_result.dart';
import '../../domain/models/series.dart';

part 'app_database.g.dart';

// ─── Tables ───────────────────────────────────────────────────────────
// @DataClassName keeps Drift's generated row classes from colliding with our
// hand-written pure-Dart domain models of the same name.

@DataClassName('ChildProfileRow')
class ChildProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text()();
  IntColumn get age => integer()();
  TextColumn get language => text().withDefault(const Constant('en'))();
  IntColumn get detailLevel => intEnum<DetailLevel>()();
  IntColumn get themeColor =>
      integer().withDefault(const Constant(0xFF6750A4))();
  TextColumn get parentBrief => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('QuizResultRow')
class QuizResults extends Table {
  TextColumn get id => text()();
  TextColumn get childId =>
      text().references(ChildProfiles, #id, onDelete: KeyAction.cascade)();
  IntColumn get kind => intEnum<QuizKind>()();
  TextColumn get answers => text().map(const _StringMapConverter())();
  TextColumn get seedSummary => text()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('InterestRow')
class Interests extends Table {
  TextColumn get id => text()();
  TextColumn get childId =>
      text().references(ChildProfiles, #id, onDelete: KeyAction.cascade)();
  TextColumn get label => text()();
  IntColumn get weight => integer().withDefault(const Constant(1))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  IntColumn get source => intEnum<InterestSource>()();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('LearnedProfileRow')
class LearnedProfiles extends Table {
  TextColumn get childId =>
      text().references(ChildProfiles, #id, onDelete: KeyAction.cascade)();
  TextColumn get dataJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {childId};
}

@DataClassName('WorldRow')
class Worlds extends Table {
  TextColumn get id => text()();
  TextColumn get childId =>
      text().references(ChildProfiles, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get premise => text().withDefault(const Constant(''))();
  IntColumn get theme => intEnum<StoryTheme>()();

  /// Up to two extra themes blended with [theme], as comma-separated enum names.
  TextColumn get extraThemes => text().withDefault(const Constant(''))();

  /// Cast edits (arrivals/departures) the next story must acknowledge, as JSON.
  TextColumn get castChanges => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('CharacterRow')
class StoryCharacters extends Table {
  @override
  String get tableName => 'characters';

  TextColumn get id => text()();
  TextColumn get worldId =>
      text().references(Worlds, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('SeriesRow')
class SeriesTable extends Table {
  @override
  String get tableName => 'series';

  TextColumn get id => text()();
  TextColumn get childId =>
      text().references(ChildProfiles, #id, onDelete: KeyAction.cascade)();
  TextColumn get worldId =>
      text().nullable().references(Worlds, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  IntColumn get theme => intEnum<StoryTheme>()();

  /// Up to two extra themes blended with [theme], as comma-separated enum names.
  TextColumn get extraThemes => text().withDefault(const Constant(''))();

  /// True while [title] is a placeholder awaiting a model-suggested title.
  BoolColumn get autoTitle => boolean().withDefault(const Constant(false))();
  TextColumn get customTheme => text().nullable()();
  IntColumn get heroMode => intEnum<HeroMode>()();
  TextColumn get heroName => text().nullable()();
  BoolColumn get bilingualEnabled =>
      boolean().withDefault(const Constant(false))();
  TextColumn get secondaryLanguage => text().nullable()();
  IntColumn get bilingualBlend => intEnum<BilingualBlend>().nullable()();
  TextColumn get seedSummary => text().withDefault(const Constant(''))();
  TextColumn get storyBible => text().withDefault(const Constant(''))();
  TextColumn get branchedFromBeatId => text().nullable()();
  IntColumn get status => intEnum<SeriesStatus>()();

  /// Reading position: the chapter last opened and when, so the bookshelf can
  /// offer "Continue — Chapter 4".
  IntColumn get lastReadSeq => integer().nullable()();
  DateTimeColumn get lastReadAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('BeatRow')
class Beats extends Table {
  TextColumn get id => text()();
  TextColumn get seriesId =>
      text().references(SeriesTable, #id, onDelete: KeyAction.cascade)();
  TextColumn get childId => text()();
  IntColumn get seq => integer()();
  IntColumn get intent => intEnum<StoryIntent>()();
  TextColumn get chosenTwist => text().nullable()();
  TextColumn get storyText => text()();
  TextColumn get summary => text()();
  IntColumn get rating => intEnum<AgeRating>()();
  TextColumn get setting => text().withDefault(const Constant(''))();
  TextColumn get characters => text().map(const _StringListConverter())();
  TextColumn get openThreads => text().map(const _StringListConverter())();
  TextColumn get language => text().withDefault(const Constant('en'))();
  BoolColumn get isFinal => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

// ─── Converters ───────────────────────────────────────────────────────

class _StringMapConverter extends TypeConverter<Map<String, String>, String> {
  const _StringMapConverter();

  @override
  Map<String, String> fromSql(String fromDb) {
    final decoded = jsonDecode(fromDb) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, v.toString()));
  }

  @override
  String toSql(Map<String, String> value) => jsonEncode(value);
}

class _StringListConverter extends TypeConverter<List<String>, String> {
  const _StringListConverter();

  @override
  List<String> fromSql(String fromDb) =>
      (jsonDecode(fromDb) as List<dynamic>).map((e) => e.toString()).toList();

  @override
  String toSql(List<String> value) => jsonEncode(value);
}

// ─── Database ─────────────────────────────────────────────────────────

@DriftDatabase(
  tables: [
    ChildProfiles,
    QuizResults,
    Interests,
    LearnedProfiles,
    Worlds,
    StoryCharacters,
    SeriesTable,
    Beats,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// In-memory database for tests.
  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 6;

  /// Opens the on-device database file (app documents dir). Foreign keys on.
  static AppDatabase open() {
    final executor = LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'sleepytime.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
    return AppDatabase(executor);
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      // v1 → v2: add Series + Beats (story engine).
      if (from < 2) {
        await m.createTable(seriesTable);
        await m.createTable(beats);
      }
      if (from < 3) {
        await m.addColumn(beats, beats.isFinal);
      }
      // v3 → v4: Worlds + Characters (the bookshelf), and episodes gain a
      // nullable worldId (existing stories stay standalone with worldId = null).
      if (from < 4) {
        await m.createTable(worlds);
        await m.createTable(storyCharacters);
        await m.addColumn(seriesTable, seriesTable.worldId);
      }
      // v4 → v5: multi-theme stories, model-suggested titles, and pending cast
      // changes on a world (so a removed character gets written out).
      if (from < 5) {
        await m.addColumn(seriesTable, seriesTable.extraThemes);
        await m.addColumn(seriesTable, seriesTable.autoTitle);
        await m.addColumn(worlds, worlds.extraThemes);
        await m.addColumn(worlds, worlds.castChanges);
      }
      // v5 → v6: reading position, so a part-heard story can be resumed.
      // Existing stories start with no position (null = never opened).
      if (from < 6) {
        await m.addColumn(seriesTable, seriesTable.lastReadSeq);
        await m.addColumn(seriesTable, seriesTable.lastReadAt);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
