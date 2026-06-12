// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ChildProfilesTable extends ChildProfiles
    with TableInfo<$ChildProfilesTable, ChildProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChildProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ageMeta = const VerificationMeta('age');
  @override
  late final GeneratedColumn<int> age = GeneratedColumn<int>(
    'age',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('en'),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DetailLevel, int> detailLevel =
      GeneratedColumn<int>(
        'detail_level',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DetailLevel>($ChildProfilesTable.$converterdetailLevel);
  static const VerificationMeta _themeColorMeta = const VerificationMeta(
    'themeColor',
  );
  @override
  late final GeneratedColumn<int> themeColor = GeneratedColumn<int>(
    'theme_color',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0xFF6750A4),
  );
  static const VerificationMeta _parentBriefMeta = const VerificationMeta(
    'parentBrief',
  );
  @override
  late final GeneratedColumn<String> parentBrief = GeneratedColumn<String>(
    'parent_brief',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    displayName,
    age,
    language,
    detailLevel,
    themeColor,
    parentBrief,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'child_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChildProfileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('age')) {
      context.handle(
        _ageMeta,
        age.isAcceptableOrUnknown(data['age']!, _ageMeta),
      );
    } else if (isInserting) {
      context.missing(_ageMeta);
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    }
    if (data.containsKey('theme_color')) {
      context.handle(
        _themeColorMeta,
        themeColor.isAcceptableOrUnknown(data['theme_color']!, _themeColorMeta),
      );
    }
    if (data.containsKey('parent_brief')) {
      context.handle(
        _parentBriefMeta,
        parentBrief.isAcceptableOrUnknown(
          data['parent_brief']!,
          _parentBriefMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChildProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChildProfileRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      age: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}age'],
      )!,
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      )!,
      detailLevel: $ChildProfilesTable.$converterdetailLevel.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}detail_level'],
        )!,
      ),
      themeColor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}theme_color'],
      )!,
      parentBrief: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_brief'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ChildProfilesTable createAlias(String alias) {
    return $ChildProfilesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<DetailLevel, int, int> $converterdetailLevel =
      const EnumIndexConverter<DetailLevel>(DetailLevel.values);
}

