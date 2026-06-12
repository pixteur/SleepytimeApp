import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/models/child_profile.dart';
import '../../domain/models/interest.dart';
import '../../domain/models/quiz_result.dart';

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

// ─── Database ─────────────────────────────────────────────────────────

@DriftDatabase(tables: [ChildProfiles, QuizResults, Interests, LearnedProfiles])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// In-memory database for tests.
  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

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
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