class ChildProfileRow extends DataClass implements Insertable<ChildProfileRow> {
  final String id;
  final String displayName;
  final int age;
  final String language;
  final DetailLevel detailLevel;
  final int themeColor;
  final String? parentBrief;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ChildProfileRow({
    required this.id,
    required this.displayName,
    required this.age,
    required this.language,
    required this.detailLevel,
    required this.themeColor,
    this.parentBrief,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['display_name'] = Variable<String>(displayName);
    map['age'] = Variable<int>(age);
    map['language'] = Variable<String>(language);
    {
      map['detail_level'] = Variable<int>(
        $ChildProfilesTable.$converterdetailLevel.toSql(detailLevel),
      );
    }
    map['theme_color'] = Variable<int>(themeColor);
    if (!nullToAbsent || parentBrief != null) {
      map['parent_brief'] = Variable<String>(parentBrief);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ChildProfilesCompanion toCompanion(bool nullToAbsent) {
    return ChildProfilesCompanion(
      id: Value(id),
      displayName: Value(displayName),
      age: Value(age),
      language: Value(language),
      detailLevel: Value(detailLevel),
      themeColor: Value(themeColor),
      parentBrief: parentBrief == null && nullToAbsent
          ? const Value.absent()
          : Value(parentBrief),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ChildProfileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChildProfileRow(
      id: serializer.fromJson<String>(json['id']),
      displayName: serializer.fromJson<String>(json['displayName']),
      age: serializer.fromJson<int>(json['age']),
      language: serializer.fromJson<String>(json['language']),
      detailLevel: $ChildProfilesTable.$converterdetailLevel.fromJson(
        serializer.fromJson<int>(json['detailLevel']),
      ),
      themeColor: serializer.fromJson<int>(json['themeColor']),
      parentBrief: serializer.fromJson<String?>(json['parentBrief']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'displayName': serializer.toJson<String>(displayName),
      'age': serializer.toJson<int>(age),
      'language': serializer.toJson<String>(language),
      'detailLevel': serializer.toJson<int>(
        $ChildProfilesTable.$converterdetailLevel.toJson(detailLevel),
      ),
      'themeColor': serializer.toJson<int>(themeColor),
      'parentBrief': serializer.toJson<String?>(parentBrief),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ChildProfileRow copyWith({
    String? id,
    String? displayName,
    int? age,
    String? language,
    DetailLevel? detailLevel,
    int? themeColor,
    Value<String?> parentBrief = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ChildProfileRow(
    id: id ?? this.id,
    displayName: displayName ?? this.displayName,
    age: age ?? this.age,
    language: language ?? this.language,
    detailLevel: detailLevel ?? this.detailLevel,
    themeColor: themeColor ?? this.themeColor,
    parentBrief: parentBrief.present ? parentBrief.value : this.parentBrief,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ChildProfileRow copyWithCompanion(ChildProfilesCompanion data) {
    return ChildProfileRow(
      id: data.id.present ? data.id.value : this.id,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      age: data.age.present ? data.age.value : this.age,
      language: data.language.present ? data.language.value : this.language,
      detailLevel: data.detailLevel.present
          ? data.detailLevel.value
          : this.detailLevel,
      themeColor: data.themeColor.present
          ? data.themeColor.value
          : this.themeColor,
      parentBrief: data.parentBrief.present
          ? data.parentBrief.value
          : this.parentBrief,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChildProfileRow(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('age: $age, ')
          ..write('language: $language, ')
          ..write('detailLevel: $detailLevel, ')
          ..write('themeColor: $themeColor, ')
          ..write('parentBrief: $parentBrief, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    displayName,
    age,
    language,
    detailLevel,
    themeColor,
    parentBrief,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChildProfileRow &&
          other.id == this.id &&
          other.displayName == this.displayName &&
          other.age == this.age &&
          other.language == this.language &&
          other.detailLevel == this.detailLevel &&
          other.themeColor == this.themeColor &&
          other.parentBrief == this.parentBrief &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ChildProfilesCompanion extends UpdateCompanion<ChildProfileRow> {
  final Value<String> id;
  final Value<String> displayName;
  final Value<int> age;
  final Value<String> language;
  final Value<DetailLevel> detailLevel;
  final Value<int> themeColor;
  final Value<String?> parentBrief;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ChildProfilesCompanion({
    this.id = const Value.absent(),
    this.displayName = const Value.absent(),
    this.age = const Value.absent(),
    this.language = const Value.absent(),
    this.detailLevel = const Value.absent(),
    this.themeColor = const Value.absent(),
    this.parentBrief = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChildProfilesCompanion.insert({
    required String id,
    required String displayName,
    required int age,
    this.language = const Value.absent(),
    required DetailLevel detailLevel,
    this.themeColor = const Value.absent(),
    this.parentBrief = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       displayName = Value(displayName),
       age = Value(age),
       detailLevel = Value(detailLevel);
  static Insertable<ChildProfileRow> custom({
    Expression<String>? id,
    Expression<String>? displayName,
    Expression<int>? age,
    Expression<String>? language,
    Expression<int>? detailLevel,
    Expression<int>? themeColor,
    Expression<String>? parentBrief,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (displayName != null) 'display_name': displayName,
      if (age != null) 'age': age,
      if (language != null) 'language': language,
      if (detailLevel != null) 'detail_level': detailLevel,
      if (themeColor != null) 'theme_color': themeColor,
      if (parentBrief != null) 'parent_brief': parentBrief,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChildProfilesCompanion copyWith({
    Value<String>? id,
    Value<String>? displayName,
    Value<int>? age,
    Value<String>? language,
    Value<DetailLevel>? detailLevel,
    Value<int>? themeColor,
    Value<String?>? parentBrief,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ChildProfilesCompanion(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      age: age ?? this.age,
      language: language ?? this.language,
      detailLevel: detailLevel ?? this.detailLevel,
      themeColor: themeColor ?? this.themeColor,
      parentBrief: parentBrief ?? this.parentBrief,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (age.present) {
      map['age'] = Variable<int>(age.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (detailLevel.present) {
      map['detail_level'] = Variable<int>(
        $ChildProfilesTable.$converterdetailLevel.toSql(detailLevel.value),
      );
    }
    if (themeColor.present) {
      map['theme_color'] = Variable<int>(themeColor.value);
    }
    if (parentBrief.present) {
      map['parent_brief'] = Variable<String>(parentBrief.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChildProfilesCompanion(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('age: $age, ')
          ..write('language: $language, ')
          ..write('detailLevel: $detailLevel, ')
          ..write('themeColor: $themeColor, ')
          ..write('parentBrief: $parentBrief, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $QuizResultsTable extends QuizResults
    with TableInfo<$QuizResultsTable, QuizResultRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QuizResultsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _childIdMeta = const VerificationMeta(
    'childId',
  );
  @override
  late final GeneratedColumn<String> childId = GeneratedColumn<String>(
    'child_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES child_profiles (id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<QuizKind, int> kind =
      GeneratedColumn<int>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<QuizKind>($QuizResultsTable.$converterkind);
  @override
  late final GeneratedColumnWithTypeConverter<Map<String, String>, String>
  answers = GeneratedColumn<String>(
    'answers',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<Map<String, String>>($QuizResultsTable.$converteranswers);
  static const VerificationMeta _seedSummaryMeta = const VerificationMeta(
    'seedSummary',
  );
  @override
  late final GeneratedColumn<String> seedSummary = GeneratedColumn<String>(
    'seed_summary',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    childId,
    kind,
    answers,
    seedSummary,
    version,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'quiz_results';
  @override
  VerificationContext validateIntegrity(
    Insertable<QuizResultRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('child_id')) {
      context.handle(
        _childIdMeta,
        childId.isAcceptableOrUnknown(data['child_id']!, _childIdMeta),
      );
    } else if (isInserting) {
      context.missing(_childIdMeta);
    }
    if (data.containsKey('seed_summary')) {
      context.handle(
        _seedSummaryMeta,
        seedSummary.isAcceptableOrUnknown(
          data['seed_summary']!,
          _seedSummaryMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_seedSummaryMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  QuizResultRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QuizResultRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      childId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}child_id'],
      )!,
      kind: $QuizResultsTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}kind'],
        )!,
      ),
      answers: $QuizResultsTable.$converteranswers.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}answers'],
        )!,
      ),
      seedSummary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}seed_summary'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $QuizResultsTable createAlias(String alias) {
    return $QuizResultsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<QuizKind, int, int> $converterkind =
      const EnumIndexConverter<QuizKind>(QuizKind.values);
  static TypeConverter<Map<String, String>, String> $converteranswers =
      const _StringMapConverter();
}

class QuizResultRow extends DataClass implements Insertable<QuizResultRow> {
  final String id;
  final String childId;
  final QuizKind kind;
  final Map<String, String> answers;
  final String seedSummary;
  final int version;
  final DateTime createdAt;
  const QuizResultRow({
    required this.id,
    required this.childId,
    required this.kind,
    required this.answers,
    required this.seedSummary,
    required this.version,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['child_id'] = Variable<String>(childId);
    {
      map['kind'] = Variable<int>($QuizResultsTable.$converterkind.toSql(kind));
    }
    {
      map['answers'] = Variable<String>(
        $QuizResultsTable.$converteranswers.toSql(answers),
      );
    }
    map['seed_summary'] = Variable<String>(seedSummary);
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  QuizResultsCompanion toCompanion(bool nullToAbsent) {
    return QuizResultsCompanion(
      id: Value(id),
      childId: Value(childId),
      kind: Value(kind),
      answers: Value(answers),
      seedSummary: Value(seedSummary),
      version: Value(version),
      createdAt: Value(createdAt),
    );
  }

  factory QuizResultRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QuizResultRow(
      id: serializer.fromJson<String>(json['id']),
      childId: serializer.fromJson<String>(json['childId']),
      kind: $QuizResultsTable.$converterkind.fromJson(
        serializer.fromJson<int>(json['kind']),
      ),
      answers: serializer.fromJson<Map<String, String>>(json['answers']),
      seedSummary: serializer.fromJson<String>(json['seedSummary']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'childId': serializer.toJson<String>(childId),
      'kind': serializer.toJson<int>(
        $QuizResultsTable.$converterkind.toJson(kind),
      ),
      'answers': serializer.toJson<Map<String, String>>(answers),
      'seedSummary': serializer.toJson<String>(seedSummary),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  QuizResultRow copyWith({
    String? id,
    String? childId,
    QuizKind? kind,
    Map<String, String>? answers,
    String? seedSummary,
    int? version,
    DateTime? createdAt,
  }) => QuizResultRow(
    id: id ?? this.id,
    childId: childId ?? this.childId,
    kind: kind ?? this.kind,
    answers: answers ?? this.answers,
    seedSummary: seedSummary ?? this.seedSummary,
    version: version ?? this.version,
    createdAt: createdAt ?? this.createdAt,
  );
  QuizResultRow copyWithCompanion(QuizResultsCompanion data) {
    return QuizResultRow(
      id: data.id.present ? data.id.value : this.id,
      childId: data.childId.present ? data.childId.value : this.childId,
      kind: data.kind.present ? data.kind.value : this.kind,
      answers: data.answers.present ? data.answers.value : this.answers,
      seedSummary: data.seedSummary.present
          ? data.seedSummary.value
          : this.seedSummary,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QuizResultRow(')
          ..write('id: $id, ')
          ..write('childId: $childId, ')
          ..write('kind: $kind, ')
          ..write('answers: $answers, ')
          ..write('seedSummary: $seedSummary, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, childId, kind, answers, seedSummary, version, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuizResultRow &&
          other.id == this.id &&
          other.childId == this.childId &&
          other.kind == this.kind &&
          other.answers == this.answers &&
          other.seedSummary == this.seedSummary &&
          other.version == this.version &&
          other.createdAt == this.createdAt);
}

class QuizResultsCompanion extends UpdateCompanion<QuizResultRow> {
  final Value<String> id;
  final Value<String> childId;
  final Value<QuizKind> kind;
  final Value<Map<String, String>> answers;
  final Value<String> seedSummary;
  final Value<int> version;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const QuizResultsCompanion({
    this.id = const Value.absent(),
    this.childId = const Value.absent(),
    this.kind = const Value.absent(),
    this.answers = const Value.absent(),
    this.seedSummary = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  QuizResultsCompanion.insert({
    required String id,
    required String childId,
    required QuizKind kind,
    required Map<String, String> answers,
    required String seedSummary,
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       childId = Value(childId),
       kind = Value(kind),
       answers = Value(answers),
       seedSummary = Value(seedSummary);
  static Insertable<QuizResultRow> custom({
    Expression<String>? id,
    Expression<String>? childId,
    Expression<int>? kind,
    Expression<String>? answers,
    Expression<String>? seedSummary,
    Expression<int>? version,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (childId != null) 'child_id': childId,
      if (kind != null) 'kind': kind,
      if (answers != null) 'answers': answers,
      if (seedSummary != null) 'seed_summary': seedSummary,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  QuizResultsCompanion copyWith({
    Value<String>? id,
    Value<String>? childId,
    Value<QuizKind>? kind,
    Value<Map<String, String>>? answers,
    Value<String>? seedSummary,
    Value<int>? version,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return QuizResultsCompanion(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      kind: kind ?? this.kind,
      answers: answers ?? this.answers,
      seedSummary: seedSummary ?? this.seedSummary,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (childId.present) {
      map['child_id'] = Variable<String>(childId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<int>(
        $QuizResultsTable.$converterkind.toSql(kind.value),
      );
    }
    if (answers.present) {
      map['answers'] = Variable<String>(
        $QuizResultsTable.$converteranswers.toSql(answers.value),
      );
    }
    if (seedSummary.present) {
      map['seed_summary'] = Variable<String>(seedSummary.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QuizResultsCompanion(')
          ..write('id: $id, ')
          ..write('childId: $childId, ')
          ..write('kind: $kind, ')
          ..write('answers: $answers, ')
          ..write('seedSummary: $seedSummary, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InterestsTable extends Interests
    with TableInfo<$InterestsTable, InterestRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InterestsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _childIdMeta = const VerificationMeta(
    'childId',
  );
  @override
  late final GeneratedColumn<String> childId = GeneratedColumn<String>(
    'child_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES child_profiles (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weightMeta = const VerificationMeta('weight');
  @override
  late final GeneratedColumn<int> weight = GeneratedColumn<int>(
    'weight',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  late final GeneratedColumnWithTypeConverter<InterestSource, int> source =
      GeneratedColumn<int>(
        'source',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<InterestSource>($InterestsTable.$convertersource);
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    childId,
    label,
    weight,
    active,
    source,
    addedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'interests';
  @override
  VerificationContext validateIntegrity(
    Insertable<InterestRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('child_id')) {
      context.handle(
        _childIdMeta,
        childId.isAcceptableOrUnknown(data['child_id']!, _childIdMeta),
      );
    } else if (isInserting) {
      context.missing(_childIdMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('weight')) {
      context.handle(
        _weightMeta,
        weight.isAcceptableOrUnknown(data['weight']!, _weightMeta),
      );
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InterestRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InterestRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      childId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}child_id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      weight: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}weight'],
      )!,
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}active'],
      )!,
      source: $InterestsTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}source'],
        )!,
      ),
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $InterestsTable createAlias(String alias) {
    return $InterestsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<InterestSource, int, int> $convertersource =
      const EnumIndexConverter<InterestSource>(InterestSource.values);
}

class InterestRow extends DataClass implements Insertable<InterestRow> {
  final String id;
  final String childId;
  final String label;
  final int weight;
  final bool active;
  final InterestSource source;
  final DateTime addedAt;
  const InterestRow({
    required this.id,
    required this.childId,
    required this.label,
    required this.weight,
    required this.active,
    required this.source,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['child_id'] = Variable<String>(childId);
    map['label'] = Variable<String>(label);
    map['weight'] = Variable<int>(weight);
    map['active'] = Variable<bool>(active);
    {
      map['source'] = Variable<int>(
        $InterestsTable.$convertersource.toSql(source),
      );
    }
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  InterestsCompanion toCompanion(bool nullToAbsent) {
    return InterestsCompanion(
      id: Value(id),
      childId: Value(childId),
      label: Value(label),
      weight: Value(weight),
      active: Value(active),
      source: Value(source),
      addedAt: Value(addedAt),
    );
  }

  factory InterestRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InterestRow(
      id: serializer.fromJson<String>(json['id']),
      childId: serializer.fromJson<String>(json['childId']),
      label: serializer.fromJson<String>(json['label']),
      weight: serializer.fromJson<int>(json['weight']),
      active: serializer.fromJson<bool>(json['active']),
      source: $InterestsTable.$convertersource.fromJson(
        serializer.fromJson<int>(json['source']),
      ),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'childId': serializer.toJson<String>(childId),
      'label': serializer.toJson<String>(label),
      'weight': serializer.toJson<int>(weight),
      'active': serializer.toJson<bool>(active),
      'source': serializer.toJson<int>(
        $InterestsTable.$convertersource.toJson(source),
      ),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  InterestRow copyWith({
    String? id,
    String? childId,
    String? label,
    int? weight,
    bool? active,
    InterestSource? source,
    DateTime? addedAt,
  }) => InterestRow(
    id: id ?? this.id,
    childId: childId ?? this.childId,
    label: label ?? this.label,
    weight: weight ?? this.weight,
    active: active ?? this.active,
    source: source ?? this.source,
    addedAt: addedAt ?? this.addedAt,
  );
  InterestRow copyWithCompanion(InterestsCompanion data) {
    return InterestRow(
      id: data.id.present ? data.id.value : this.id,
      childId: data.childId.present ? data.childId.value : this.childId,
      label: data.label.present ? data.label.value : this.label,
      weight: data.weight.present ? data.weight.value : this.weight,
      active: data.active.present ? data.active.value : this.active,
      source: data.source.present ? data.source.value : this.source,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InterestRow(')
          ..write('id: $id, ')
          ..write('childId: $childId, ')
          ..write('label: $label, ')
          ..write('weight: $weight, ')
          ..write('active: $active, ')
          ..write('source: $source, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, childId, label, weight, active, source, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InterestRow &&
          other.id == this.id &&
          other.childId == this.childId &&
          other.label == this.label &&
          other.weight == this.weight &&
          other.active == this.active &&
          other.source == this.source &&
          other.addedAt == this.addedAt);
}

class InterestsCompanion extends UpdateCompanion<InterestRow> {
  final Value<String> id;
  final Value<String> childId;
  final Value<String> label;
  final Value<int> weight;
  final Value<bool> active;
  final Value<InterestSource> source;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const InterestsCompanion({
    this.id = const Value.absent(),
    this.childId = const Value.absent(),
    this.label = const Value.absent(),
    this.weight = const Value.absent(),
    this.active = const Value.absent(),
    this.source = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InterestsCompanion.insert({
    required String id,
    required String childId,
    required String label,
    this.weight = const Value.absent(),
    this.active = const Value.absent(),
    required InterestSource source,
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       childId = Value(childId),
       label = Value(label),
       source = Value(source);
  static Insertable<InterestRow> custom({
    Expression<String>? id,
    Expression<String>? childId,
    Expression<String>? label,
    Expression<int>? weight,
    Expression<bool>? active,
    Expression<int>? source,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (childId != null) 'child_id': childId,
      if (label != null) 'label': label,
      if (weight != null) 'weight': weight,
      if (active != null) 'active': active,
      if (source != null) 'source': source,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InterestsCompanion copyWith({
    Value<String>? id,
    Value<String>? childId,
    Value<String>? label,
    Value<int>? weight,
    Value<bool>? active,
    Value<InterestSource>? source,
    Value<DateTime>? addedAt,
    Value<int>? rowid,
  }) {
    return InterestsCompanion(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      label: label ?? this.label,
      weight: weight ?? this.weight,
      active: active ?? this.active,
      source: source ?? this.source,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (childId.present) {
      map['child_id'] = Variable<String>(childId.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (weight.present) {
      map['weight'] = Variable<int>(weight.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (source.present) {
      map['source'] = Variable<int>(
        $InterestsTable.$convertersource.toSql(source.value),
      );
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InterestsCompanion(')
          ..write('id: $id, ')
          ..write('childId: $childId, ')
          ..write('label: $label, ')
          ..write('weight: $weight, ')
          ..write('active: $active, ')
          ..write('source: $source, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LearnedProfilesTable extends LearnedProfiles
    with TableInfo<$LearnedProfilesTable, LearnedProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LearnedProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _childIdMeta = const VerificationMeta(
    'childId',
  );
  @override
  late final GeneratedColumn<String> childId = GeneratedColumn<String>(
    'child_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES child_profiles (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _dataJsonMeta = const VerificationMeta(
    'dataJson',
  );
  @override
  late final GeneratedColumn<String> dataJson = GeneratedColumn<String>(
    'data_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [childId, dataJson, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'learned_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<LearnedProfileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('child_id')) {
      context.handle(
        _childIdMeta,
        childId.isAcceptableOrUnknown(data['child_id']!, _childIdMeta),
      );
    } else if (isInserting) {
      context.missing(_childIdMeta);
    }
    if (data.containsKey('data_json')) {
      context.handle(
        _dataJsonMeta,
        dataJson.isAcceptableOrUnknown(data['data_json']!, _dataJsonMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {childId};
  @override
  LearnedProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LearnedProfileRow(
      childId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}child_id'],
      )!,
      dataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LearnedProfilesTable createAlias(String alias) {
    return $LearnedProfilesTable(attachedDatabase, alias);
  }
}

class LearnedProfileRow extends DataClass
    implements Insertable<LearnedProfileRow> {
  final String childId;
  final String dataJson;
  final DateTime updatedAt;
  const LearnedProfileRow({
    required this.childId,
    required this.dataJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['child_id'] = Variable<String>(childId);
    map['data_json'] = Variable<String>(dataJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LearnedProfilesCompanion toCompanion(bool nullToAbsent) {
    return LearnedProfilesCompanion(
      childId: Value(childId),
      dataJson: Value(dataJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory LearnedProfileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LearnedProfileRow(
      childId: serializer.fromJson<String>(json['childId']),
      dataJson: serializer.fromJson<String>(json['dataJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'childId': serializer.toJson<String>(childId),
      'dataJson': serializer.toJson<String>(dataJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LearnedProfileRow copyWith({
    String? childId,
    String? dataJson,
    DateTime? updatedAt,
  }) => LearnedProfileRow(
    childId: childId ?? this.childId,
    dataJson: dataJson ?? this.dataJson,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LearnedProfileRow copyWithCompanion(LearnedProfilesCompanion data) {
    return LearnedProfileRow(
      childId: data.childId.present ? data.childId.value : this.childId,
      dataJson: data.dataJson.present ? data.dataJson.value : this.dataJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LearnedProfileRow(')
          ..write('childId: $childId, ')
          ..write('dataJson: $dataJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(childId, dataJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LearnedProfileRow &&
          other.childId == this.childId &&
          other.dataJson == this.dataJson &&
          other.updatedAt == this.updatedAt);
}

class LearnedProfilesCompanion extends UpdateCompanion<LearnedProfileRow> {
  final Value<String> childId;
  final Value<String> dataJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const LearnedProfilesCompanion({
    this.childId = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LearnedProfilesCompanion.insert({
    required String childId,
    this.dataJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : childId = Value(childId);
  static Insertable<LearnedProfileRow> custom({
    Expression<String>? childId,
    Expression<String>? dataJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (childId != null) 'child_id': childId,
      if (dataJson != null) 'data_json': dataJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LearnedProfilesCompanion copyWith({
    Value<String>? childId,
    Value<String>? dataJson,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return LearnedProfilesCompanion(
      childId: childId ?? this.childId,
      dataJson: dataJson ?? this.dataJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (childId.present) {
      map['child_id'] = Variable<String>(childId.value);
    }
    if (dataJson.present) {
      map['data_json'] = Variable<String>(dataJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LearnedProfilesCompanion(')
          ..write('childId: $childId, ')
          ..write('dataJson: $dataJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ChildProfilesTable childProfiles = $ChildProfilesTable(this);
  late final $QuizResultsTable quizResults = $QuizResultsTable(this);
  late final $InterestsTable interests = $InterestsTable(this);
  late final $LearnedProfilesTable learnedProfiles = $LearnedProfilesTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    childProfiles,
    quizResults,
    interests,
    learnedProfiles,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'child_profiles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('quiz_results', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'child_profiles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('interests', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'child_profiles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('learned_profiles', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$ChildProfilesTableCreateCompanionBuilder =
    ChildProfilesCompanion Function({
      required String id,
      required String displayName,
      required int age,
      Value<String> language,
      required DetailLevel detailLevel,
      Value<int> themeColor,
      Value<String?> parentBrief,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$ChildProfilesTableUpdateCompanionBuilder =
    ChildProfilesCompanion Function({
      Value<String> id,
      Value<String> displayName,
      Value<int> age,
      Value<String> language,
      Value<DetailLevel> detailLevel,
      Value<int> themeColor,
      Value<String?> parentBrief,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$ChildProfilesTableReferences
    extends
        BaseReferences<_$AppDatabase, $ChildProfilesTable, ChildProfileRow> {
  $$ChildProfilesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$QuizResultsTable, List<QuizResultRow>>
  _quizResultsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.quizResults,
    aliasName: 'child_profiles__id__quiz_results__child_id',
  );

  $$QuizResultsTableProcessedTableManager get quizResultsRefs {
    final manager = $$QuizResultsTableTableManager(
      $_db,
      $_db.quizResults,
    ).filter((f) => f.childId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_quizResultsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$InterestsTable, List<InterestRow>>
  _interestsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.interests,
    aliasName: 'child_profiles__id__interests__child_id',
  );

  $$InterestsTableProcessedTableManager get interestsRefs {
    final manager = $$InterestsTableTableManager(
      $_db,
      $_db.interests,
    ).filter((f) => f.childId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_interestsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LearnedProfilesTable, List<LearnedProfileRow>>
  _learnedProfilesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.learnedProfiles,
    aliasName: 'child_profiles__id__learned_profiles__child_id',
  );

  $$LearnedProfilesTableProcessedTableManager get learnedProfilesRefs {
    final manager = $$LearnedProfilesTableTableManager(
      $_db,
      $_db.learnedProfiles,
    ).filter((f) => f.childId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _learnedProfilesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ChildProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $ChildProfilesTable> {
  $$ChildProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get age => $composableBuilder(
    column: $table.age,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DetailLevel, DetailLevel, int>
  get detailLevel => $composableBuilder(
    column: $table.detailLevel,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get themeColor => $composableBuilder(
    column: $table.themeColor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentBrief => $composableBuilder(
    column: $table.parentBrief,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> quizResultsRefs(
    Expression<bool> Function($$QuizResultsTableFilterComposer f) f,
  ) {
    final $$QuizResultsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.quizResults,
      getReferencedColumn: (t) => t.childId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuizResultsTableFilterComposer(
            $db: $db,
            $table: $db.quizResults,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> interestsRefs(
    Expression<bool> Function($$InterestsTableFilterComposer f) f,
  ) {
    final $$InterestsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.interests,
      getReferencedColumn: (t) => t.childId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InterestsTableFilterComposer(
            $db: $db,
            $table: $db.interests,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> learnedProfilesRefs(
    Expression<bool> Function($$LearnedProfilesTableFilterComposer f) f,
  ) {
    final $$LearnedProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.learnedProfiles,
      getReferencedColumn: (t) => t.childId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearnedProfilesTableFilterComposer(
            $db: $db,
            $table: $db.learnedProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ChildProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $ChildProfilesTable> {
  $$ChildProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get age => $composableBuilder(
    column: $table.age,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get detailLevel => $composableBuilder(
    column: $table.detailLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get themeColor => $composableBuilder(
    column: $table.themeColor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentBrief => $composableBuilder(
    column: $table.parentBrief,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChildProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChildProfilesTable> {
  $$ChildProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get age =>
      $composableBuilder(column: $table.age, builder: (column) => column);

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DetailLevel, int> get detailLevel =>
      $composableBuilder(
        column: $table.detailLevel,
        builder: (column) => column,
      );

  GeneratedColumn<int> get themeColor => $composableBuilder(
    column: $table.themeColor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get parentBrief => $composableBuilder(
    column: $table.parentBrief,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> quizResultsRefs<T extends Object>(
    Expression<T> Function($$QuizResultsTableAnnotationComposer a) f,
  ) {
    final $$QuizResultsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.quizResults,
      getReferencedColumn: (t) => t.childId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$QuizResultsTableAnnotationComposer(
            $db: $db,
            $table: $db.quizResults,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> interestsRefs<T extends Object>(
    Expression<T> Function($$InterestsTableAnnotationComposer a) f,
  ) {
    final $$InterestsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.interests,
      getReferencedColumn: (t) => t.childId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InterestsTableAnnotationComposer(
            $db: $db,
            $table: $db.interests,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> learnedProfilesRefs<T extends Object>(
    Expression<T> Function($$LearnedProfilesTableAnnotationComposer a) f,
  ) {
    final $$LearnedProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.learnedProfiles,
      getReferencedColumn: (t) => t.childId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LearnedProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.learnedProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ChildProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChildProfilesTable,
          ChildProfileRow,
          $$ChildProfilesTableFilterComposer,
          $$ChildProfilesTableOrderingComposer,
          $$ChildProfilesTableAnnotationComposer,
          $$ChildProfilesTableCreateCompanionBuilder,
          $$ChildProfilesTableUpdateCompanionBuilder,
          (ChildProfileRow, $$ChildProfilesTableReferences),
          ChildProfileRow,
          PrefetchHooks Function({
            bool quizResultsRefs,
            bool interestsRefs,
            bool learnedProfilesRefs,
          })
        > {
  $$ChildProfilesTableTableManager(_$AppDatabase db, $ChildProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChildProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChildProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChildProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<int> age = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<DetailLevel> detailLevel = const Value.absent(),
                Value<int> themeColor = const Value.absent(),
                Value<String?> parentBrief = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChildProfilesCompanion(
                id: id,
                displayName: displayName,
                age: age,
                language: language,
                detailLevel: detailLevel,
                themeColor: themeColor,
                parentBrief: parentBrief,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String displayName,
                required int age,
                Value<String> language = const Value.absent(),
                required DetailLevel detailLevel,
                Value<int> themeColor = const Value.absent(),
                Value<String?> parentBrief = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChildProfilesCompanion.insert(
                id: id,
                displayName: displayName,
                age: age,
                language: language,
                detailLevel: detailLevel,
                themeColor: themeColor,
                parentBrief: parentBrief,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ChildProfilesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                quizResultsRefs = false,
                interestsRefs = false,
                learnedProfilesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (quizResultsRefs) db.quizResults,
                    if (interestsRefs) db.interests,
                    if (learnedProfilesRefs) db.learnedProfiles,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (quizResultsRefs)
                        await $_getPrefetchedData<
                          ChildProfileRow,
                          $ChildProfilesTable,
                          QuizResultRow
                        >(
                          currentTable: table,
                          referencedTable: $$ChildProfilesTableReferences
                              ._quizResultsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ChildProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).quizResultsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.childId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (interestsRefs)
                        await $_getPrefetchedData<
                          ChildProfileRow,
                          $ChildProfilesTable,
                          InterestRow
                        >(
                          currentTable: table,
                          referencedTable: $$ChildProfilesTableReferences
                              ._interestsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ChildProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).interestsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.childId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (learnedProfilesRefs)
                        await $_getPrefetchedData<
                          ChildProfileRow,
                          $ChildProfilesTable,
                          LearnedProfileRow
                        >(
                          currentTable: table,
                          referencedTable: $$ChildProfilesTableReferences
                              ._learnedProfilesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ChildProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).learnedProfilesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.childId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ChildProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChildProfilesTable,
      ChildProfileRow,
      $$ChildProfilesTableFilterComposer,
      $$ChildProfilesTableOrderingComposer,
      $$ChildProfilesTableAnnotationComposer,
      $$ChildProfilesTableCreateCompanionBuilder,
      $$ChildProfilesTableUpdateCompanionBuilder,
      (ChildProfileRow, $$ChildProfilesTableReferences),
      ChildProfileRow,
      PrefetchHooks Function({
        bool quizResultsRefs,
        bool interestsRefs,
        bool learnedProfilesRefs,
      })
    >;
typedef $$QuizResultsTableCreateCompanionBuilder =
    QuizResultsCompanion Function({
      required String id,
      required String childId,
      required QuizKind kind,
      required Map<String, String> answers,
      required String seedSummary,
      Value<int> version,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$QuizResultsTableUpdateCompanionBuilder =
    QuizResultsCompanion Function({
      Value<String> id,
      Value<String> childId,
      Value<QuizKind> kind,
      Value<Map<String, String>> answers,
      Value<String> seedSummary,
      Value<int> version,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$QuizResultsTableReferences
    extends BaseReferences<_$AppDatabase, $QuizResultsTable, QuizResultRow> {
  $$QuizResultsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ChildProfilesTable _childIdTable(_$AppDatabase db) => db.childProfiles
      .createAlias('quiz_results__child_id__child_profiles__id');

  $$ChildProfilesTableProcessedTableManager get childId {
    final $_column = $_itemColumn<String>('child_id')!;

    final manager = $$ChildProfilesTableTableManager(
      $_db,
      $_db.childProfiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_childIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$QuizResultsTableFilterComposer
    extends Composer<_$AppDatabase, $QuizResultsTable> {
  $$QuizResultsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<QuizKind, QuizKind, int> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<
    Map<String, String>,
    Map<String, String>,
    String
  >
  get answers => $composableBuilder(
    column: $table.answers,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get seedSummary => $composableBuilder(
    column: $table.seedSummary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ChildProfilesTableFilterComposer get childId {
    final $$ChildProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childId,
      referencedTable: $db.childProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChildProfilesTableFilterComposer(
            $db: $db,
            $table: $db.childProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$QuizResultsTableOrderingComposer
    extends Composer<_$AppDatabase, $QuizResultsTable> {
  $$QuizResultsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get answers => $composableBuilder(
    column: $table.answers,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get seedSummary => $composableBuilder(
    column: $table.seedSummary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ChildProfilesTableOrderingComposer get childId {
    final $$ChildProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childId,
      referencedTable: $db.childProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChildProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.childProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$QuizResultsTableAnnotationComposer
    extends Composer<_$AppDatabase, $QuizResultsTable> {
  $$QuizResultsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<QuizKind, int> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Map<String, String>, String> get answers =>
      $composableBuilder(column: $table.answers, builder: (column) => column);

  GeneratedColumn<String> get seedSummary => $composableBuilder(
    column: $table.seedSummary,
    builder: (column) => column,
  );

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ChildProfilesTableAnnotationComposer get childId {
    final $$ChildProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childId,
      referencedTable: $db.childProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChildProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.childProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$QuizResultsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $QuizResultsTable,
          QuizResultRow,
          $$QuizResultsTableFilterComposer,
          $$QuizResultsTableOrderingComposer,
          $$QuizResultsTableAnnotationComposer,
          $$QuizResultsTableCreateCompanionBuilder,
          $$QuizResultsTableUpdateCompanionBuilder,
          (QuizResultRow, $$QuizResultsTableReferences),
          QuizResultRow,
          PrefetchHooks Function({bool childId})
        > {
  $$QuizResultsTableTableManager(_$AppDatabase db, $QuizResultsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QuizResultsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QuizResultsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QuizResultsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> childId = const Value.absent(),
                Value<QuizKind> kind = const Value.absent(),
                Value<Map<String, String>> answers = const Value.absent(),
                Value<String> seedSummary = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QuizResultsCompanion(
                id: id,
                childId: childId,
                kind: kind,
                answers: answers,
                seedSummary: seedSummary,
                version: version,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String childId,
                required QuizKind kind,
                required Map<String, String> answers,
                required String seedSummary,
                Value<int> version = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QuizResultsCompanion.insert(
                id: id,
                childId: childId,
                kind: kind,
                answers: answers,
                seedSummary: seedSummary,
                version: version,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$QuizResultsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({childId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (childId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.childId,
                                referencedTable: $$QuizResultsTableReferences
                                    ._childIdTable(db),
                                referencedColumn: $$QuizResultsTableReferences
                                    ._childIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$QuizResultsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $QuizResultsTable,
      QuizResultRow,
      $$QuizResultsTableFilterComposer,
      $$QuizResultsTableOrderingComposer,
      $$QuizResultsTableAnnotationComposer,
      $$QuizResultsTableCreateCompanionBuilder,
      $$QuizResultsTableUpdateCompanionBuilder,
      (QuizResultRow, $$QuizResultsTableReferences),
      QuizResultRow,
      PrefetchHooks Function({bool childId})
    >;
typedef $$InterestsTableCreateCompanionBuilder =
    InterestsCompanion Function({
      required String id,
      required String childId,
      required String label,
      Value<int> weight,
      Value<bool> active,
      required InterestSource source,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });
typedef $$InterestsTableUpdateCompanionBuilder =
    InterestsCompanion Function({
      Value<String> id,
      Value<String> childId,
      Value<String> label,
      Value<int> weight,
      Value<bool> active,
      Value<InterestSource> source,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });

final class $$InterestsTableReferences
    extends BaseReferences<_$AppDatabase, $InterestsTable, InterestRow> {
  $$InterestsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ChildProfilesTable _childIdTable(_$AppDatabase db) =>
      db.childProfiles.createAlias('interests__child_id__child_profiles__id');

  $$ChildProfilesTableProcessedTableManager get childId {
    final $_column = $_itemColumn<String>('child_id')!;

    final manager = $$ChildProfilesTableTableManager(
      $_db,
      $_db.childProfiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_childIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$InterestsTableFilterComposer
    extends Composer<_$AppDatabase, $InterestsTable> {
  $$InterestsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get weight => $composableBuilder(
    column: $table.weight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<InterestSource, InterestSource, int>
  get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ChildProfilesTableFilterComposer get childId {
    final $$ChildProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childId,
      referencedTable: $db.childProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChildProfilesTableFilterComposer(
            $db: $db,
            $table: $db.childProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InterestsTableOrderingComposer
    extends Composer<_$AppDatabase, $InterestsTable> {
  $$InterestsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get weight => $composableBuilder(
    column: $table.weight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ChildProfilesTableOrderingComposer get childId {
    final $$ChildProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childId,
      referencedTable: $db.childProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChildProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.childProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InterestsTableAnnotationComposer
    extends Composer<_$AppDatabase, $InterestsTable> {
  $$InterestsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<int> get weight =>
      $composableBuilder(column: $table.weight, builder: (column) => column);

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  GeneratedColumnWithTypeConverter<InterestSource, int> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  $$ChildProfilesTableAnnotationComposer get childId {
    final $$ChildProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childId,
      referencedTable: $db.childProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChildProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.childProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InterestsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InterestsTable,
          InterestRow,
          $$InterestsTableFilterComposer,
          $$InterestsTableOrderingComposer,
          $$InterestsTableAnnotationComposer,
          $$InterestsTableCreateCompanionBuilder,
          $$InterestsTableUpdateCompanionBuilder,
          (InterestRow, $$InterestsTableReferences),
          InterestRow,
          PrefetchHooks Function({bool childId})
        > {
  $$InterestsTableTableManager(_$AppDatabase db, $InterestsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InterestsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InterestsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InterestsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> childId = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<int> weight = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<InterestSource> source = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InterestsCompanion(
                id: id,
                childId: childId,
                label: label,
                weight: weight,
                active: active,
                source: source,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String childId,
                required String label,
                Value<int> weight = const Value.absent(),
                Value<bool> active = const Value.absent(),
                required InterestSource source,
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InterestsCompanion.insert(
                id: id,
                childId: childId,
                label: label,
                weight: weight,
                active: active,
                source: source,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$InterestsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({childId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (childId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.childId,
                                referencedTable: $$InterestsTableReferences
                                    ._childIdTable(db),
                                referencedColumn: $$InterestsTableReferences
                                    ._childIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$InterestsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InterestsTable,
      InterestRow,
      $$InterestsTableFilterComposer,
      $$InterestsTableOrderingComposer,
      $$InterestsTableAnnotationComposer,
      $$InterestsTableCreateCompanionBuilder,
      $$InterestsTableUpdateCompanionBuilder,
      (InterestRow, $$InterestsTableReferences),
      InterestRow,
      PrefetchHooks Function({bool childId})
    >;
typedef $$LearnedProfilesTableCreateCompanionBuilder =
    LearnedProfilesCompanion Function({
      required String childId,
      Value<String> dataJson,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$LearnedProfilesTableUpdateCompanionBuilder =
    LearnedProfilesCompanion Function({
      Value<String> childId,
      Value<String> dataJson,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$LearnedProfilesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $LearnedProfilesTable,
          LearnedProfileRow
        > {
  $$LearnedProfilesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ChildProfilesTable _childIdTable(_$AppDatabase db) => db.childProfiles
      .createAlias('learned_profiles__child_id__child_profiles__id');

  $$ChildProfilesTableProcessedTableManager get childId {
    final $_column = $_itemColumn<String>('child_id')!;

    final manager = $$ChildProfilesTableTableManager(
      $_db,
      $_db.childProfiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_childIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LearnedProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $LearnedProfilesTable> {
  $$LearnedProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ChildProfilesTableFilterComposer get childId {
    final $$ChildProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childId,
      referencedTable: $db.childProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChildProfilesTableFilterComposer(
            $db: $db,
            $table: $db.childProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearnedProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $LearnedProfilesTable> {
  $$LearnedProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ChildProfilesTableOrderingComposer get childId {
    final $$ChildProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childId,
      referencedTable: $db.childProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChildProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.childProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearnedProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LearnedProfilesTable> {
  $$LearnedProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get dataJson =>
      $composableBuilder(column: $table.dataJson, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ChildProfilesTableAnnotationComposer get childId {
    final $$ChildProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.childId,
      referencedTable: $db.childProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChildProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.childProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LearnedProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LearnedProfilesTable,
          LearnedProfileRow,
          $$LearnedProfilesTableFilterComposer,
          $$LearnedProfilesTableOrderingComposer,
          $$LearnedProfilesTableAnnotationComposer,
          $$LearnedProfilesTableCreateCompanionBuilder,
          $$LearnedProfilesTableUpdateCompanionBuilder,
          (LearnedProfileRow, $$LearnedProfilesTableReferences),
          LearnedProfileRow,
          PrefetchHooks Function({bool childId})
        > {
  $$LearnedProfilesTableTableManager(
    _$AppDatabase db,
    $LearnedProfilesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LearnedProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LearnedProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LearnedProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> childId = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LearnedProfilesCompanion(
                childId: childId,
                dataJson: dataJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String childId,
                Value<String> dataJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LearnedProfilesCompanion.insert(
                childId: childId,
                dataJson: dataJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LearnedProfilesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({childId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (childId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.childId,
                                referencedTable:
                                    $$LearnedProfilesTableReferences
                                        ._childIdTable(db),
                                referencedColumn:
                                    $$LearnedProfilesTableReferences
                                        ._childIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LearnedProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LearnedProfilesTable,
      LearnedProfileRow,
      $$LearnedProfilesTableFilterComposer,
      $$LearnedProfilesTableOrderingComposer,
      $$LearnedProfilesTableAnnotationComposer,
      $$LearnedProfilesTableCreateCompanionBuilder,
      $$LearnedProfilesTableUpdateCompanionBuilder,
      (LearnedProfileRow, $$LearnedProfilesTableReferences),
      LearnedProfileRow,
      PrefetchHooks Function({bool childId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ChildProfilesTableTableManager get childProfiles =>
      $$ChildProfilesTableTableManager(_db, _db.childProfiles);
  $$QuizResultsTableTableManager get quizResults =>
      $$QuizResultsTableTableManager(_db, _db.quizResults);
  $$InterestsTableTableManager get interests =>
      $$InterestsTableTableManager(_db, _db.interests);
  $$LearnedProfilesTableTableManager get learnedProfiles =>
      $$LearnedProfilesTableTableManager(_db, _db.learnedProfiles);
}
