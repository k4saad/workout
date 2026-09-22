// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $SessionsTable extends Sessions with TableInfo<$SessionsTable, Session> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _programmeIdMeta = const VerificationMeta(
    'programmeId',
  );
  @override
  late final GeneratedColumn<String> programmeId = GeneratedColumn<String>(
    'programme_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _blockIdMeta = const VerificationMeta(
    'blockId',
  );
  @override
  late final GeneratedColumn<String> blockId = GeneratedColumn<String>(
    'block_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dayIdMeta = const VerificationMeta('dayId');
  @override
  late final GeneratedColumn<String> dayId = GeneratedColumn<String>(
    'day_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weekNoMeta = const VerificationMeta('weekNo');
  @override
  late final GeneratedColumn<int> weekNo = GeneratedColumn<int>(
    'week_no',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _plannedDateMeta = const VerificationMeta(
    'plannedDate',
  );
  @override
  late final GeneratedColumn<DateTime> plannedDate = GeneratedColumn<DateTime>(
    'planned_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scheduledDateMeta = const VerificationMeta(
    'scheduledDate',
  );
  @override
  late final GeneratedColumn<DateTime> scheduledDate =
      GeneratedColumn<DateTime>(
        'scheduled_date',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _finishedAtMeta = const VerificationMeta(
    'finishedAt',
  );
  @override
  late final GeneratedColumn<DateTime> finishedAt = GeneratedColumn<DateTime>(
    'finished_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<SessionStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('planned'),
      ).withConverter<SessionStatus>($SessionsTable.$converterstatus);
  static const VerificationMeta _bodyweightKgMeta = const VerificationMeta(
    'bodyweightKg',
  );
  @override
  late final GeneratedColumn<double> bodyweightKg = GeneratedColumn<double>(
    'bodyweight_kg',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rpeOverallMeta = const VerificationMeta(
    'rpeOverall',
  );
  @override
  late final GeneratedColumn<int> rpeOverall = GeneratedColumn<int>(
    'rpe_overall',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _loggedRetroactivelyMeta =
      const VerificationMeta('loggedRetroactively');
  @override
  late final GeneratedColumn<bool> loggedRetroactively = GeneratedColumn<bool>(
    'logged_retroactively',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("logged_retroactively" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _wasShortenedMeta = const VerificationMeta(
    'wasShortened',
  );
  @override
  late final GeneratedColumn<bool> wasShortened = GeneratedColumn<bool>(
    'was_shortened',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("was_shortened" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    programmeId,
    blockId,
    dayId,
    weekNo,
    plannedDate,
    scheduledDate,
    startedAt,
    finishedAt,
    status,
    bodyweightKg,
    rpeOverall,
    note,
    loggedRetroactively,
    wasShortened,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Session> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('programme_id')) {
      context.handle(
        _programmeIdMeta,
        programmeId.isAcceptableOrUnknown(
          data['programme_id']!,
          _programmeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_programmeIdMeta);
    }
    if (data.containsKey('block_id')) {
      context.handle(
        _blockIdMeta,
        blockId.isAcceptableOrUnknown(data['block_id']!, _blockIdMeta),
      );
    } else if (isInserting) {
      context.missing(_blockIdMeta);
    }
    if (data.containsKey('day_id')) {
      context.handle(
        _dayIdMeta,
        dayId.isAcceptableOrUnknown(data['day_id']!, _dayIdMeta),
      );
    } else if (isInserting) {
      context.missing(_dayIdMeta);
    }
    if (data.containsKey('week_no')) {
      context.handle(
        _weekNoMeta,
        weekNo.isAcceptableOrUnknown(data['week_no']!, _weekNoMeta),
      );
    } else if (isInserting) {
      context.missing(_weekNoMeta);
    }
    if (data.containsKey('planned_date')) {
      context.handle(
        _plannedDateMeta,
        plannedDate.isAcceptableOrUnknown(
          data['planned_date']!,
          _plannedDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_plannedDateMeta);
    }
    if (data.containsKey('scheduled_date')) {
      context.handle(
        _scheduledDateMeta,
        scheduledDate.isAcceptableOrUnknown(
          data['scheduled_date']!,
          _scheduledDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduledDateMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    }
    if (data.containsKey('finished_at')) {
      context.handle(
        _finishedAtMeta,
        finishedAt.isAcceptableOrUnknown(data['finished_at']!, _finishedAtMeta),
      );
    }
    if (data.containsKey('bodyweight_kg')) {
      context.handle(
        _bodyweightKgMeta,
        bodyweightKg.isAcceptableOrUnknown(
          data['bodyweight_kg']!,
          _bodyweightKgMeta,
        ),
      );
    }
    if (data.containsKey('rpe_overall')) {
      context.handle(
        _rpeOverallMeta,
        rpeOverall.isAcceptableOrUnknown(data['rpe_overall']!, _rpeOverallMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('logged_retroactively')) {
      context.handle(
        _loggedRetroactivelyMeta,
        loggedRetroactively.isAcceptableOrUnknown(
          data['logged_retroactively']!,
          _loggedRetroactivelyMeta,
        ),
      );
    }
    if (data.containsKey('was_shortened')) {
      context.handle(
        _wasShortenedMeta,
        wasShortened.isAcceptableOrUnknown(
          data['was_shortened']!,
          _wasShortenedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Session map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Session(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      programmeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}programme_id'],
      )!,
      blockId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}block_id'],
      )!,
      dayId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day_id'],
      )!,
      weekNo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}week_no'],
      )!,
      plannedDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}planned_date'],
      )!,
      scheduledDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scheduled_date'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      ),
      finishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}finished_at'],
      ),
      status: $SessionsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      bodyweightKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}bodyweight_kg'],
      ),
      rpeOverall: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rpe_overall'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      loggedRetroactively: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}logged_retroactively'],
      )!,
      wasShortened: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}was_shortened'],
      )!,
    );
  }

  @override
  $SessionsTable createAlias(String alias) {
    return $SessionsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<SessionStatus, String, String> $converterstatus =
      const EnumNameConverter<SessionStatus>(SessionStatus.values);
}

class Session extends DataClass implements Insertable<Session> {
  final int id;
  final String programmeId;
  final String blockId;
  final String dayId;
  final int weekNo;
  final DateTime plannedDate;
  final DateTime scheduledDate;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final SessionStatus status;
  final double? bodyweightKg;
  final int? rpeOverall;
  final String? note;

  /// True when the session was reconstructed from memory rather than logged
  /// live. You will forget to open the app mid-session a dozen times over
  /// twelve weeks, and the progression engine needs that history anyway.
  final bool loggedRetroactively;

  /// Set when the athlete chose the short version of the session.
  final bool wasShortened;
  const Session({
    required this.id,
    required this.programmeId,
    required this.blockId,
    required this.dayId,
    required this.weekNo,
    required this.plannedDate,
    required this.scheduledDate,
    this.startedAt,
    this.finishedAt,
    required this.status,
    this.bodyweightKg,
    this.rpeOverall,
    this.note,
    required this.loggedRetroactively,
    required this.wasShortened,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['programme_id'] = Variable<String>(programmeId);
    map['block_id'] = Variable<String>(blockId);
    map['day_id'] = Variable<String>(dayId);
    map['week_no'] = Variable<int>(weekNo);
    map['planned_date'] = Variable<DateTime>(plannedDate);
    map['scheduled_date'] = Variable<DateTime>(scheduledDate);
    if (!nullToAbsent || startedAt != null) {
      map['started_at'] = Variable<DateTime>(startedAt);
    }
    if (!nullToAbsent || finishedAt != null) {
      map['finished_at'] = Variable<DateTime>(finishedAt);
    }
    {
      map['status'] = Variable<String>(
        $SessionsTable.$converterstatus.toSql(status),
      );
    }
    if (!nullToAbsent || bodyweightKg != null) {
      map['bodyweight_kg'] = Variable<double>(bodyweightKg);
    }
    if (!nullToAbsent || rpeOverall != null) {
      map['rpe_overall'] = Variable<int>(rpeOverall);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['logged_retroactively'] = Variable<bool>(loggedRetroactively);
    map['was_shortened'] = Variable<bool>(wasShortened);
    return map;
  }

  SessionsCompanion toCompanion(bool nullToAbsent) {
    return SessionsCompanion(
      id: Value(id),
      programmeId: Value(programmeId),
      blockId: Value(blockId),
      dayId: Value(dayId),
      weekNo: Value(weekNo),
      plannedDate: Value(plannedDate),
      scheduledDate: Value(scheduledDate),
      startedAt: startedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(startedAt),
      finishedAt: finishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(finishedAt),
      status: Value(status),
      bodyweightKg: bodyweightKg == null && nullToAbsent
          ? const Value.absent()
          : Value(bodyweightKg),
      rpeOverall: rpeOverall == null && nullToAbsent
          ? const Value.absent()
          : Value(rpeOverall),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      loggedRetroactively: Value(loggedRetroactively),
      wasShortened: Value(wasShortened),
    );
  }

  factory Session.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Session(
      id: serializer.fromJson<int>(json['id']),
      programmeId: serializer.fromJson<String>(json['programmeId']),
      blockId: serializer.fromJson<String>(json['blockId']),
      dayId: serializer.fromJson<String>(json['dayId']),
      weekNo: serializer.fromJson<int>(json['weekNo']),
      plannedDate: serializer.fromJson<DateTime>(json['plannedDate']),
      scheduledDate: serializer.fromJson<DateTime>(json['scheduledDate']),
      startedAt: serializer.fromJson<DateTime?>(json['startedAt']),
      finishedAt: serializer.fromJson<DateTime?>(json['finishedAt']),
      status: $SessionsTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      bodyweightKg: serializer.fromJson<double?>(json['bodyweightKg']),
      rpeOverall: serializer.fromJson<int?>(json['rpeOverall']),
      note: serializer.fromJson<String?>(json['note']),
      loggedRetroactively: serializer.fromJson<bool>(
        json['loggedRetroactively'],
      ),
      wasShortened: serializer.fromJson<bool>(json['wasShortened']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'programmeId': serializer.toJson<String>(programmeId),
      'blockId': serializer.toJson<String>(blockId),
      'dayId': serializer.toJson<String>(dayId),
      'weekNo': serializer.toJson<int>(weekNo),
      'plannedDate': serializer.toJson<DateTime>(plannedDate),
      'scheduledDate': serializer.toJson<DateTime>(scheduledDate),
      'startedAt': serializer.toJson<DateTime?>(startedAt),
      'finishedAt': serializer.toJson<DateTime?>(finishedAt),
      'status': serializer.toJson<String>(
        $SessionsTable.$converterstatus.toJson(status),
      ),
      'bodyweightKg': serializer.toJson<double?>(bodyweightKg),
      'rpeOverall': serializer.toJson<int?>(rpeOverall),
      'note': serializer.toJson<String?>(note),
      'loggedRetroactively': serializer.toJson<bool>(loggedRetroactively),
      'wasShortened': serializer.toJson<bool>(wasShortened),
    };
  }

  Session copyWith({
    int? id,
    String? programmeId,
    String? blockId,
    String? dayId,
    int? weekNo,
    DateTime? plannedDate,
    DateTime? scheduledDate,
    Value<DateTime?> startedAt = const Value.absent(),
    Value<DateTime?> finishedAt = const Value.absent(),
    SessionStatus? status,
    Value<double?> bodyweightKg = const Value.absent(),
    Value<int?> rpeOverall = const Value.absent(),
    Value<String?> note = const Value.absent(),
    bool? loggedRetroactively,
    bool? wasShortened,
  }) => Session(
    id: id ?? this.id,
    programmeId: programmeId ?? this.programmeId,
    blockId: blockId ?? this.blockId,
    dayId: dayId ?? this.dayId,
    weekNo: weekNo ?? this.weekNo,
    plannedDate: plannedDate ?? this.plannedDate,
    scheduledDate: scheduledDate ?? this.scheduledDate,
    startedAt: startedAt.present ? startedAt.value : this.startedAt,
    finishedAt: finishedAt.present ? finishedAt.value : this.finishedAt,
    status: status ?? this.status,
    bodyweightKg: bodyweightKg.present ? bodyweightKg.value : this.bodyweightKg,
    rpeOverall: rpeOverall.present ? rpeOverall.value : this.rpeOverall,
    note: note.present ? note.value : this.note,
    loggedRetroactively: loggedRetroactively ?? this.loggedRetroactively,
    wasShortened: wasShortened ?? this.wasShortened,
  );
  Session copyWithCompanion(SessionsCompanion data) {
    return Session(
      id: data.id.present ? data.id.value : this.id,
      programmeId: data.programmeId.present
          ? data.programmeId.value
          : this.programmeId,
      blockId: data.blockId.present ? data.blockId.value : this.blockId,
      dayId: data.dayId.present ? data.dayId.value : this.dayId,
      weekNo: data.weekNo.present ? data.weekNo.value : this.weekNo,
      plannedDate: data.plannedDate.present
          ? data.plannedDate.value
          : this.plannedDate,
      scheduledDate: data.scheduledDate.present
          ? data.scheduledDate.value
          : this.scheduledDate,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      finishedAt: data.finishedAt.present
          ? data.finishedAt.value
          : this.finishedAt,
      status: data.status.present ? data.status.value : this.status,
      bodyweightKg: data.bodyweightKg.present
          ? data.bodyweightKg.value
          : this.bodyweightKg,
      rpeOverall: data.rpeOverall.present
          ? data.rpeOverall.value
          : this.rpeOverall,
      note: data.note.present ? data.note.value : this.note,
      loggedRetroactively: data.loggedRetroactively.present
          ? data.loggedRetroactively.value
          : this.loggedRetroactively,
      wasShortened: data.wasShortened.present
          ? data.wasShortened.value
          : this.wasShortened,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Session(')
          ..write('id: $id, ')
          ..write('programmeId: $programmeId, ')
          ..write('blockId: $blockId, ')
          ..write('dayId: $dayId, ')
          ..write('weekNo: $weekNo, ')
          ..write('plannedDate: $plannedDate, ')
          ..write('scheduledDate: $scheduledDate, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('status: $status, ')
          ..write('bodyweightKg: $bodyweightKg, ')
          ..write('rpeOverall: $rpeOverall, ')
          ..write('note: $note, ')
          ..write('loggedRetroactively: $loggedRetroactively, ')
          ..write('wasShortened: $wasShortened')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    programmeId,
    blockId,
    dayId,
    weekNo,
    plannedDate,
    scheduledDate,
    startedAt,
    finishedAt,
    status,
    bodyweightKg,
    rpeOverall,
    note,
    loggedRetroactively,
    wasShortened,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Session &&
          other.id == this.id &&
          other.programmeId == this.programmeId &&
          other.blockId == this.blockId &&
          other.dayId == this.dayId &&
          other.weekNo == this.weekNo &&
          other.plannedDate == this.plannedDate &&
          other.scheduledDate == this.scheduledDate &&
          other.startedAt == this.startedAt &&
          other.finishedAt == this.finishedAt &&
          other.status == this.status &&
          other.bodyweightKg == this.bodyweightKg &&
          other.rpeOverall == this.rpeOverall &&
          other.note == this.note &&
          other.loggedRetroactively == this.loggedRetroactively &&
          other.wasShortened == this.wasShortened);
}

class SessionsCompanion extends UpdateCompanion<Session> {
  final Value<int> id;
  final Value<String> programmeId;
  final Value<String> blockId;
  final Value<String> dayId;
  final Value<int> weekNo;
  final Value<DateTime> plannedDate;
  final Value<DateTime> scheduledDate;
  final Value<DateTime?> startedAt;
  final Value<DateTime?> finishedAt;
  final Value<SessionStatus> status;
  final Value<double?> bodyweightKg;
  final Value<int?> rpeOverall;
  final Value<String?> note;
  final Value<bool> loggedRetroactively;
  final Value<bool> wasShortened;
  const SessionsCompanion({
    this.id = const Value.absent(),
    this.programmeId = const Value.absent(),
    this.blockId = const Value.absent(),
    this.dayId = const Value.absent(),
    this.weekNo = const Value.absent(),
    this.plannedDate = const Value.absent(),
    this.scheduledDate = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.bodyweightKg = const Value.absent(),
    this.rpeOverall = const Value.absent(),
    this.note = const Value.absent(),
    this.loggedRetroactively = const Value.absent(),
    this.wasShortened = const Value.absent(),
  });
  SessionsCompanion.insert({
    this.id = const Value.absent(),
    required String programmeId,
    required String blockId,
    required String dayId,
    required int weekNo,
    required DateTime plannedDate,
    required DateTime scheduledDate,
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.bodyweightKg = const Value.absent(),
    this.rpeOverall = const Value.absent(),
    this.note = const Value.absent(),
    this.loggedRetroactively = const Value.absent(),
    this.wasShortened = const Value.absent(),
  }) : programmeId = Value(programmeId),
       blockId = Value(blockId),
       dayId = Value(dayId),
       weekNo = Value(weekNo),
       plannedDate = Value(plannedDate),
       scheduledDate = Value(scheduledDate);
  static Insertable<Session> custom({
    Expression<int>? id,
    Expression<String>? programmeId,
    Expression<String>? blockId,
    Expression<String>? dayId,
    Expression<int>? weekNo,
    Expression<DateTime>? plannedDate,
    Expression<DateTime>? scheduledDate,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? finishedAt,
    Expression<String>? status,
    Expression<double>? bodyweightKg,
    Expression<int>? rpeOverall,
    Expression<String>? note,
    Expression<bool>? loggedRetroactively,
    Expression<bool>? wasShortened,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (programmeId != null) 'programme_id': programmeId,
      if (blockId != null) 'block_id': blockId,
      if (dayId != null) 'day_id': dayId,
      if (weekNo != null) 'week_no': weekNo,
      if (plannedDate != null) 'planned_date': plannedDate,
      if (scheduledDate != null) 'scheduled_date': scheduledDate,
      if (startedAt != null) 'started_at': startedAt,
      if (finishedAt != null) 'finished_at': finishedAt,
      if (status != null) 'status': status,
      if (bodyweightKg != null) 'bodyweight_kg': bodyweightKg,
      if (rpeOverall != null) 'rpe_overall': rpeOverall,
      if (note != null) 'note': note,
      if (loggedRetroactively != null)
        'logged_retroactively': loggedRetroactively,
      if (wasShortened != null) 'was_shortened': wasShortened,
    });
  }

  SessionsCompanion copyWith({
    Value<int>? id,
    Value<String>? programmeId,
    Value<String>? blockId,
    Value<String>? dayId,
    Value<int>? weekNo,
    Value<DateTime>? plannedDate,
    Value<DateTime>? scheduledDate,
    Value<DateTime?>? startedAt,
    Value<DateTime?>? finishedAt,
    Value<SessionStatus>? status,
    Value<double?>? bodyweightKg,
    Value<int?>? rpeOverall,
    Value<String?>? note,
    Value<bool>? loggedRetroactively,
    Value<bool>? wasShortened,
  }) {
    return SessionsCompanion(
      id: id ?? this.id,
      programmeId: programmeId ?? this.programmeId,
      blockId: blockId ?? this.blockId,
      dayId: dayId ?? this.dayId,
      weekNo: weekNo ?? this.weekNo,
      plannedDate: plannedDate ?? this.plannedDate,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      status: status ?? this.status,
      bodyweightKg: bodyweightKg ?? this.bodyweightKg,
      rpeOverall: rpeOverall ?? this.rpeOverall,
      note: note ?? this.note,
      loggedRetroactively: loggedRetroactively ?? this.loggedRetroactively,
      wasShortened: wasShortened ?? this.wasShortened,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (programmeId.present) {
      map['programme_id'] = Variable<String>(programmeId.value);
    }
    if (blockId.present) {
      map['block_id'] = Variable<String>(blockId.value);
    }
    if (dayId.present) {
      map['day_id'] = Variable<String>(dayId.value);
    }
    if (weekNo.present) {
      map['week_no'] = Variable<int>(weekNo.value);
    }
    if (plannedDate.present) {
      map['planned_date'] = Variable<DateTime>(plannedDate.value);
    }
    if (scheduledDate.present) {
      map['scheduled_date'] = Variable<DateTime>(scheduledDate.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (finishedAt.present) {
      map['finished_at'] = Variable<DateTime>(finishedAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $SessionsTable.$converterstatus.toSql(status.value),
      );
    }
    if (bodyweightKg.present) {
      map['bodyweight_kg'] = Variable<double>(bodyweightKg.value);
    }
    if (rpeOverall.present) {
      map['rpe_overall'] = Variable<int>(rpeOverall.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (loggedRetroactively.present) {
      map['logged_retroactively'] = Variable<bool>(loggedRetroactively.value);
    }
    if (wasShortened.present) {
      map['was_shortened'] = Variable<bool>(wasShortened.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsCompanion(')
          ..write('id: $id, ')
          ..write('programmeId: $programmeId, ')
          ..write('blockId: $blockId, ')
          ..write('dayId: $dayId, ')
          ..write('weekNo: $weekNo, ')
          ..write('plannedDate: $plannedDate, ')
          ..write('scheduledDate: $scheduledDate, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('status: $status, ')
          ..write('bodyweightKg: $bodyweightKg, ')
          ..write('rpeOverall: $rpeOverall, ')
          ..write('note: $note, ')
          ..write('loggedRetroactively: $loggedRetroactively, ')
          ..write('wasShortened: $wasShortened')
          ..write(')'))
        .toString();
  }
}

class $SetLogsTable extends SetLogs with TableInfo<$SetLogsTable, SetLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SetLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<int> sessionId = GeneratedColumn<int>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sessions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _prescriptionIdMeta = const VerificationMeta(
    'prescriptionId',
  );
  @override
  late final GeneratedColumn<String> prescriptionId = GeneratedColumn<String>(
    'prescription_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exerciseIdMeta = const VerificationMeta(
    'exerciseId',
  );
  @override
  late final GeneratedColumn<String> exerciseId = GeneratedColumn<String>(
    'exercise_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _setIndexMeta = const VerificationMeta(
    'setIndex',
  );
  @override
  late final GeneratedColumn<int> setIndex = GeneratedColumn<int>(
    'set_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetRepsMinMeta = const VerificationMeta(
    'targetRepsMin',
  );
  @override
  late final GeneratedColumn<int> targetRepsMin = GeneratedColumn<int>(
    'target_reps_min',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetRepsMaxMeta = const VerificationMeta(
    'targetRepsMax',
  );
  @override
  late final GeneratedColumn<int> targetRepsMax = GeneratedColumn<int>(
    'target_reps_max',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetLoadKgMeta = const VerificationMeta(
    'targetLoadKg',
  );
  @override
  late final GeneratedColumn<double> targetLoadKg = GeneratedColumn<double>(
    'target_load_kg',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _repsMeta = const VerificationMeta('reps');
  @override
  late final GeneratedColumn<int> reps = GeneratedColumn<int>(
    'reps',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _loadKgMeta = const VerificationMeta('loadKg');
  @override
  late final GeneratedColumn<double> loadKg = GeneratedColumn<double>(
    'load_kg',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationSecMeta = const VerificationMeta(
    'durationSec',
  );
  @override
  late final GeneratedColumn<int> durationSec = GeneratedColumn<int>(
    'duration_sec',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _distanceMMeta = const VerificationMeta(
    'distanceM',
  );
  @override
  late final GeneratedColumn<int> distanceM = GeneratedColumn<int>(
    'distance_m',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rirMeta = const VerificationMeta('rir');
  @override
  late final GeneratedColumn<int> rir = GeneratedColumn<int>(
    'rir',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sideMeta = const VerificationMeta('side');
  @override
  late final GeneratedColumn<String> side = GeneratedColumn<String>(
    'side',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isWarmupMeta = const VerificationMeta(
    'isWarmup',
  );
  @override
  late final GeneratedColumn<bool> isWarmup = GeneratedColumn<bool>(
    'is_warmup',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_warmup" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    prescriptionId,
    exerciseId,
    setIndex,
    targetRepsMin,
    targetRepsMax,
    targetLoadKg,
    reps,
    loadKg,
    durationSec,
    distanceM,
    rir,
    side,
    isWarmup,
    completedAt,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'set_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<SetLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('prescription_id')) {
      context.handle(
        _prescriptionIdMeta,
        prescriptionId.isAcceptableOrUnknown(
          data['prescription_id']!,
          _prescriptionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_prescriptionIdMeta);
    }
    if (data.containsKey('exercise_id')) {
      context.handle(
        _exerciseIdMeta,
        exerciseId.isAcceptableOrUnknown(data['exercise_id']!, _exerciseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_exerciseIdMeta);
    }
    if (data.containsKey('set_index')) {
      context.handle(
        _setIndexMeta,
        setIndex.isAcceptableOrUnknown(data['set_index']!, _setIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_setIndexMeta);
    }
    if (data.containsKey('target_reps_min')) {
      context.handle(
        _targetRepsMinMeta,
        targetRepsMin.isAcceptableOrUnknown(
          data['target_reps_min']!,
          _targetRepsMinMeta,
        ),
      );
    }
    if (data.containsKey('target_reps_max')) {
      context.handle(
        _targetRepsMaxMeta,
        targetRepsMax.isAcceptableOrUnknown(
          data['target_reps_max']!,
          _targetRepsMaxMeta,
        ),
      );
    }
    if (data.containsKey('target_load_kg')) {
      context.handle(
        _targetLoadKgMeta,
        targetLoadKg.isAcceptableOrUnknown(
          data['target_load_kg']!,
          _targetLoadKgMeta,
        ),
      );
    }
    if (data.containsKey('reps')) {
      context.handle(
        _repsMeta,
        reps.isAcceptableOrUnknown(data['reps']!, _repsMeta),
      );
    }
    if (data.containsKey('load_kg')) {
      context.handle(
        _loadKgMeta,
        loadKg.isAcceptableOrUnknown(data['load_kg']!, _loadKgMeta),
      );
    }
    if (data.containsKey('duration_sec')) {
      context.handle(
        _durationSecMeta,
        durationSec.isAcceptableOrUnknown(
          data['duration_sec']!,
          _durationSecMeta,
        ),
      );
    }
    if (data.containsKey('distance_m')) {
      context.handle(
        _distanceMMeta,
        distanceM.isAcceptableOrUnknown(data['distance_m']!, _distanceMMeta),
      );
    }
    if (data.containsKey('rir')) {
      context.handle(
        _rirMeta,
        rir.isAcceptableOrUnknown(data['rir']!, _rirMeta),
      );
    }
    if (data.containsKey('side')) {
      context.handle(
        _sideMeta,
        side.isAcceptableOrUnknown(data['side']!, _sideMeta),
      );
    }
    if (data.containsKey('is_warmup')) {
      context.handle(
        _isWarmupMeta,
        isWarmup.isAcceptableOrUnknown(data['is_warmup']!, _isWarmupMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_completedAtMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SetLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SetLog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}session_id'],
      )!,
      prescriptionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prescription_id'],
      )!,
      exerciseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exercise_id'],
      )!,
      setIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}set_index'],
      )!,
      targetRepsMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_reps_min'],
      ),
      targetRepsMax: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_reps_max'],
      ),
      targetLoadKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}target_load_kg'],
      ),
      reps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reps'],
      ),
      loadKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}load_kg'],
      ),
      durationSec: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_sec'],
      ),
      distanceM: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}distance_m'],
      ),
      rir: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rir'],
      ),
      side: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}side'],
      ),
      isWarmup: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_warmup'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $SetLogsTable createAlias(String alias) {
    return $SetLogsTable(attachedDatabase, alias);
  }
}

class SetLog extends DataClass implements Insertable<SetLog> {
  final int id;
  final int sessionId;
  final String prescriptionId;
  final String exerciseId;
  final int setIndex;
  final int? targetRepsMin;
  final int? targetRepsMax;
  final double? targetLoadKg;
  final int? reps;
  final double? loadKg;
  final int? durationSec;
  final int? distanceM;
  final int? rir;

  /// Which side, for per-side prescriptions. Null for bilateral work.
  final String? side;

  /// Ramp sets are logged but excluded from every progression decision and
  /// every volume statistic.
  final bool isWarmup;
  final DateTime completedAt;
  final String? note;
  const SetLog({
    required this.id,
    required this.sessionId,
    required this.prescriptionId,
    required this.exerciseId,
    required this.setIndex,
    this.targetRepsMin,
    this.targetRepsMax,
    this.targetLoadKg,
    this.reps,
    this.loadKg,
    this.durationSec,
    this.distanceM,
    this.rir,
    this.side,
    required this.isWarmup,
    required this.completedAt,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['session_id'] = Variable<int>(sessionId);
    map['prescription_id'] = Variable<String>(prescriptionId);
    map['exercise_id'] = Variable<String>(exerciseId);
    map['set_index'] = Variable<int>(setIndex);
    if (!nullToAbsent || targetRepsMin != null) {
      map['target_reps_min'] = Variable<int>(targetRepsMin);
    }
    if (!nullToAbsent || targetRepsMax != null) {
      map['target_reps_max'] = Variable<int>(targetRepsMax);
    }
    if (!nullToAbsent || targetLoadKg != null) {
      map['target_load_kg'] = Variable<double>(targetLoadKg);
    }
    if (!nullToAbsent || reps != null) {
      map['reps'] = Variable<int>(reps);
    }
    if (!nullToAbsent || loadKg != null) {
      map['load_kg'] = Variable<double>(loadKg);
    }
    if (!nullToAbsent || durationSec != null) {
      map['duration_sec'] = Variable<int>(durationSec);
    }
    if (!nullToAbsent || distanceM != null) {
      map['distance_m'] = Variable<int>(distanceM);
    }
    if (!nullToAbsent || rir != null) {
      map['rir'] = Variable<int>(rir);
    }
    if (!nullToAbsent || side != null) {
      map['side'] = Variable<String>(side);
    }
    map['is_warmup'] = Variable<bool>(isWarmup);
    map['completed_at'] = Variable<DateTime>(completedAt);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  SetLogsCompanion toCompanion(bool nullToAbsent) {
    return SetLogsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      prescriptionId: Value(prescriptionId),
      exerciseId: Value(exerciseId),
      setIndex: Value(setIndex),
      targetRepsMin: targetRepsMin == null && nullToAbsent
          ? const Value.absent()
          : Value(targetRepsMin),
      targetRepsMax: targetRepsMax == null && nullToAbsent
          ? const Value.absent()
          : Value(targetRepsMax),
      targetLoadKg: targetLoadKg == null && nullToAbsent
          ? const Value.absent()
          : Value(targetLoadKg),
      reps: reps == null && nullToAbsent ? const Value.absent() : Value(reps),
      loadKg: loadKg == null && nullToAbsent
          ? const Value.absent()
          : Value(loadKg),
      durationSec: durationSec == null && nullToAbsent
          ? const Value.absent()
          : Value(durationSec),
      distanceM: distanceM == null && nullToAbsent
          ? const Value.absent()
          : Value(distanceM),
      rir: rir == null && nullToAbsent ? const Value.absent() : Value(rir),
      side: side == null && nullToAbsent ? const Value.absent() : Value(side),
      isWarmup: Value(isWarmup),
      completedAt: Value(completedAt),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory SetLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SetLog(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<int>(json['sessionId']),
      prescriptionId: serializer.fromJson<String>(json['prescriptionId']),
      exerciseId: serializer.fromJson<String>(json['exerciseId']),
      setIndex: serializer.fromJson<int>(json['setIndex']),
      targetRepsMin: serializer.fromJson<int?>(json['targetRepsMin']),
      targetRepsMax: serializer.fromJson<int?>(json['targetRepsMax']),
      targetLoadKg: serializer.fromJson<double?>(json['targetLoadKg']),
      reps: serializer.fromJson<int?>(json['reps']),
      loadKg: serializer.fromJson<double?>(json['loadKg']),
      durationSec: serializer.fromJson<int?>(json['durationSec']),
      distanceM: serializer.fromJson<int?>(json['distanceM']),
      rir: serializer.fromJson<int?>(json['rir']),
      side: serializer.fromJson<String?>(json['side']),
      isWarmup: serializer.fromJson<bool>(json['isWarmup']),
      completedAt: serializer.fromJson<DateTime>(json['completedAt']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<int>(sessionId),
      'prescriptionId': serializer.toJson<String>(prescriptionId),
      'exerciseId': serializer.toJson<String>(exerciseId),
      'setIndex': serializer.toJson<int>(setIndex),
      'targetRepsMin': serializer.toJson<int?>(targetRepsMin),
      'targetRepsMax': serializer.toJson<int?>(targetRepsMax),
      'targetLoadKg': serializer.toJson<double?>(targetLoadKg),
      'reps': serializer.toJson<int?>(reps),
      'loadKg': serializer.toJson<double?>(loadKg),
      'durationSec': serializer.toJson<int?>(durationSec),
      'distanceM': serializer.toJson<int?>(distanceM),
      'rir': serializer.toJson<int?>(rir),
      'side': serializer.toJson<String?>(side),
      'isWarmup': serializer.toJson<bool>(isWarmup),
      'completedAt': serializer.toJson<DateTime>(completedAt),
      'note': serializer.toJson<String?>(note),
    };
  }

  SetLog copyWith({
    int? id,
    int? sessionId,
    String? prescriptionId,
    String? exerciseId,
    int? setIndex,
    Value<int?> targetRepsMin = const Value.absent(),
    Value<int?> targetRepsMax = const Value.absent(),
    Value<double?> targetLoadKg = const Value.absent(),
    Value<int?> reps = const Value.absent(),
    Value<double?> loadKg = const Value.absent(),
    Value<int?> durationSec = const Value.absent(),
    Value<int?> distanceM = const Value.absent(),
    Value<int?> rir = const Value.absent(),
    Value<String?> side = const Value.absent(),
    bool? isWarmup,
    DateTime? completedAt,
    Value<String?> note = const Value.absent(),
  }) => SetLog(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    prescriptionId: prescriptionId ?? this.prescriptionId,
    exerciseId: exerciseId ?? this.exerciseId,
    setIndex: setIndex ?? this.setIndex,
    targetRepsMin: targetRepsMin.present
        ? targetRepsMin.value
        : this.targetRepsMin,
    targetRepsMax: targetRepsMax.present
        ? targetRepsMax.value
        : this.targetRepsMax,
    targetLoadKg: targetLoadKg.present ? targetLoadKg.value : this.targetLoadKg,
    reps: reps.present ? reps.value : this.reps,
    loadKg: loadKg.present ? loadKg.value : this.loadKg,
    durationSec: durationSec.present ? durationSec.value : this.durationSec,
    distanceM: distanceM.present ? distanceM.value : this.distanceM,
    rir: rir.present ? rir.value : this.rir,
    side: side.present ? side.value : this.side,
    isWarmup: isWarmup ?? this.isWarmup,
    completedAt: completedAt ?? this.completedAt,
    note: note.present ? note.value : this.note,
  );
  SetLog copyWithCompanion(SetLogsCompanion data) {
    return SetLog(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      prescriptionId: data.prescriptionId.present
          ? data.prescriptionId.value
          : this.prescriptionId,
      exerciseId: data.exerciseId.present
          ? data.exerciseId.value
          : this.exerciseId,
      setIndex: data.setIndex.present ? data.setIndex.value : this.setIndex,
      targetRepsMin: data.targetRepsMin.present
          ? data.targetRepsMin.value
          : this.targetRepsMin,
      targetRepsMax: data.targetRepsMax.present
          ? data.targetRepsMax.value
          : this.targetRepsMax,
      targetLoadKg: data.targetLoadKg.present
          ? data.targetLoadKg.value
          : this.targetLoadKg,
      reps: data.reps.present ? data.reps.value : this.reps,
      loadKg: data.loadKg.present ? data.loadKg.value : this.loadKg,
      durationSec: data.durationSec.present
          ? data.durationSec.value
          : this.durationSec,
      distanceM: data.distanceM.present ? data.distanceM.value : this.distanceM,
      rir: data.rir.present ? data.rir.value : this.rir,
      side: data.side.present ? data.side.value : this.side,
      isWarmup: data.isWarmup.present ? data.isWarmup.value : this.isWarmup,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SetLog(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('prescriptionId: $prescriptionId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('setIndex: $setIndex, ')
          ..write('targetRepsMin: $targetRepsMin, ')
          ..write('targetRepsMax: $targetRepsMax, ')
          ..write('targetLoadKg: $targetLoadKg, ')
          ..write('reps: $reps, ')
          ..write('loadKg: $loadKg, ')
          ..write('durationSec: $durationSec, ')
          ..write('distanceM: $distanceM, ')
          ..write('rir: $rir, ')
          ..write('side: $side, ')
          ..write('isWarmup: $isWarmup, ')
          ..write('completedAt: $completedAt, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    prescriptionId,
    exerciseId,
    setIndex,
    targetRepsMin,
    targetRepsMax,
    targetLoadKg,
    reps,
    loadKg,
    durationSec,
    distanceM,
    rir,
    side,
    isWarmup,
    completedAt,
    note,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SetLog &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.prescriptionId == this.prescriptionId &&
          other.exerciseId == this.exerciseId &&
          other.setIndex == this.setIndex &&
          other.targetRepsMin == this.targetRepsMin &&
          other.targetRepsMax == this.targetRepsMax &&
          other.targetLoadKg == this.targetLoadKg &&
          other.reps == this.reps &&
          other.loadKg == this.loadKg &&
          other.durationSec == this.durationSec &&
          other.distanceM == this.distanceM &&
          other.rir == this.rir &&
          other.side == this.side &&
          other.isWarmup == this.isWarmup &&
          other.completedAt == this.completedAt &&
          other.note == this.note);
}

class SetLogsCompanion extends UpdateCompanion<SetLog> {
  final Value<int> id;
  final Value<int> sessionId;
  final Value<String> prescriptionId;
  final Value<String> exerciseId;
  final Value<int> setIndex;
  final Value<int?> targetRepsMin;
  final Value<int?> targetRepsMax;
  final Value<double?> targetLoadKg;
  final Value<int?> reps;
  final Value<double?> loadKg;
  final Value<int?> durationSec;
  final Value<int?> distanceM;
  final Value<int?> rir;
  final Value<String?> side;
  final Value<bool> isWarmup;
  final Value<DateTime> completedAt;
  final Value<String?> note;
  const SetLogsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.prescriptionId = const Value.absent(),
    this.exerciseId = const Value.absent(),
    this.setIndex = const Value.absent(),
    this.targetRepsMin = const Value.absent(),
    this.targetRepsMax = const Value.absent(),
    this.targetLoadKg = const Value.absent(),
    this.reps = const Value.absent(),
    this.loadKg = const Value.absent(),
    this.durationSec = const Value.absent(),
    this.distanceM = const Value.absent(),
    this.rir = const Value.absent(),
    this.side = const Value.absent(),
    this.isWarmup = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.note = const Value.absent(),
  });
  SetLogsCompanion.insert({
    this.id = const Value.absent(),
    required int sessionId,
    required String prescriptionId,
    required String exerciseId,
    required int setIndex,
    this.targetRepsMin = const Value.absent(),
    this.targetRepsMax = const Value.absent(),
    this.targetLoadKg = const Value.absent(),
    this.reps = const Value.absent(),
    this.loadKg = const Value.absent(),
    this.durationSec = const Value.absent(),
    this.distanceM = const Value.absent(),
    this.rir = const Value.absent(),
    this.side = const Value.absent(),
    this.isWarmup = const Value.absent(),
    required DateTime completedAt,
    this.note = const Value.absent(),
  }) : sessionId = Value(sessionId),
       prescriptionId = Value(prescriptionId),
       exerciseId = Value(exerciseId),
       setIndex = Value(setIndex),
       completedAt = Value(completedAt);
  static Insertable<SetLog> custom({
    Expression<int>? id,
    Expression<int>? sessionId,
    Expression<String>? prescriptionId,
    Expression<String>? exerciseId,
    Expression<int>? setIndex,
    Expression<int>? targetRepsMin,
    Expression<int>? targetRepsMax,
    Expression<double>? targetLoadKg,
    Expression<int>? reps,
    Expression<double>? loadKg,
    Expression<int>? durationSec,
    Expression<int>? distanceM,
    Expression<int>? rir,
    Expression<String>? side,
    Expression<bool>? isWarmup,
    Expression<DateTime>? completedAt,
    Expression<String>? note,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (prescriptionId != null) 'prescription_id': prescriptionId,
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (setIndex != null) 'set_index': setIndex,
      if (targetRepsMin != null) 'target_reps_min': targetRepsMin,
      if (targetRepsMax != null) 'target_reps_max': targetRepsMax,
      if (targetLoadKg != null) 'target_load_kg': targetLoadKg,
      if (reps != null) 'reps': reps,
      if (loadKg != null) 'load_kg': loadKg,
      if (durationSec != null) 'duration_sec': durationSec,
      if (distanceM != null) 'distance_m': distanceM,
      if (rir != null) 'rir': rir,
      if (side != null) 'side': side,
      if (isWarmup != null) 'is_warmup': isWarmup,
      if (completedAt != null) 'completed_at': completedAt,
      if (note != null) 'note': note,
    });
  }

  SetLogsCompanion copyWith({
    Value<int>? id,
    Value<int>? sessionId,
    Value<String>? prescriptionId,
    Value<String>? exerciseId,
    Value<int>? setIndex,
    Value<int?>? targetRepsMin,
    Value<int?>? targetRepsMax,
    Value<double?>? targetLoadKg,
    Value<int?>? reps,
    Value<double?>? loadKg,
    Value<int?>? durationSec,
    Value<int?>? distanceM,
    Value<int?>? rir,
    Value<String?>? side,
    Value<bool>? isWarmup,
    Value<DateTime>? completedAt,
    Value<String?>? note,
  }) {
    return SetLogsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      prescriptionId: prescriptionId ?? this.prescriptionId,
      exerciseId: exerciseId ?? this.exerciseId,
      setIndex: setIndex ?? this.setIndex,
      targetRepsMin: targetRepsMin ?? this.targetRepsMin,
      targetRepsMax: targetRepsMax ?? this.targetRepsMax,
      targetLoadKg: targetLoadKg ?? this.targetLoadKg,
      reps: reps ?? this.reps,
      loadKg: loadKg ?? this.loadKg,
      durationSec: durationSec ?? this.durationSec,
      distanceM: distanceM ?? this.distanceM,
      rir: rir ?? this.rir,
      side: side ?? this.side,
      isWarmup: isWarmup ?? this.isWarmup,
      completedAt: completedAt ?? this.completedAt,
      note: note ?? this.note,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<int>(sessionId.value);
    }
    if (prescriptionId.present) {
      map['prescription_id'] = Variable<String>(prescriptionId.value);
    }
    if (exerciseId.present) {
      map['exercise_id'] = Variable<String>(exerciseId.value);
    }
    if (setIndex.present) {
      map['set_index'] = Variable<int>(setIndex.value);
    }
    if (targetRepsMin.present) {
      map['target_reps_min'] = Variable<int>(targetRepsMin.value);
    }
    if (targetRepsMax.present) {
      map['target_reps_max'] = Variable<int>(targetRepsMax.value);
    }
    if (targetLoadKg.present) {
      map['target_load_kg'] = Variable<double>(targetLoadKg.value);
    }
    if (reps.present) {
      map['reps'] = Variable<int>(reps.value);
    }
    if (loadKg.present) {
      map['load_kg'] = Variable<double>(loadKg.value);
    }
    if (durationSec.present) {
      map['duration_sec'] = Variable<int>(durationSec.value);
    }
    if (distanceM.present) {
      map['distance_m'] = Variable<int>(distanceM.value);
    }
    if (rir.present) {
      map['rir'] = Variable<int>(rir.value);
    }
    if (side.present) {
      map['side'] = Variable<String>(side.value);
    }
    if (isWarmup.present) {
      map['is_warmup'] = Variable<bool>(isWarmup.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SetLogsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('prescriptionId: $prescriptionId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('setIndex: $setIndex, ')
          ..write('targetRepsMin: $targetRepsMin, ')
          ..write('targetRepsMax: $targetRepsMax, ')
          ..write('targetLoadKg: $targetLoadKg, ')
          ..write('reps: $reps, ')
          ..write('loadKg: $loadKg, ')
          ..write('durationSec: $durationSec, ')
          ..write('distanceM: $distanceM, ')
          ..write('rir: $rir, ')
          ..write('side: $side, ')
          ..write('isWarmup: $isWarmup, ')
          ..write('completedAt: $completedAt, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }
}

class $StallCountersTable extends StallCounters
    with TableInfo<$StallCountersTable, StallCounter> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StallCountersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _exerciseIdMeta = const VerificationMeta(
    'exerciseId',
  );
  @override
  late final GeneratedColumn<String> exerciseId = GeneratedColumn<String>(
    'exercise_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _prescriptionIdMeta = const VerificationMeta(
    'prescriptionId',
  );
  @override
  late final GeneratedColumn<String> prescriptionId = GeneratedColumn<String>(
    'prescription_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _countMeta = const VerificationMeta('count');
  @override
  late final GeneratedColumn<int> count = GeneratedColumn<int>(
    'count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
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
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    exerciseId,
    prescriptionId,
    count,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stall_counters';
  @override
  VerificationContext validateIntegrity(
    Insertable<StallCounter> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('exercise_id')) {
      context.handle(
        _exerciseIdMeta,
        exerciseId.isAcceptableOrUnknown(data['exercise_id']!, _exerciseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_exerciseIdMeta);
    }
    if (data.containsKey('prescription_id')) {
      context.handle(
        _prescriptionIdMeta,
        prescriptionId.isAcceptableOrUnknown(
          data['prescription_id']!,
          _prescriptionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_prescriptionIdMeta);
    }
    if (data.containsKey('count')) {
      context.handle(
        _countMeta,
        count.isAcceptableOrUnknown(data['count']!, _countMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {exerciseId, prescriptionId};
  @override
  StallCounter map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StallCounter(
      exerciseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exercise_id'],
      )!,
      prescriptionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prescription_id'],
      )!,
      count: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}count'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $StallCountersTable createAlias(String alias) {
    return $StallCountersTable(attachedDatabase, alias);
  }
}

class StallCounter extends DataClass implements Insertable<StallCounter> {
  final String exerciseId;
  final String prescriptionId;
  final int count;
  final DateTime updatedAt;
  const StallCounter({
    required this.exerciseId,
    required this.prescriptionId,
    required this.count,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['exercise_id'] = Variable<String>(exerciseId);
    map['prescription_id'] = Variable<String>(prescriptionId);
    map['count'] = Variable<int>(count);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  StallCountersCompanion toCompanion(bool nullToAbsent) {
    return StallCountersCompanion(
      exerciseId: Value(exerciseId),
      prescriptionId: Value(prescriptionId),
      count: Value(count),
      updatedAt: Value(updatedAt),
    );
  }

  factory StallCounter.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StallCounter(
      exerciseId: serializer.fromJson<String>(json['exerciseId']),
      prescriptionId: serializer.fromJson<String>(json['prescriptionId']),
      count: serializer.fromJson<int>(json['count']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'exerciseId': serializer.toJson<String>(exerciseId),
      'prescriptionId': serializer.toJson<String>(prescriptionId),
      'count': serializer.toJson<int>(count),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  StallCounter copyWith({
    String? exerciseId,
    String? prescriptionId,
    int? count,
    DateTime? updatedAt,
  }) => StallCounter(
    exerciseId: exerciseId ?? this.exerciseId,
    prescriptionId: prescriptionId ?? this.prescriptionId,
    count: count ?? this.count,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StallCounter copyWithCompanion(StallCountersCompanion data) {
    return StallCounter(
      exerciseId: data.exerciseId.present
          ? data.exerciseId.value
          : this.exerciseId,
      prescriptionId: data.prescriptionId.present
          ? data.prescriptionId.value
          : this.prescriptionId,
      count: data.count.present ? data.count.value : this.count,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StallCounter(')
          ..write('exerciseId: $exerciseId, ')
          ..write('prescriptionId: $prescriptionId, ')
          ..write('count: $count, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(exerciseId, prescriptionId, count, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StallCounter &&
          other.exerciseId == this.exerciseId &&
          other.prescriptionId == this.prescriptionId &&
          other.count == this.count &&
          other.updatedAt == this.updatedAt);
}

class StallCountersCompanion extends UpdateCompanion<StallCounter> {
  final Value<String> exerciseId;
  final Value<String> prescriptionId;
  final Value<int> count;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const StallCountersCompanion({
    this.exerciseId = const Value.absent(),
    this.prescriptionId = const Value.absent(),
    this.count = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StallCountersCompanion.insert({
    required String exerciseId,
    required String prescriptionId,
    this.count = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : exerciseId = Value(exerciseId),
       prescriptionId = Value(prescriptionId),
       updatedAt = Value(updatedAt);
  static Insertable<StallCounter> custom({
    Expression<String>? exerciseId,
    Expression<String>? prescriptionId,
    Expression<int>? count,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (prescriptionId != null) 'prescription_id': prescriptionId,
      if (count != null) 'count': count,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StallCountersCompanion copyWith({
    Value<String>? exerciseId,
    Value<String>? prescriptionId,
    Value<int>? count,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return StallCountersCompanion(
      exerciseId: exerciseId ?? this.exerciseId,
      prescriptionId: prescriptionId ?? this.prescriptionId,
      count: count ?? this.count,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (exerciseId.present) {
      map['exercise_id'] = Variable<String>(exerciseId.value);
    }
    if (prescriptionId.present) {
      map['prescription_id'] = Variable<String>(prescriptionId.value);
    }
    if (count.present) {
      map['count'] = Variable<int>(count.value);
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
    return (StringBuffer('StallCountersCompanion(')
          ..write('exerciseId: $exerciseId, ')
          ..write('prescriptionId: $prescriptionId, ')
          ..write('count: $count, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BodyweightsTable extends Bodyweights
    with TableInfo<$BodyweightsTable, Bodyweight> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BodyweightsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _measuredOnMeta = const VerificationMeta(
    'measuredOn',
  );
  @override
  late final GeneratedColumn<DateTime> measuredOn = GeneratedColumn<DateTime>(
    'measured_on',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kgMeta = const VerificationMeta('kg');
  @override
  late final GeneratedColumn<double> kg = GeneratedColumn<double>(
    'kg',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [measuredOn, kg, note];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bodyweights';
  @override
  VerificationContext validateIntegrity(
    Insertable<Bodyweight> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('measured_on')) {
      context.handle(
        _measuredOnMeta,
        measuredOn.isAcceptableOrUnknown(data['measured_on']!, _measuredOnMeta),
      );
    } else if (isInserting) {
      context.missing(_measuredOnMeta);
    }
    if (data.containsKey('kg')) {
      context.handle(_kgMeta, kg.isAcceptableOrUnknown(data['kg']!, _kgMeta));
    } else if (isInserting) {
      context.missing(_kgMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {measuredOn};
  @override
  Bodyweight map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Bodyweight(
      measuredOn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}measured_on'],
      )!,
      kg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}kg'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $BodyweightsTable createAlias(String alias) {
    return $BodyweightsTable(attachedDatabase, alias);
  }
}

class Bodyweight extends DataClass implements Insertable<Bodyweight> {
  final DateTime measuredOn;
  final double kg;
  final String? note;
  const Bodyweight({required this.measuredOn, required this.kg, this.note});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['measured_on'] = Variable<DateTime>(measuredOn);
    map['kg'] = Variable<double>(kg);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  BodyweightsCompanion toCompanion(bool nullToAbsent) {
    return BodyweightsCompanion(
      measuredOn: Value(measuredOn),
      kg: Value(kg),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory Bodyweight.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Bodyweight(
      measuredOn: serializer.fromJson<DateTime>(json['measuredOn']),
      kg: serializer.fromJson<double>(json['kg']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'measuredOn': serializer.toJson<DateTime>(measuredOn),
      'kg': serializer.toJson<double>(kg),
      'note': serializer.toJson<String?>(note),
    };
  }

  Bodyweight copyWith({
    DateTime? measuredOn,
    double? kg,
    Value<String?> note = const Value.absent(),
  }) => Bodyweight(
    measuredOn: measuredOn ?? this.measuredOn,
    kg: kg ?? this.kg,
    note: note.present ? note.value : this.note,
  );
  Bodyweight copyWithCompanion(BodyweightsCompanion data) {
    return Bodyweight(
      measuredOn: data.measuredOn.present
          ? data.measuredOn.value
          : this.measuredOn,
      kg: data.kg.present ? data.kg.value : this.kg,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Bodyweight(')
          ..write('measuredOn: $measuredOn, ')
          ..write('kg: $kg, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(measuredOn, kg, note);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Bodyweight &&
          other.measuredOn == this.measuredOn &&
          other.kg == this.kg &&
          other.note == this.note);
}

class BodyweightsCompanion extends UpdateCompanion<Bodyweight> {
  final Value<DateTime> measuredOn;
  final Value<double> kg;
  final Value<String?> note;
  final Value<int> rowid;
  const BodyweightsCompanion({
    this.measuredOn = const Value.absent(),
    this.kg = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BodyweightsCompanion.insert({
    required DateTime measuredOn,
    required double kg,
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : measuredOn = Value(measuredOn),
       kg = Value(kg);
  static Insertable<Bodyweight> custom({
    Expression<DateTime>? measuredOn,
    Expression<double>? kg,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (measuredOn != null) 'measured_on': measuredOn,
      if (kg != null) 'kg': kg,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BodyweightsCompanion copyWith({
    Value<DateTime>? measuredOn,
    Value<double>? kg,
    Value<String?>? note,
    Value<int>? rowid,
  }) {
    return BodyweightsCompanion(
      measuredOn: measuredOn ?? this.measuredOn,
      kg: kg ?? this.kg,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (measuredOn.present) {
      map['measured_on'] = Variable<DateTime>(measuredOn.value);
    }
    if (kg.present) {
      map['kg'] = Variable<double>(kg.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BodyweightsCompanion(')
          ..write('measuredOn: $measuredOn, ')
          ..write('kg: $kg, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CardioLogsTable extends CardioLogs
    with TableInfo<$CardioLogsTable, CardioLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CardioLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<int> sessionId = GeneratedColumn<int>(
    'session_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<CardioKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<CardioKind>($CardioLogsTable.$converterkind);
  static const VerificationMeta _measuredOnMeta = const VerificationMeta(
    'measuredOn',
  );
  @override
  late final GeneratedColumn<DateTime> measuredOn = GeneratedColumn<DateTime>(
    'measured_on',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationSecMeta = const VerificationMeta(
    'durationSec',
  );
  @override
  late final GeneratedColumn<int> durationSec = GeneratedColumn<int>(
    'duration_sec',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _distanceMMeta = const VerificationMeta(
    'distanceM',
  );
  @override
  late final GeneratedColumn<int> distanceM = GeneratedColumn<int>(
    'distance_m',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _roundsMeta = const VerificationMeta('rounds');
  @override
  late final GeneratedColumn<int> rounds = GeneratedColumn<int>(
    'rounds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _effortMeta = const VerificationMeta('effort');
  @override
  late final GeneratedColumn<int> effort = GeneratedColumn<int>(
    'effort',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    kind,
    measuredOn,
    durationSec,
    distanceM,
    rounds,
    effort,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cardio_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<CardioLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    }
    if (data.containsKey('measured_on')) {
      context.handle(
        _measuredOnMeta,
        measuredOn.isAcceptableOrUnknown(data['measured_on']!, _measuredOnMeta),
      );
    } else if (isInserting) {
      context.missing(_measuredOnMeta);
    }
    if (data.containsKey('duration_sec')) {
      context.handle(
        _durationSecMeta,
        durationSec.isAcceptableOrUnknown(
          data['duration_sec']!,
          _durationSecMeta,
        ),
      );
    }
    if (data.containsKey('distance_m')) {
      context.handle(
        _distanceMMeta,
        distanceM.isAcceptableOrUnknown(data['distance_m']!, _distanceMMeta),
      );
    }
    if (data.containsKey('rounds')) {
      context.handle(
        _roundsMeta,
        rounds.isAcceptableOrUnknown(data['rounds']!, _roundsMeta),
      );
    }
    if (data.containsKey('effort')) {
      context.handle(
        _effortMeta,
        effort.isAcceptableOrUnknown(data['effort']!, _effortMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CardioLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CardioLog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}session_id'],
      ),
      kind: $CardioLogsTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      measuredOn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}measured_on'],
      )!,
      durationSec: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_sec'],
      ),
      distanceM: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}distance_m'],
      ),
      rounds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rounds'],
      ),
      effort: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}effort'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $CardioLogsTable createAlias(String alias) {
    return $CardioLogsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<CardioKind, String, String> $converterkind =
      const EnumNameConverter<CardioKind>(CardioKind.values);
}

class CardioLog extends DataClass implements Insertable<CardioLog> {
  final int id;
  final int? sessionId;
  final CardioKind kind;
  final DateTime measuredOn;
  final int? durationSec;
  final int? distanceM;
  final int? rounds;
  final int? effort;
  final String? note;
  const CardioLog({
    required this.id,
    this.sessionId,
    required this.kind,
    required this.measuredOn,
    this.durationSec,
    this.distanceM,
    this.rounds,
    this.effort,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || sessionId != null) {
      map['session_id'] = Variable<int>(sessionId);
    }
    {
      map['kind'] = Variable<String>(
        $CardioLogsTable.$converterkind.toSql(kind),
      );
    }
    map['measured_on'] = Variable<DateTime>(measuredOn);
    if (!nullToAbsent || durationSec != null) {
      map['duration_sec'] = Variable<int>(durationSec);
    }
    if (!nullToAbsent || distanceM != null) {
      map['distance_m'] = Variable<int>(distanceM);
    }
    if (!nullToAbsent || rounds != null) {
      map['rounds'] = Variable<int>(rounds);
    }
    if (!nullToAbsent || effort != null) {
      map['effort'] = Variable<int>(effort);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  CardioLogsCompanion toCompanion(bool nullToAbsent) {
    return CardioLogsCompanion(
      id: Value(id),
      sessionId: sessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sessionId),
      kind: Value(kind),
      measuredOn: Value(measuredOn),
      durationSec: durationSec == null && nullToAbsent
          ? const Value.absent()
          : Value(durationSec),
      distanceM: distanceM == null && nullToAbsent
          ? const Value.absent()
          : Value(distanceM),
      rounds: rounds == null && nullToAbsent
          ? const Value.absent()
          : Value(rounds),
      effort: effort == null && nullToAbsent
          ? const Value.absent()
          : Value(effort),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory CardioLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CardioLog(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<int?>(json['sessionId']),
      kind: $CardioLogsTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      measuredOn: serializer.fromJson<DateTime>(json['measuredOn']),
      durationSec: serializer.fromJson<int?>(json['durationSec']),
      distanceM: serializer.fromJson<int?>(json['distanceM']),
      rounds: serializer.fromJson<int?>(json['rounds']),
      effort: serializer.fromJson<int?>(json['effort']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<int?>(sessionId),
      'kind': serializer.toJson<String>(
        $CardioLogsTable.$converterkind.toJson(kind),
      ),
      'measuredOn': serializer.toJson<DateTime>(measuredOn),
      'durationSec': serializer.toJson<int?>(durationSec),
      'distanceM': serializer.toJson<int?>(distanceM),
      'rounds': serializer.toJson<int?>(rounds),
      'effort': serializer.toJson<int?>(effort),
      'note': serializer.toJson<String?>(note),
    };
  }

  CardioLog copyWith({
    int? id,
    Value<int?> sessionId = const Value.absent(),
    CardioKind? kind,
    DateTime? measuredOn,
    Value<int?> durationSec = const Value.absent(),
    Value<int?> distanceM = const Value.absent(),
    Value<int?> rounds = const Value.absent(),
    Value<int?> effort = const Value.absent(),
    Value<String?> note = const Value.absent(),
  }) => CardioLog(
    id: id ?? this.id,
    sessionId: sessionId.present ? sessionId.value : this.sessionId,
    kind: kind ?? this.kind,
    measuredOn: measuredOn ?? this.measuredOn,
    durationSec: durationSec.present ? durationSec.value : this.durationSec,
    distanceM: distanceM.present ? distanceM.value : this.distanceM,
    rounds: rounds.present ? rounds.value : this.rounds,
    effort: effort.present ? effort.value : this.effort,
    note: note.present ? note.value : this.note,
  );
  CardioLog copyWithCompanion(CardioLogsCompanion data) {
    return CardioLog(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      kind: data.kind.present ? data.kind.value : this.kind,
      measuredOn: data.measuredOn.present
          ? data.measuredOn.value
          : this.measuredOn,
      durationSec: data.durationSec.present
          ? data.durationSec.value
          : this.durationSec,
      distanceM: data.distanceM.present ? data.distanceM.value : this.distanceM,
      rounds: data.rounds.present ? data.rounds.value : this.rounds,
      effort: data.effort.present ? data.effort.value : this.effort,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CardioLog(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('kind: $kind, ')
          ..write('measuredOn: $measuredOn, ')
          ..write('durationSec: $durationSec, ')
          ..write('distanceM: $distanceM, ')
          ..write('rounds: $rounds, ')
          ..write('effort: $effort, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    kind,
    measuredOn,
    durationSec,
    distanceM,
    rounds,
    effort,
    note,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CardioLog &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.kind == this.kind &&
          other.measuredOn == this.measuredOn &&
          other.durationSec == this.durationSec &&
          other.distanceM == this.distanceM &&
          other.rounds == this.rounds &&
          other.effort == this.effort &&
          other.note == this.note);
}

class CardioLogsCompanion extends UpdateCompanion<CardioLog> {
  final Value<int> id;
  final Value<int?> sessionId;
  final Value<CardioKind> kind;
  final Value<DateTime> measuredOn;
  final Value<int?> durationSec;
  final Value<int?> distanceM;
  final Value<int?> rounds;
  final Value<int?> effort;
  final Value<String?> note;
  const CardioLogsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.kind = const Value.absent(),
    this.measuredOn = const Value.absent(),
    this.durationSec = const Value.absent(),
    this.distanceM = const Value.absent(),
    this.rounds = const Value.absent(),
    this.effort = const Value.absent(),
    this.note = const Value.absent(),
  });
  CardioLogsCompanion.insert({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    required CardioKind kind,
    required DateTime measuredOn,
    this.durationSec = const Value.absent(),
    this.distanceM = const Value.absent(),
    this.rounds = const Value.absent(),
    this.effort = const Value.absent(),
    this.note = const Value.absent(),
  }) : kind = Value(kind),
       measuredOn = Value(measuredOn);
  static Insertable<CardioLog> custom({
    Expression<int>? id,
    Expression<int>? sessionId,
    Expression<String>? kind,
    Expression<DateTime>? measuredOn,
    Expression<int>? durationSec,
    Expression<int>? distanceM,
    Expression<int>? rounds,
    Expression<int>? effort,
    Expression<String>? note,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (kind != null) 'kind': kind,
      if (measuredOn != null) 'measured_on': measuredOn,
      if (durationSec != null) 'duration_sec': durationSec,
      if (distanceM != null) 'distance_m': distanceM,
      if (rounds != null) 'rounds': rounds,
      if (effort != null) 'effort': effort,
      if (note != null) 'note': note,
    });
  }

  CardioLogsCompanion copyWith({
    Value<int>? id,
    Value<int?>? sessionId,
    Value<CardioKind>? kind,
    Value<DateTime>? measuredOn,
    Value<int?>? durationSec,
    Value<int?>? distanceM,
    Value<int?>? rounds,
    Value<int?>? effort,
    Value<String?>? note,
  }) {
    return CardioLogsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      kind: kind ?? this.kind,
      measuredOn: measuredOn ?? this.measuredOn,
      durationSec: durationSec ?? this.durationSec,
      distanceM: distanceM ?? this.distanceM,
      rounds: rounds ?? this.rounds,
      effort: effort ?? this.effort,
      note: note ?? this.note,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<int>(sessionId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $CardioLogsTable.$converterkind.toSql(kind.value),
      );
    }
    if (measuredOn.present) {
      map['measured_on'] = Variable<DateTime>(measuredOn.value);
    }
    if (durationSec.present) {
      map['duration_sec'] = Variable<int>(durationSec.value);
    }
    if (distanceM.present) {
      map['distance_m'] = Variable<int>(distanceM.value);
    }
    if (rounds.present) {
      map['rounds'] = Variable<int>(rounds.value);
    }
    if (effort.present) {
      map['effort'] = Variable<int>(effort.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CardioLogsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('kind: $kind, ')
          ..write('measuredOn: $measuredOn, ')
          ..write('durationSec: $durationSec, ')
          ..write('distanceM: $distanceM, ')
          ..write('rounds: $rounds, ')
          ..write('effort: $effort, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }
}

class $FoodLogsTable extends FoodLogs with TableInfo<$FoodLogsTable, FoodLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FoodLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _loggedOnMeta = const VerificationMeta(
    'loggedOn',
  );
  @override
  late final GeneratedColumn<DateTime> loggedOn = GeneratedColumn<DateTime>(
    'logged_on',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kcalMeta = const VerificationMeta('kcal');
  @override
  late final GeneratedColumn<int> kcal = GeneratedColumn<int>(
    'kcal',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _proteinGMeta = const VerificationMeta(
    'proteinG',
  );
  @override
  late final GeneratedColumn<int> proteinG = GeneratedColumn<int>(
    'protein_g',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hitTargetMeta = const VerificationMeta(
    'hitTarget',
  );
  @override
  late final GeneratedColumn<bool> hitTarget = GeneratedColumn<bool>(
    'hit_target',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("hit_target" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    loggedOn,
    kcal,
    proteinG,
    hitTarget,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'food_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<FoodLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('logged_on')) {
      context.handle(
        _loggedOnMeta,
        loggedOn.isAcceptableOrUnknown(data['logged_on']!, _loggedOnMeta),
      );
    } else if (isInserting) {
      context.missing(_loggedOnMeta);
    }
    if (data.containsKey('kcal')) {
      context.handle(
        _kcalMeta,
        kcal.isAcceptableOrUnknown(data['kcal']!, _kcalMeta),
      );
    }
    if (data.containsKey('protein_g')) {
      context.handle(
        _proteinGMeta,
        proteinG.isAcceptableOrUnknown(data['protein_g']!, _proteinGMeta),
      );
    }
    if (data.containsKey('hit_target')) {
      context.handle(
        _hitTargetMeta,
        hitTarget.isAcceptableOrUnknown(data['hit_target']!, _hitTargetMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {loggedOn};
  @override
  FoodLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FoodLog(
      loggedOn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}logged_on'],
      )!,
      kcal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}kcal'],
      ),
      proteinG: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}protein_g'],
      ),
      hitTarget: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}hit_target'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $FoodLogsTable createAlias(String alias) {
    return $FoodLogsTable(attachedDatabase, alias);
  }
}

class FoodLog extends DataClass implements Insertable<FoodLog> {
  final DateTime loggedOn;
  final int? kcal;
  final int? proteinG;
  final bool hitTarget;
  final String? note;
  const FoodLog({
    required this.loggedOn,
    this.kcal,
    this.proteinG,
    required this.hitTarget,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['logged_on'] = Variable<DateTime>(loggedOn);
    if (!nullToAbsent || kcal != null) {
      map['kcal'] = Variable<int>(kcal);
    }
    if (!nullToAbsent || proteinG != null) {
      map['protein_g'] = Variable<int>(proteinG);
    }
    map['hit_target'] = Variable<bool>(hitTarget);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  FoodLogsCompanion toCompanion(bool nullToAbsent) {
    return FoodLogsCompanion(
      loggedOn: Value(loggedOn),
      kcal: kcal == null && nullToAbsent ? const Value.absent() : Value(kcal),
      proteinG: proteinG == null && nullToAbsent
          ? const Value.absent()
          : Value(proteinG),
      hitTarget: Value(hitTarget),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory FoodLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FoodLog(
      loggedOn: serializer.fromJson<DateTime>(json['loggedOn']),
      kcal: serializer.fromJson<int?>(json['kcal']),
      proteinG: serializer.fromJson<int?>(json['proteinG']),
      hitTarget: serializer.fromJson<bool>(json['hitTarget']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'loggedOn': serializer.toJson<DateTime>(loggedOn),
      'kcal': serializer.toJson<int?>(kcal),
      'proteinG': serializer.toJson<int?>(proteinG),
      'hitTarget': serializer.toJson<bool>(hitTarget),
      'note': serializer.toJson<String?>(note),
    };
  }

  FoodLog copyWith({
    DateTime? loggedOn,
    Value<int?> kcal = const Value.absent(),
    Value<int?> proteinG = const Value.absent(),
    bool? hitTarget,
    Value<String?> note = const Value.absent(),
  }) => FoodLog(
    loggedOn: loggedOn ?? this.loggedOn,
    kcal: kcal.present ? kcal.value : this.kcal,
    proteinG: proteinG.present ? proteinG.value : this.proteinG,
    hitTarget: hitTarget ?? this.hitTarget,
    note: note.present ? note.value : this.note,
  );
  FoodLog copyWithCompanion(FoodLogsCompanion data) {
    return FoodLog(
      loggedOn: data.loggedOn.present ? data.loggedOn.value : this.loggedOn,
      kcal: data.kcal.present ? data.kcal.value : this.kcal,
      proteinG: data.proteinG.present ? data.proteinG.value : this.proteinG,
      hitTarget: data.hitTarget.present ? data.hitTarget.value : this.hitTarget,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FoodLog(')
          ..write('loggedOn: $loggedOn, ')
          ..write('kcal: $kcal, ')
          ..write('proteinG: $proteinG, ')
          ..write('hitTarget: $hitTarget, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(loggedOn, kcal, proteinG, hitTarget, note);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FoodLog &&
          other.loggedOn == this.loggedOn &&
          other.kcal == this.kcal &&
          other.proteinG == this.proteinG &&
          other.hitTarget == this.hitTarget &&
          other.note == this.note);
}

class FoodLogsCompanion extends UpdateCompanion<FoodLog> {
  final Value<DateTime> loggedOn;
  final Value<int?> kcal;
  final Value<int?> proteinG;
  final Value<bool> hitTarget;
  final Value<String?> note;
  final Value<int> rowid;
  const FoodLogsCompanion({
    this.loggedOn = const Value.absent(),
    this.kcal = const Value.absent(),
    this.proteinG = const Value.absent(),
    this.hitTarget = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FoodLogsCompanion.insert({
    required DateTime loggedOn,
    this.kcal = const Value.absent(),
    this.proteinG = const Value.absent(),
    this.hitTarget = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : loggedOn = Value(loggedOn);
  static Insertable<FoodLog> custom({
    Expression<DateTime>? loggedOn,
    Expression<int>? kcal,
    Expression<int>? proteinG,
    Expression<bool>? hitTarget,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (loggedOn != null) 'logged_on': loggedOn,
      if (kcal != null) 'kcal': kcal,
      if (proteinG != null) 'protein_g': proteinG,
      if (hitTarget != null) 'hit_target': hitTarget,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FoodLogsCompanion copyWith({
    Value<DateTime>? loggedOn,
    Value<int?>? kcal,
    Value<int?>? proteinG,
    Value<bool>? hitTarget,
    Value<String?>? note,
    Value<int>? rowid,
  }) {
    return FoodLogsCompanion(
      loggedOn: loggedOn ?? this.loggedOn,
      kcal: kcal ?? this.kcal,
      proteinG: proteinG ?? this.proteinG,
      hitTarget: hitTarget ?? this.hitTarget,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (loggedOn.present) {
      map['logged_on'] = Variable<DateTime>(loggedOn.value);
    }
    if (kcal.present) {
      map['kcal'] = Variable<int>(kcal.value);
    }
    if (proteinG.present) {
      map['protein_g'] = Variable<int>(proteinG.value);
    }
    if (hitTarget.present) {
      map['hit_target'] = Variable<bool>(hitTarget.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FoodLogsCompanion(')
          ..write('loggedOn: $loggedOn, ')
          ..write('kcal: $kcal, ')
          ..write('proteinG: $proteinG, ')
          ..write('hitTarget: $hitTarget, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NigglesTable extends Niggles with TableInfo<$NigglesTable, Niggle> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NigglesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _loggedOnMeta = const VerificationMeta(
    'loggedOn',
  );
  @override
  late final GeneratedColumn<DateTime> loggedOn = GeneratedColumn<DateTime>(
    'logged_on',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exerciseIdMeta = const VerificationMeta(
    'exerciseId',
  );
  @override
  late final GeneratedColumn<String> exerciseId = GeneratedColumn<String>(
    'exercise_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<int> sessionId = GeneratedColumn<int>(
    'session_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<NiggleSite, String> site =
      GeneratedColumn<String>(
        'site',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<NiggleSite>($NigglesTable.$convertersite);
  static const VerificationMeta _severityMeta = const VerificationMeta(
    'severity',
  );
  @override
  late final GeneratedColumn<int> severity = GeneratedColumn<int>(
    'severity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resolvedOnMeta = const VerificationMeta(
    'resolvedOn',
  );
  @override
  late final GeneratedColumn<DateTime> resolvedOn = GeneratedColumn<DateTime>(
    'resolved_on',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    loggedOn,
    exerciseId,
    sessionId,
    site,
    severity,
    note,
    resolvedOn,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'niggles';
  @override
  VerificationContext validateIntegrity(
    Insertable<Niggle> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('logged_on')) {
      context.handle(
        _loggedOnMeta,
        loggedOn.isAcceptableOrUnknown(data['logged_on']!, _loggedOnMeta),
      );
    } else if (isInserting) {
      context.missing(_loggedOnMeta);
    }
    if (data.containsKey('exercise_id')) {
      context.handle(
        _exerciseIdMeta,
        exerciseId.isAcceptableOrUnknown(data['exercise_id']!, _exerciseIdMeta),
      );
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    }
    if (data.containsKey('severity')) {
      context.handle(
        _severityMeta,
        severity.isAcceptableOrUnknown(data['severity']!, _severityMeta),
      );
    } else if (isInserting) {
      context.missing(_severityMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('resolved_on')) {
      context.handle(
        _resolvedOnMeta,
        resolvedOn.isAcceptableOrUnknown(data['resolved_on']!, _resolvedOnMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Niggle map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Niggle(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      loggedOn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}logged_on'],
      )!,
      exerciseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exercise_id'],
      ),
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}session_id'],
      ),
      site: $NigglesTable.$convertersite.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}site'],
        )!,
      ),
      severity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}severity'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      resolvedOn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}resolved_on'],
      ),
    );
  }

  @override
  $NigglesTable createAlias(String alias) {
    return $NigglesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<NiggleSite, String, String> $convertersite =
      const EnumNameConverter<NiggleSite>(NiggleSite.values);
}

class Niggle extends DataClass implements Insertable<Niggle> {
  final int id;
  final DateTime loggedOn;
  final String? exerciseId;
  final int? sessionId;
  final NiggleSite site;

  /// 1 = noticed it, 5 = stopped the session.
  final int severity;
  final String? note;
  final DateTime? resolvedOn;
  const Niggle({
    required this.id,
    required this.loggedOn,
    this.exerciseId,
    this.sessionId,
    required this.site,
    required this.severity,
    this.note,
    this.resolvedOn,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['logged_on'] = Variable<DateTime>(loggedOn);
    if (!nullToAbsent || exerciseId != null) {
      map['exercise_id'] = Variable<String>(exerciseId);
    }
    if (!nullToAbsent || sessionId != null) {
      map['session_id'] = Variable<int>(sessionId);
    }
    {
      map['site'] = Variable<String>($NigglesTable.$convertersite.toSql(site));
    }
    map['severity'] = Variable<int>(severity);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || resolvedOn != null) {
      map['resolved_on'] = Variable<DateTime>(resolvedOn);
    }
    return map;
  }

  NigglesCompanion toCompanion(bool nullToAbsent) {
    return NigglesCompanion(
      id: Value(id),
      loggedOn: Value(loggedOn),
      exerciseId: exerciseId == null && nullToAbsent
          ? const Value.absent()
          : Value(exerciseId),
      sessionId: sessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sessionId),
      site: Value(site),
      severity: Value(severity),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      resolvedOn: resolvedOn == null && nullToAbsent
          ? const Value.absent()
          : Value(resolvedOn),
    );
  }

  factory Niggle.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Niggle(
      id: serializer.fromJson<int>(json['id']),
      loggedOn: serializer.fromJson<DateTime>(json['loggedOn']),
      exerciseId: serializer.fromJson<String?>(json['exerciseId']),
      sessionId: serializer.fromJson<int?>(json['sessionId']),
      site: $NigglesTable.$convertersite.fromJson(
        serializer.fromJson<String>(json['site']),
      ),
      severity: serializer.fromJson<int>(json['severity']),
      note: serializer.fromJson<String?>(json['note']),
      resolvedOn: serializer.fromJson<DateTime?>(json['resolvedOn']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'loggedOn': serializer.toJson<DateTime>(loggedOn),
      'exerciseId': serializer.toJson<String?>(exerciseId),
      'sessionId': serializer.toJson<int?>(sessionId),
      'site': serializer.toJson<String>(
        $NigglesTable.$convertersite.toJson(site),
      ),
      'severity': serializer.toJson<int>(severity),
      'note': serializer.toJson<String?>(note),
      'resolvedOn': serializer.toJson<DateTime?>(resolvedOn),
    };
  }

  Niggle copyWith({
    int? id,
    DateTime? loggedOn,
    Value<String?> exerciseId = const Value.absent(),
    Value<int?> sessionId = const Value.absent(),
    NiggleSite? site,
    int? severity,
    Value<String?> note = const Value.absent(),
    Value<DateTime?> resolvedOn = const Value.absent(),
  }) => Niggle(
    id: id ?? this.id,
    loggedOn: loggedOn ?? this.loggedOn,
    exerciseId: exerciseId.present ? exerciseId.value : this.exerciseId,
    sessionId: sessionId.present ? sessionId.value : this.sessionId,
    site: site ?? this.site,
    severity: severity ?? this.severity,
    note: note.present ? note.value : this.note,
    resolvedOn: resolvedOn.present ? resolvedOn.value : this.resolvedOn,
  );
  Niggle copyWithCompanion(NigglesCompanion data) {
    return Niggle(
      id: data.id.present ? data.id.value : this.id,
      loggedOn: data.loggedOn.present ? data.loggedOn.value : this.loggedOn,
      exerciseId: data.exerciseId.present
          ? data.exerciseId.value
          : this.exerciseId,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      site: data.site.present ? data.site.value : this.site,
      severity: data.severity.present ? data.severity.value : this.severity,
      note: data.note.present ? data.note.value : this.note,
      resolvedOn: data.resolvedOn.present
          ? data.resolvedOn.value
          : this.resolvedOn,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Niggle(')
          ..write('id: $id, ')
          ..write('loggedOn: $loggedOn, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('sessionId: $sessionId, ')
          ..write('site: $site, ')
          ..write('severity: $severity, ')
          ..write('note: $note, ')
          ..write('resolvedOn: $resolvedOn')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    loggedOn,
    exerciseId,
    sessionId,
    site,
    severity,
    note,
    resolvedOn,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Niggle &&
          other.id == this.id &&
          other.loggedOn == this.loggedOn &&
          other.exerciseId == this.exerciseId &&
          other.sessionId == this.sessionId &&
          other.site == this.site &&
          other.severity == this.severity &&
          other.note == this.note &&
          other.resolvedOn == this.resolvedOn);
}

class NigglesCompanion extends UpdateCompanion<Niggle> {
  final Value<int> id;
  final Value<DateTime> loggedOn;
  final Value<String?> exerciseId;
  final Value<int?> sessionId;
  final Value<NiggleSite> site;
  final Value<int> severity;
  final Value<String?> note;
  final Value<DateTime?> resolvedOn;
  const NigglesCompanion({
    this.id = const Value.absent(),
    this.loggedOn = const Value.absent(),
    this.exerciseId = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.site = const Value.absent(),
    this.severity = const Value.absent(),
    this.note = const Value.absent(),
    this.resolvedOn = const Value.absent(),
  });
  NigglesCompanion.insert({
    this.id = const Value.absent(),
    required DateTime loggedOn,
    this.exerciseId = const Value.absent(),
    this.sessionId = const Value.absent(),
    required NiggleSite site,
    required int severity,
    this.note = const Value.absent(),
    this.resolvedOn = const Value.absent(),
  }) : loggedOn = Value(loggedOn),
       site = Value(site),
       severity = Value(severity);
  static Insertable<Niggle> custom({
    Expression<int>? id,
    Expression<DateTime>? loggedOn,
    Expression<String>? exerciseId,
    Expression<int>? sessionId,
    Expression<String>? site,
    Expression<int>? severity,
    Expression<String>? note,
    Expression<DateTime>? resolvedOn,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (loggedOn != null) 'logged_on': loggedOn,
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (sessionId != null) 'session_id': sessionId,
      if (site != null) 'site': site,
      if (severity != null) 'severity': severity,
      if (note != null) 'note': note,
      if (resolvedOn != null) 'resolved_on': resolvedOn,
    });
  }

  NigglesCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? loggedOn,
    Value<String?>? exerciseId,
    Value<int?>? sessionId,
    Value<NiggleSite>? site,
    Value<int>? severity,
    Value<String?>? note,
    Value<DateTime?>? resolvedOn,
  }) {
    return NigglesCompanion(
      id: id ?? this.id,
      loggedOn: loggedOn ?? this.loggedOn,
      exerciseId: exerciseId ?? this.exerciseId,
      sessionId: sessionId ?? this.sessionId,
      site: site ?? this.site,
      severity: severity ?? this.severity,
      note: note ?? this.note,
      resolvedOn: resolvedOn ?? this.resolvedOn,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (loggedOn.present) {
      map['logged_on'] = Variable<DateTime>(loggedOn.value);
    }
    if (exerciseId.present) {
      map['exercise_id'] = Variable<String>(exerciseId.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<int>(sessionId.value);
    }
    if (site.present) {
      map['site'] = Variable<String>(
        $NigglesTable.$convertersite.toSql(site.value),
      );
    }
    if (severity.present) {
      map['severity'] = Variable<int>(severity.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (resolvedOn.present) {
      map['resolved_on'] = Variable<DateTime>(resolvedOn.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NigglesCompanion(')
          ..write('id: $id, ')
          ..write('loggedOn: $loggedOn, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('sessionId: $sessionId, ')
          ..write('site: $site, ')
          ..write('severity: $severity, ')
          ..write('note: $note, ')
          ..write('resolvedOn: $resolvedOn')
          ..write(')'))
        .toString();
  }
}

class $PhotoShootsTable extends PhotoShoots
    with TableInfo<$PhotoShootsTable, PhotoShoot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PhotoShootsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _shotOnMeta = const VerificationMeta('shotOn');
  @override
  late final GeneratedColumn<DateTime> shotOn = GeneratedColumn<DateTime>(
    'shot_on',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weekNoMeta = const VerificationMeta('weekNo');
  @override
  late final GeneratedColumn<int> weekNo = GeneratedColumn<int>(
    'week_no',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bodyweightKgMeta = const VerificationMeta(
    'bodyweightKg',
  );
  @override
  late final GeneratedColumn<double> bodyweightKg = GeneratedColumn<double>(
    'bodyweight_kg',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    shotOn,
    weekNo,
    bodyweightKg,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'photo_shoots';
  @override
  VerificationContext validateIntegrity(
    Insertable<PhotoShoot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('shot_on')) {
      context.handle(
        _shotOnMeta,
        shotOn.isAcceptableOrUnknown(data['shot_on']!, _shotOnMeta),
      );
    } else if (isInserting) {
      context.missing(_shotOnMeta);
    }
    if (data.containsKey('week_no')) {
      context.handle(
        _weekNoMeta,
        weekNo.isAcceptableOrUnknown(data['week_no']!, _weekNoMeta),
      );
    }
    if (data.containsKey('bodyweight_kg')) {
      context.handle(
        _bodyweightKgMeta,
        bodyweightKg.isAcceptableOrUnknown(
          data['bodyweight_kg']!,
          _bodyweightKgMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PhotoShoot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PhotoShoot(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      shotOn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}shot_on'],
      )!,
      weekNo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}week_no'],
      ),
      bodyweightKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}bodyweight_kg'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $PhotoShootsTable createAlias(String alias) {
    return $PhotoShootsTable(attachedDatabase, alias);
  }
}

class PhotoShoot extends DataClass implements Insertable<PhotoShoot> {
  final String id;
  final DateTime shotOn;
  final int? weekNo;

  /// Resolved from the bodyweight table within +/- 2 days, so a caption is
  /// never empty and you never type the number twice.
  final double? bodyweightKg;
  final String? note;
  const PhotoShoot({
    required this.id,
    required this.shotOn,
    this.weekNo,
    this.bodyweightKg,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['shot_on'] = Variable<DateTime>(shotOn);
    if (!nullToAbsent || weekNo != null) {
      map['week_no'] = Variable<int>(weekNo);
    }
    if (!nullToAbsent || bodyweightKg != null) {
      map['bodyweight_kg'] = Variable<double>(bodyweightKg);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  PhotoShootsCompanion toCompanion(bool nullToAbsent) {
    return PhotoShootsCompanion(
      id: Value(id),
      shotOn: Value(shotOn),
      weekNo: weekNo == null && nullToAbsent
          ? const Value.absent()
          : Value(weekNo),
      bodyweightKg: bodyweightKg == null && nullToAbsent
          ? const Value.absent()
          : Value(bodyweightKg),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory PhotoShoot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PhotoShoot(
      id: serializer.fromJson<String>(json['id']),
      shotOn: serializer.fromJson<DateTime>(json['shotOn']),
      weekNo: serializer.fromJson<int?>(json['weekNo']),
      bodyweightKg: serializer.fromJson<double?>(json['bodyweightKg']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'shotOn': serializer.toJson<DateTime>(shotOn),
      'weekNo': serializer.toJson<int?>(weekNo),
      'bodyweightKg': serializer.toJson<double?>(bodyweightKg),
      'note': serializer.toJson<String?>(note),
    };
  }

  PhotoShoot copyWith({
    String? id,
    DateTime? shotOn,
    Value<int?> weekNo = const Value.absent(),
    Value<double?> bodyweightKg = const Value.absent(),
    Value<String?> note = const Value.absent(),
  }) => PhotoShoot(
    id: id ?? this.id,
    shotOn: shotOn ?? this.shotOn,
    weekNo: weekNo.present ? weekNo.value : this.weekNo,
    bodyweightKg: bodyweightKg.present ? bodyweightKg.value : this.bodyweightKg,
    note: note.present ? note.value : this.note,
  );
  PhotoShoot copyWithCompanion(PhotoShootsCompanion data) {
    return PhotoShoot(
      id: data.id.present ? data.id.value : this.id,
      shotOn: data.shotOn.present ? data.shotOn.value : this.shotOn,
      weekNo: data.weekNo.present ? data.weekNo.value : this.weekNo,
      bodyweightKg: data.bodyweightKg.present
          ? data.bodyweightKg.value
          : this.bodyweightKg,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PhotoShoot(')
          ..write('id: $id, ')
          ..write('shotOn: $shotOn, ')
          ..write('weekNo: $weekNo, ')
          ..write('bodyweightKg: $bodyweightKg, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, shotOn, weekNo, bodyweightKg, note);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PhotoShoot &&
          other.id == this.id &&
          other.shotOn == this.shotOn &&
          other.weekNo == this.weekNo &&
          other.bodyweightKg == this.bodyweightKg &&
          other.note == this.note);
}

class PhotoShootsCompanion extends UpdateCompanion<PhotoShoot> {
  final Value<String> id;
  final Value<DateTime> shotOn;
  final Value<int?> weekNo;
  final Value<double?> bodyweightKg;
  final Value<String?> note;
  final Value<int> rowid;
  const PhotoShootsCompanion({
    this.id = const Value.absent(),
    this.shotOn = const Value.absent(),
    this.weekNo = const Value.absent(),
    this.bodyweightKg = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PhotoShootsCompanion.insert({
    required String id,
    required DateTime shotOn,
    this.weekNo = const Value.absent(),
    this.bodyweightKg = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       shotOn = Value(shotOn);
  static Insertable<PhotoShoot> custom({
    Expression<String>? id,
    Expression<DateTime>? shotOn,
    Expression<int>? weekNo,
    Expression<double>? bodyweightKg,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (shotOn != null) 'shot_on': shotOn,
      if (weekNo != null) 'week_no': weekNo,
      if (bodyweightKg != null) 'bodyweight_kg': bodyweightKg,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PhotoShootsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? shotOn,
    Value<int?>? weekNo,
    Value<double?>? bodyweightKg,
    Value<String?>? note,
    Value<int>? rowid,
  }) {
    return PhotoShootsCompanion(
      id: id ?? this.id,
      shotOn: shotOn ?? this.shotOn,
      weekNo: weekNo ?? this.weekNo,
      bodyweightKg: bodyweightKg ?? this.bodyweightKg,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (shotOn.present) {
      map['shot_on'] = Variable<DateTime>(shotOn.value);
    }
    if (weekNo.present) {
      map['week_no'] = Variable<int>(weekNo.value);
    }
    if (bodyweightKg.present) {
      map['bodyweight_kg'] = Variable<double>(bodyweightKg.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PhotoShootsCompanion(')
          ..write('id: $id, ')
          ..write('shotOn: $shotOn, ')
          ..write('weekNo: $weekNo, ')
          ..write('bodyweightKg: $bodyweightKg, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProgressPhotosTable extends ProgressPhotos
    with TableInfo<$ProgressPhotosTable, ProgressPhoto> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProgressPhotosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _shootIdMeta = const VerificationMeta(
    'shootId',
  );
  @override
  late final GeneratedColumn<String> shootId = GeneratedColumn<String>(
    'shoot_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES photo_shoots (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _poseIdMeta = const VerificationMeta('poseId');
  @override
  late final GeneratedColumn<String> poseId = GeneratedColumn<String>(
    'pose_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _relativePathMeta = const VerificationMeta(
    'relativePath',
  );
  @override
  late final GeneratedColumn<String> relativePath = GeneratedColumn<String>(
    'relative_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<int> bytes = GeneratedColumn<int>(
    'bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _takenAtMeta = const VerificationMeta(
    'takenAt',
  );
  @override
  late final GeneratedColumn<DateTime> takenAt = GeneratedColumn<DateTime>(
    'taken_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    shootId,
    poseId,
    relativePath,
    width,
    height,
    bytes,
    takenAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'progress_photos';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProgressPhoto> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('shoot_id')) {
      context.handle(
        _shootIdMeta,
        shootId.isAcceptableOrUnknown(data['shoot_id']!, _shootIdMeta),
      );
    } else if (isInserting) {
      context.missing(_shootIdMeta);
    }
    if (data.containsKey('pose_id')) {
      context.handle(
        _poseIdMeta,
        poseId.isAcceptableOrUnknown(data['pose_id']!, _poseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_poseIdMeta);
    }
    if (data.containsKey('relative_path')) {
      context.handle(
        _relativePathMeta,
        relativePath.isAcceptableOrUnknown(
          data['relative_path']!,
          _relativePathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_relativePathMeta);
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    }
    if (data.containsKey('taken_at')) {
      context.handle(
        _takenAtMeta,
        takenAt.isAcceptableOrUnknown(data['taken_at']!, _takenAtMeta),
      );
    } else if (isInserting) {
      context.missing(_takenAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProgressPhoto map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProgressPhoto(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      shootId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shoot_id'],
      )!,
      poseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pose_id'],
      )!,
      relativePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relative_path'],
      )!,
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width'],
      )!,
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      )!,
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bytes'],
      )!,
      takenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}taken_at'],
      )!,
    );
  }

  @override
  $ProgressPhotosTable createAlias(String alias) {
    return $ProgressPhotosTable(attachedDatabase, alias);
  }
}

class ProgressPhoto extends DataClass implements Insertable<ProgressPhoto> {
  final String id;
  final String shootId;
  final String poseId;

  /// Relative to the app documents directory, so a restore onto a different
  /// device with a different sandbox path still finds the file.
  final String relativePath;
  final int width;
  final int height;
  final int bytes;
  final DateTime takenAt;
  const ProgressPhoto({
    required this.id,
    required this.shootId,
    required this.poseId,
    required this.relativePath,
    required this.width,
    required this.height,
    required this.bytes,
    required this.takenAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['shoot_id'] = Variable<String>(shootId);
    map['pose_id'] = Variable<String>(poseId);
    map['relative_path'] = Variable<String>(relativePath);
    map['width'] = Variable<int>(width);
    map['height'] = Variable<int>(height);
    map['bytes'] = Variable<int>(bytes);
    map['taken_at'] = Variable<DateTime>(takenAt);
    return map;
  }

  ProgressPhotosCompanion toCompanion(bool nullToAbsent) {
    return ProgressPhotosCompanion(
      id: Value(id),
      shootId: Value(shootId),
      poseId: Value(poseId),
      relativePath: Value(relativePath),
      width: Value(width),
      height: Value(height),
      bytes: Value(bytes),
      takenAt: Value(takenAt),
    );
  }

  factory ProgressPhoto.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProgressPhoto(
      id: serializer.fromJson<String>(json['id']),
      shootId: serializer.fromJson<String>(json['shootId']),
      poseId: serializer.fromJson<String>(json['poseId']),
      relativePath: serializer.fromJson<String>(json['relativePath']),
      width: serializer.fromJson<int>(json['width']),
      height: serializer.fromJson<int>(json['height']),
      bytes: serializer.fromJson<int>(json['bytes']),
      takenAt: serializer.fromJson<DateTime>(json['takenAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'shootId': serializer.toJson<String>(shootId),
      'poseId': serializer.toJson<String>(poseId),
      'relativePath': serializer.toJson<String>(relativePath),
      'width': serializer.toJson<int>(width),
      'height': serializer.toJson<int>(height),
      'bytes': serializer.toJson<int>(bytes),
      'takenAt': serializer.toJson<DateTime>(takenAt),
    };
  }

  ProgressPhoto copyWith({
    String? id,
    String? shootId,
    String? poseId,
    String? relativePath,
    int? width,
    int? height,
    int? bytes,
    DateTime? takenAt,
  }) => ProgressPhoto(
    id: id ?? this.id,
    shootId: shootId ?? this.shootId,
    poseId: poseId ?? this.poseId,
    relativePath: relativePath ?? this.relativePath,
    width: width ?? this.width,
    height: height ?? this.height,
    bytes: bytes ?? this.bytes,
    takenAt: takenAt ?? this.takenAt,
  );
  ProgressPhoto copyWithCompanion(ProgressPhotosCompanion data) {
    return ProgressPhoto(
      id: data.id.present ? data.id.value : this.id,
      shootId: data.shootId.present ? data.shootId.value : this.shootId,
      poseId: data.poseId.present ? data.poseId.value : this.poseId,
      relativePath: data.relativePath.present
          ? data.relativePath.value
          : this.relativePath,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      takenAt: data.takenAt.present ? data.takenAt.value : this.takenAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProgressPhoto(')
          ..write('id: $id, ')
          ..write('shootId: $shootId, ')
          ..write('poseId: $poseId, ')
          ..write('relativePath: $relativePath, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('bytes: $bytes, ')
          ..write('takenAt: $takenAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    shootId,
    poseId,
    relativePath,
    width,
    height,
    bytes,
    takenAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProgressPhoto &&
          other.id == this.id &&
          other.shootId == this.shootId &&
          other.poseId == this.poseId &&
          other.relativePath == this.relativePath &&
          other.width == this.width &&
          other.height == this.height &&
          other.bytes == this.bytes &&
          other.takenAt == this.takenAt);
}

class ProgressPhotosCompanion extends UpdateCompanion<ProgressPhoto> {
  final Value<String> id;
  final Value<String> shootId;
  final Value<String> poseId;
  final Value<String> relativePath;
  final Value<int> width;
  final Value<int> height;
  final Value<int> bytes;
  final Value<DateTime> takenAt;
  final Value<int> rowid;
  const ProgressPhotosCompanion({
    this.id = const Value.absent(),
    this.shootId = const Value.absent(),
    this.poseId = const Value.absent(),
    this.relativePath = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.bytes = const Value.absent(),
    this.takenAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProgressPhotosCompanion.insert({
    required String id,
    required String shootId,
    required String poseId,
    required String relativePath,
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.bytes = const Value.absent(),
    required DateTime takenAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       shootId = Value(shootId),
       poseId = Value(poseId),
       relativePath = Value(relativePath),
       takenAt = Value(takenAt);
  static Insertable<ProgressPhoto> custom({
    Expression<String>? id,
    Expression<String>? shootId,
    Expression<String>? poseId,
    Expression<String>? relativePath,
    Expression<int>? width,
    Expression<int>? height,
    Expression<int>? bytes,
    Expression<DateTime>? takenAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (shootId != null) 'shoot_id': shootId,
      if (poseId != null) 'pose_id': poseId,
      if (relativePath != null) 'relative_path': relativePath,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (bytes != null) 'bytes': bytes,
      if (takenAt != null) 'taken_at': takenAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProgressPhotosCompanion copyWith({
    Value<String>? id,
    Value<String>? shootId,
    Value<String>? poseId,
    Value<String>? relativePath,
    Value<int>? width,
    Value<int>? height,
    Value<int>? bytes,
    Value<DateTime>? takenAt,
    Value<int>? rowid,
  }) {
    return ProgressPhotosCompanion(
      id: id ?? this.id,
      shootId: shootId ?? this.shootId,
      poseId: poseId ?? this.poseId,
      relativePath: relativePath ?? this.relativePath,
      width: width ?? this.width,
      height: height ?? this.height,
      bytes: bytes ?? this.bytes,
      takenAt: takenAt ?? this.takenAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (shootId.present) {
      map['shoot_id'] = Variable<String>(shootId.value);
    }
    if (poseId.present) {
      map['pose_id'] = Variable<String>(poseId.value);
    }
    if (relativePath.present) {
      map['relative_path'] = Variable<String>(relativePath.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<int>(bytes.value);
    }
    if (takenAt.present) {
      map['taken_at'] = Variable<DateTime>(takenAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProgressPhotosCompanion(')
          ..write('id: $id, ')
          ..write('shootId: $shootId, ')
          ..write('poseId: $poseId, ')
          ..write('relativePath: $relativePath, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('bytes: $bytes, ')
          ..write('takenAt: $takenAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PhotoPosesTable extends PhotoPoses
    with TableInfo<$PhotoPosesTable, PhotoPose> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PhotoPosesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _guidanceMeta = const VerificationMeta(
    'guidance',
  );
  @override
  late final GeneratedColumn<String> guidance = GeneratedColumn<String>(
    'guidance',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    orderIndex,
    guidance,
    enabled,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'photo_poses';
  @override
  VerificationContext validateIntegrity(
    Insertable<PhotoPose> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_orderIndexMeta);
    }
    if (data.containsKey('guidance')) {
      context.handle(
        _guidanceMeta,
        guidance.isAcceptableOrUnknown(data['guidance']!, _guidanceMeta),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PhotoPose map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PhotoPose(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
      guidance: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}guidance'],
      ),
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
    );
  }

  @override
  $PhotoPosesTable createAlias(String alias) {
    return $PhotoPosesTable(attachedDatabase, alias);
  }
}

class PhotoPose extends DataClass implements Insertable<PhotoPose> {
  final String id;
  final String name;
  final int orderIndex;
  final String? guidance;
  final bool enabled;
  const PhotoPose({
    required this.id,
    required this.name,
    required this.orderIndex,
    this.guidance,
    required this.enabled,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['order_index'] = Variable<int>(orderIndex);
    if (!nullToAbsent || guidance != null) {
      map['guidance'] = Variable<String>(guidance);
    }
    map['enabled'] = Variable<bool>(enabled);
    return map;
  }

  PhotoPosesCompanion toCompanion(bool nullToAbsent) {
    return PhotoPosesCompanion(
      id: Value(id),
      name: Value(name),
      orderIndex: Value(orderIndex),
      guidance: guidance == null && nullToAbsent
          ? const Value.absent()
          : Value(guidance),
      enabled: Value(enabled),
    );
  }

  factory PhotoPose.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PhotoPose(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
      guidance: serializer.fromJson<String?>(json['guidance']),
      enabled: serializer.fromJson<bool>(json['enabled']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'orderIndex': serializer.toJson<int>(orderIndex),
      'guidance': serializer.toJson<String?>(guidance),
      'enabled': serializer.toJson<bool>(enabled),
    };
  }

  PhotoPose copyWith({
    String? id,
    String? name,
    int? orderIndex,
    Value<String?> guidance = const Value.absent(),
    bool? enabled,
  }) => PhotoPose(
    id: id ?? this.id,
    name: name ?? this.name,
    orderIndex: orderIndex ?? this.orderIndex,
    guidance: guidance.present ? guidance.value : this.guidance,
    enabled: enabled ?? this.enabled,
  );
  PhotoPose copyWithCompanion(PhotoPosesCompanion data) {
    return PhotoPose(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
      guidance: data.guidance.present ? data.guidance.value : this.guidance,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PhotoPose(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('guidance: $guidance, ')
          ..write('enabled: $enabled')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, orderIndex, guidance, enabled);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PhotoPose &&
          other.id == this.id &&
          other.name == this.name &&
          other.orderIndex == this.orderIndex &&
          other.guidance == this.guidance &&
          other.enabled == this.enabled);
}

class PhotoPosesCompanion extends UpdateCompanion<PhotoPose> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> orderIndex;
  final Value<String?> guidance;
  final Value<bool> enabled;
  final Value<int> rowid;
  const PhotoPosesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.guidance = const Value.absent(),
    this.enabled = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PhotoPosesCompanion.insert({
    required String id,
    required String name,
    required int orderIndex,
    this.guidance = const Value.absent(),
    this.enabled = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       orderIndex = Value(orderIndex);
  static Insertable<PhotoPose> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? orderIndex,
    Expression<String>? guidance,
    Expression<bool>? enabled,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (orderIndex != null) 'order_index': orderIndex,
      if (guidance != null) 'guidance': guidance,
      if (enabled != null) 'enabled': enabled,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PhotoPosesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? orderIndex,
    Value<String?>? guidance,
    Value<bool>? enabled,
    Value<int>? rowid,
  }) {
    return PhotoPosesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      orderIndex: orderIndex ?? this.orderIndex,
      guidance: guidance ?? this.guidance,
      enabled: enabled ?? this.enabled,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (guidance.present) {
      map['guidance'] = Variable<String>(guidance.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PhotoPosesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('guidance: $guidance, ')
          ..write('enabled: $enabled, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MeasurementsTable extends Measurements
    with TableInfo<$MeasurementsTable, Measurement> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MeasurementsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _measuredOnMeta = const VerificationMeta(
    'measuredOn',
  );
  @override
  late final GeneratedColumn<DateTime> measuredOn = GeneratedColumn<DateTime>(
    'measured_on',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<MeasurementSite, String> site =
      GeneratedColumn<String>(
        'site',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<MeasurementSite>($MeasurementsTable.$convertersite);
  static const VerificationMeta _cmMeta = const VerificationMeta('cm');
  @override
  late final GeneratedColumn<double> cm = GeneratedColumn<double>(
    'cm',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, measuredOn, site, cm, note];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'measurements';
  @override
  VerificationContext validateIntegrity(
    Insertable<Measurement> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('measured_on')) {
      context.handle(
        _measuredOnMeta,
        measuredOn.isAcceptableOrUnknown(data['measured_on']!, _measuredOnMeta),
      );
    } else if (isInserting) {
      context.missing(_measuredOnMeta);
    }
    if (data.containsKey('cm')) {
      context.handle(_cmMeta, cm.isAcceptableOrUnknown(data['cm']!, _cmMeta));
    } else if (isInserting) {
      context.missing(_cmMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {measuredOn, site},
  ];
  @override
  Measurement map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Measurement(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      measuredOn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}measured_on'],
      )!,
      site: $MeasurementsTable.$convertersite.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}site'],
        )!,
      ),
      cm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}cm'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $MeasurementsTable createAlias(String alias) {
    return $MeasurementsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<MeasurementSite, String, String> $convertersite =
      const EnumNameConverter<MeasurementSite>(MeasurementSite.values);
}

class Measurement extends DataClass implements Insertable<Measurement> {
  final int id;
  final DateTime measuredOn;
  final MeasurementSite site;
  final double cm;
  final String? note;
  const Measurement({
    required this.id,
    required this.measuredOn,
    required this.site,
    required this.cm,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['measured_on'] = Variable<DateTime>(measuredOn);
    {
      map['site'] = Variable<String>(
        $MeasurementsTable.$convertersite.toSql(site),
      );
    }
    map['cm'] = Variable<double>(cm);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  MeasurementsCompanion toCompanion(bool nullToAbsent) {
    return MeasurementsCompanion(
      id: Value(id),
      measuredOn: Value(measuredOn),
      site: Value(site),
      cm: Value(cm),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory Measurement.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Measurement(
      id: serializer.fromJson<int>(json['id']),
      measuredOn: serializer.fromJson<DateTime>(json['measuredOn']),
      site: $MeasurementsTable.$convertersite.fromJson(
        serializer.fromJson<String>(json['site']),
      ),
      cm: serializer.fromJson<double>(json['cm']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'measuredOn': serializer.toJson<DateTime>(measuredOn),
      'site': serializer.toJson<String>(
        $MeasurementsTable.$convertersite.toJson(site),
      ),
      'cm': serializer.toJson<double>(cm),
      'note': serializer.toJson<String?>(note),
    };
  }

  Measurement copyWith({
    int? id,
    DateTime? measuredOn,
    MeasurementSite? site,
    double? cm,
    Value<String?> note = const Value.absent(),
  }) => Measurement(
    id: id ?? this.id,
    measuredOn: measuredOn ?? this.measuredOn,
    site: site ?? this.site,
    cm: cm ?? this.cm,
    note: note.present ? note.value : this.note,
  );
  Measurement copyWithCompanion(MeasurementsCompanion data) {
    return Measurement(
      id: data.id.present ? data.id.value : this.id,
      measuredOn: data.measuredOn.present
          ? data.measuredOn.value
          : this.measuredOn,
      site: data.site.present ? data.site.value : this.site,
      cm: data.cm.present ? data.cm.value : this.cm,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Measurement(')
          ..write('id: $id, ')
          ..write('measuredOn: $measuredOn, ')
          ..write('site: $site, ')
          ..write('cm: $cm, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, measuredOn, site, cm, note);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Measurement &&
          other.id == this.id &&
          other.measuredOn == this.measuredOn &&
          other.site == this.site &&
          other.cm == this.cm &&
          other.note == this.note);
}

class MeasurementsCompanion extends UpdateCompanion<Measurement> {
  final Value<int> id;
  final Value<DateTime> measuredOn;
  final Value<MeasurementSite> site;
  final Value<double> cm;
  final Value<String?> note;
  const MeasurementsCompanion({
    this.id = const Value.absent(),
    this.measuredOn = const Value.absent(),
    this.site = const Value.absent(),
    this.cm = const Value.absent(),
    this.note = const Value.absent(),
  });
  MeasurementsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime measuredOn,
    required MeasurementSite site,
    required double cm,
    this.note = const Value.absent(),
  }) : measuredOn = Value(measuredOn),
       site = Value(site),
       cm = Value(cm);
  static Insertable<Measurement> custom({
    Expression<int>? id,
    Expression<DateTime>? measuredOn,
    Expression<String>? site,
    Expression<double>? cm,
    Expression<String>? note,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (measuredOn != null) 'measured_on': measuredOn,
      if (site != null) 'site': site,
      if (cm != null) 'cm': cm,
      if (note != null) 'note': note,
    });
  }

  MeasurementsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? measuredOn,
    Value<MeasurementSite>? site,
    Value<double>? cm,
    Value<String?>? note,
  }) {
    return MeasurementsCompanion(
      id: id ?? this.id,
      measuredOn: measuredOn ?? this.measuredOn,
      site: site ?? this.site,
      cm: cm ?? this.cm,
      note: note ?? this.note,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (measuredOn.present) {
      map['measured_on'] = Variable<DateTime>(measuredOn.value);
    }
    if (site.present) {
      map['site'] = Variable<String>(
        $MeasurementsTable.$convertersite.toSql(site.value),
      );
    }
    if (cm.present) {
      map['cm'] = Variable<double>(cm.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MeasurementsCompanion(')
          ..write('id: $id, ')
          ..write('measuredOn: $measuredOn, ')
          ..write('site: $site, ')
          ..write('cm: $cm, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }
}

class $FormClipsTable extends FormClips
    with TableInfo<$FormClipsTable, FormClip> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FormClipsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exerciseIdMeta = const VerificationMeta(
    'exerciseId',
  );
  @override
  late final GeneratedColumn<String> exerciseId = GeneratedColumn<String>(
    'exercise_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _relativePathMeta = const VerificationMeta(
    'relativePath',
  );
  @override
  late final GeneratedColumn<String> relativePath = GeneratedColumn<String>(
    'relative_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordedAtMeta = const VerificationMeta(
    'recordedAt',
  );
  @override
  late final GeneratedColumn<DateTime> recordedAt = GeneratedColumn<DateTime>(
    'recorded_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationSecMeta = const VerificationMeta(
    'durationSec',
  );
  @override
  late final GeneratedColumn<int> durationSec = GeneratedColumn<int>(
    'duration_sec',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<int> bytes = GeneratedColumn<int>(
    'bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    exerciseId,
    relativePath,
    recordedAt,
    durationSec,
    bytes,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'form_clips';
  @override
  VerificationContext validateIntegrity(
    Insertable<FormClip> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('exercise_id')) {
      context.handle(
        _exerciseIdMeta,
        exerciseId.isAcceptableOrUnknown(data['exercise_id']!, _exerciseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_exerciseIdMeta);
    }
    if (data.containsKey('relative_path')) {
      context.handle(
        _relativePathMeta,
        relativePath.isAcceptableOrUnknown(
          data['relative_path']!,
          _relativePathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_relativePathMeta);
    }
    if (data.containsKey('recorded_at')) {
      context.handle(
        _recordedAtMeta,
        recordedAt.isAcceptableOrUnknown(data['recorded_at']!, _recordedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_recordedAtMeta);
    }
    if (data.containsKey('duration_sec')) {
      context.handle(
        _durationSecMeta,
        durationSec.isAcceptableOrUnknown(
          data['duration_sec']!,
          _durationSecMeta,
        ),
      );
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FormClip map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FormClip(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      exerciseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exercise_id'],
      )!,
      relativePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relative_path'],
      )!,
      recordedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}recorded_at'],
      )!,
      durationSec: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_sec'],
      )!,
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bytes'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $FormClipsTable createAlias(String alias) {
    return $FormClipsTable(attachedDatabase, alias);
  }
}

class FormClip extends DataClass implements Insertable<FormClip> {
  final String id;
  final String exerciseId;
  final String relativePath;
  final DateTime recordedAt;
  final int durationSec;
  final int bytes;
  final String? note;
  const FormClip({
    required this.id,
    required this.exerciseId,
    required this.relativePath,
    required this.recordedAt,
    required this.durationSec,
    required this.bytes,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['exercise_id'] = Variable<String>(exerciseId);
    map['relative_path'] = Variable<String>(relativePath);
    map['recorded_at'] = Variable<DateTime>(recordedAt);
    map['duration_sec'] = Variable<int>(durationSec);
    map['bytes'] = Variable<int>(bytes);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  FormClipsCompanion toCompanion(bool nullToAbsent) {
    return FormClipsCompanion(
      id: Value(id),
      exerciseId: Value(exerciseId),
      relativePath: Value(relativePath),
      recordedAt: Value(recordedAt),
      durationSec: Value(durationSec),
      bytes: Value(bytes),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory FormClip.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FormClip(
      id: serializer.fromJson<String>(json['id']),
      exerciseId: serializer.fromJson<String>(json['exerciseId']),
      relativePath: serializer.fromJson<String>(json['relativePath']),
      recordedAt: serializer.fromJson<DateTime>(json['recordedAt']),
      durationSec: serializer.fromJson<int>(json['durationSec']),
      bytes: serializer.fromJson<int>(json['bytes']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'exerciseId': serializer.toJson<String>(exerciseId),
      'relativePath': serializer.toJson<String>(relativePath),
      'recordedAt': serializer.toJson<DateTime>(recordedAt),
      'durationSec': serializer.toJson<int>(durationSec),
      'bytes': serializer.toJson<int>(bytes),
      'note': serializer.toJson<String?>(note),
    };
  }

  FormClip copyWith({
    String? id,
    String? exerciseId,
    String? relativePath,
    DateTime? recordedAt,
    int? durationSec,
    int? bytes,
    Value<String?> note = const Value.absent(),
  }) => FormClip(
    id: id ?? this.id,
    exerciseId: exerciseId ?? this.exerciseId,
    relativePath: relativePath ?? this.relativePath,
    recordedAt: recordedAt ?? this.recordedAt,
    durationSec: durationSec ?? this.durationSec,
    bytes: bytes ?? this.bytes,
    note: note.present ? note.value : this.note,
  );
  FormClip copyWithCompanion(FormClipsCompanion data) {
    return FormClip(
      id: data.id.present ? data.id.value : this.id,
      exerciseId: data.exerciseId.present
          ? data.exerciseId.value
          : this.exerciseId,
      relativePath: data.relativePath.present
          ? data.relativePath.value
          : this.relativePath,
      recordedAt: data.recordedAt.present
          ? data.recordedAt.value
          : this.recordedAt,
      durationSec: data.durationSec.present
          ? data.durationSec.value
          : this.durationSec,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FormClip(')
          ..write('id: $id, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('relativePath: $relativePath, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('durationSec: $durationSec, ')
          ..write('bytes: $bytes, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    exerciseId,
    relativePath,
    recordedAt,
    durationSec,
    bytes,
    note,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FormClip &&
          other.id == this.id &&
          other.exerciseId == this.exerciseId &&
          other.relativePath == this.relativePath &&
          other.recordedAt == this.recordedAt &&
          other.durationSec == this.durationSec &&
          other.bytes == this.bytes &&
          other.note == this.note);
}

class FormClipsCompanion extends UpdateCompanion<FormClip> {
  final Value<String> id;
  final Value<String> exerciseId;
  final Value<String> relativePath;
  final Value<DateTime> recordedAt;
  final Value<int> durationSec;
  final Value<int> bytes;
  final Value<String?> note;
  final Value<int> rowid;
  const FormClipsCompanion({
    this.id = const Value.absent(),
    this.exerciseId = const Value.absent(),
    this.relativePath = const Value.absent(),
    this.recordedAt = const Value.absent(),
    this.durationSec = const Value.absent(),
    this.bytes = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FormClipsCompanion.insert({
    required String id,
    required String exerciseId,
    required String relativePath,
    required DateTime recordedAt,
    this.durationSec = const Value.absent(),
    this.bytes = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       exerciseId = Value(exerciseId),
       relativePath = Value(relativePath),
       recordedAt = Value(recordedAt);
  static Insertable<FormClip> custom({
    Expression<String>? id,
    Expression<String>? exerciseId,
    Expression<String>? relativePath,
    Expression<DateTime>? recordedAt,
    Expression<int>? durationSec,
    Expression<int>? bytes,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (relativePath != null) 'relative_path': relativePath,
      if (recordedAt != null) 'recorded_at': recordedAt,
      if (durationSec != null) 'duration_sec': durationSec,
      if (bytes != null) 'bytes': bytes,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FormClipsCompanion copyWith({
    Value<String>? id,
    Value<String>? exerciseId,
    Value<String>? relativePath,
    Value<DateTime>? recordedAt,
    Value<int>? durationSec,
    Value<int>? bytes,
    Value<String?>? note,
    Value<int>? rowid,
  }) {
    return FormClipsCompanion(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      relativePath: relativePath ?? this.relativePath,
      recordedAt: recordedAt ?? this.recordedAt,
      durationSec: durationSec ?? this.durationSec,
      bytes: bytes ?? this.bytes,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (exerciseId.present) {
      map['exercise_id'] = Variable<String>(exerciseId.value);
    }
    if (relativePath.present) {
      map['relative_path'] = Variable<String>(relativePath.value);
    }
    if (recordedAt.present) {
      map['recorded_at'] = Variable<DateTime>(recordedAt.value);
    }
    if (durationSec.present) {
      map['duration_sec'] = Variable<int>(durationSec.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<int>(bytes.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FormClipsCompanion(')
          ..write('id: $id, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('relativePath: $relativePath, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('durationSec: $durationSec, ')
          ..write('bytes: $bytes, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SessionsTable sessions = $SessionsTable(this);
  late final $SetLogsTable setLogs = $SetLogsTable(this);
  late final $StallCountersTable stallCounters = $StallCountersTable(this);
  late final $BodyweightsTable bodyweights = $BodyweightsTable(this);
  late final $CardioLogsTable cardioLogs = $CardioLogsTable(this);
  late final $FoodLogsTable foodLogs = $FoodLogsTable(this);
  late final $NigglesTable niggles = $NigglesTable(this);
  late final $PhotoShootsTable photoShoots = $PhotoShootsTable(this);
  late final $ProgressPhotosTable progressPhotos = $ProgressPhotosTable(this);
  late final $PhotoPosesTable photoPoses = $PhotoPosesTable(this);
  late final $MeasurementsTable measurements = $MeasurementsTable(this);
  late final $FormClipsTable formClips = $FormClipsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    sessions,
    setLogs,
    stallCounters,
    bodyweights,
    cardioLogs,
    foodLogs,
    niggles,
    photoShoots,
    progressPhotos,
    photoPoses,
    measurements,
    formClips,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'sessions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('set_logs', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'photo_shoots',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('progress_photos', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$SessionsTableCreateCompanionBuilder = SessionsCompanion Function({
  Value<int> id,
  required String programmeId,
  required String blockId,
  required String dayId,
  required int weekNo,
  required DateTime plannedDate,
  required DateTime scheduledDate,
  Value<DateTime?> startedAt,
  Value<DateTime?> finishedAt,
  Value<SessionStatus> status,
  Value<double?> bodyweightKg,
  Value<int?> rpeOverall,
  Value<String?> note,
  Value<bool> loggedRetroactively,
  Value<bool> wasShortened,
});
typedef $$SessionsTableUpdateCompanionBuilder = SessionsCompanion Function({
  Value<int> id,
  Value<String> programmeId,
  Value<String> blockId,
  Value<String> dayId,
  Value<int> weekNo,
  Value<DateTime> plannedDate,
  Value<DateTime> scheduledDate,
  Value<DateTime?> startedAt,
  Value<DateTime?> finishedAt,
  Value<SessionStatus> status,
  Value<double?> bodyweightKg,
  Value<int?> rpeOverall,
  Value<String?> note,
  Value<bool> loggedRetroactively,
  Value<bool> wasShortened,
});

final class $$SessionsTableReferences
    extends BaseReferences<_$AppDatabase, $SessionsTable, Session> {
  $$SessionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SetLogsTable, List<SetLog>> _setLogsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.setLogs,
    aliasName: $_aliasNameGenerator(db.sessions.id, db.setLogs.sessionId),
  );

  $$SetLogsTableProcessedTableManager get setLogsRefs {
    final manager = $$SetLogsTableTableManager(
      $_db,
      $_db.setLogs,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_setLogsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SessionsTableFilterComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get programmeId => $composableBuilder(
    column: $table.programmeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get blockId => $composableBuilder(
    column: $table.blockId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dayId => $composableBuilder(
    column: $table.dayId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get weekNo => $composableBuilder(
    column: $table.weekNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get plannedDate => $composableBuilder(
    column: $table.plannedDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get scheduledDate => $composableBuilder(
    column: $table.scheduledDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<SessionStatus, SessionStatus, String>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<double> get bodyweightKg => $composableBuilder(
    column: $table.bodyweightKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rpeOverall => $composableBuilder(
    column: $table.rpeOverall,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get loggedRetroactively => $composableBuilder(
    column: $table.loggedRetroactively,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get wasShortened => $composableBuilder(
    column: $table.wasShortened,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> setLogsRefs(
    Expression<bool> Function($$SetLogsTableFilterComposer f) f,
  ) {
    final $$SetLogsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.setLogs,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SetLogsTableFilterComposer(
            $db: $db,
            $table: $db.setLogs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get programmeId => $composableBuilder(
    column: $table.programmeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get blockId => $composableBuilder(
    column: $table.blockId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dayId => $composableBuilder(
    column: $table.dayId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get weekNo => $composableBuilder(
    column: $table.weekNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get plannedDate => $composableBuilder(
    column: $table.plannedDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scheduledDate => $composableBuilder(
    column: $table.scheduledDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get bodyweightKg => $composableBuilder(
    column: $table.bodyweightKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rpeOverall => $composableBuilder(
    column: $table.rpeOverall,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get loggedRetroactively => $composableBuilder(
    column: $table.loggedRetroactively,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get wasShortened => $composableBuilder(
    column: $table.wasShortened,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get programmeId => $composableBuilder(
    column: $table.programmeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get blockId =>
      $composableBuilder(column: $table.blockId, builder: (column) => column);

  GeneratedColumn<String> get dayId =>
      $composableBuilder(column: $table.dayId, builder: (column) => column);

  GeneratedColumn<int> get weekNo =>
      $composableBuilder(column: $table.weekNo, builder: (column) => column);

  GeneratedColumn<DateTime> get plannedDate => $composableBuilder(
    column: $table.plannedDate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get scheduledDate => $composableBuilder(
    column: $table.scheduledDate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<SessionStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<double> get bodyweightKg => $composableBuilder(
    column: $table.bodyweightKg,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rpeOverall => $composableBuilder(
    column: $table.rpeOverall,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<bool> get loggedRetroactively => $composableBuilder(
    column: $table.loggedRetroactively,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get wasShortened => $composableBuilder(
    column: $table.wasShortened,
    builder: (column) => column,
  );

  Expression<T> setLogsRefs<T extends Object>(
    Expression<T> Function($$SetLogsTableAnnotationComposer a) f,
  ) {
    final $$SetLogsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.setLogs,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SetLogsTableAnnotationComposer(
            $db: $db,
            $table: $db.setLogs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionsTable,
          Session,
          $$SessionsTableFilterComposer,
          $$SessionsTableOrderingComposer,
          $$SessionsTableAnnotationComposer,
          $$SessionsTableCreateCompanionBuilder,
          $$SessionsTableUpdateCompanionBuilder,
          (Session, $$SessionsTableReferences),
          Session,
          PrefetchHooks Function({bool setLogsRefs})
        > {
  $$SessionsTableTableManager(_$AppDatabase db, $SessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> programmeId = const Value.absent(),
                Value<String> blockId = const Value.absent(),
                Value<String> dayId = const Value.absent(),
                Value<int> weekNo = const Value.absent(),
                Value<DateTime> plannedDate = const Value.absent(),
                Value<DateTime> scheduledDate = const Value.absent(),
                Value<DateTime?> startedAt = const Value.absent(),
                Value<DateTime?> finishedAt = const Value.absent(),
                Value<SessionStatus> status = const Value.absent(),
                Value<double?> bodyweightKg = const Value.absent(),
                Value<int?> rpeOverall = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<bool> loggedRetroactively = const Value.absent(),
                Value<bool> wasShortened = const Value.absent(),
              }) => SessionsCompanion(
                id: id,
                programmeId: programmeId,
                blockId: blockId,
                dayId: dayId,
                weekNo: weekNo,
                plannedDate: plannedDate,
                scheduledDate: scheduledDate,
                startedAt: startedAt,
                finishedAt: finishedAt,
                status: status,
                bodyweightKg: bodyweightKg,
                rpeOverall: rpeOverall,
                note: note,
                loggedRetroactively: loggedRetroactively,
                wasShortened: wasShortened,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String programmeId,
                required String blockId,
                required String dayId,
                required int weekNo,
                required DateTime plannedDate,
                required DateTime scheduledDate,
                Value<DateTime?> startedAt = const Value.absent(),
                Value<DateTime?> finishedAt = const Value.absent(),
                Value<SessionStatus> status = const Value.absent(),
                Value<double?> bodyweightKg = const Value.absent(),
                Value<int?> rpeOverall = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<bool> loggedRetroactively = const Value.absent(),
                Value<bool> wasShortened = const Value.absent(),
              }) => SessionsCompanion.insert(
                id: id,
                programmeId: programmeId,
                blockId: blockId,
                dayId: dayId,
                weekNo: weekNo,
                plannedDate: plannedDate,
                scheduledDate: scheduledDate,
                startedAt: startedAt,
                finishedAt: finishedAt,
                status: status,
                bodyweightKg: bodyweightKg,
                rpeOverall: rpeOverall,
                note: note,
                loggedRetroactively: loggedRetroactively,
                wasShortened: wasShortened,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({setLogsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (setLogsRefs) db.setLogs],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (setLogsRefs)
                    await $_getPrefetchedData<Session, $SessionsTable, SetLog>(
                      currentTable: table,
                      referencedTable: $$SessionsTableReferences
                          ._setLogsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$SessionsTableReferences(db, table, p0).setLogsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.sessionId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionsTable,
      Session,
      $$SessionsTableFilterComposer,
      $$SessionsTableOrderingComposer,
      $$SessionsTableAnnotationComposer,
      $$SessionsTableCreateCompanionBuilder,
      $$SessionsTableUpdateCompanionBuilder,
      (Session, $$SessionsTableReferences),
      Session,
      PrefetchHooks Function({bool setLogsRefs})
    >;
typedef $$SetLogsTableCreateCompanionBuilder = SetLogsCompanion Function({
  Value<int> id,
  required int sessionId,
  required String prescriptionId,
  required String exerciseId,
  required int setIndex,
  Value<int?> targetRepsMin,
  Value<int?> targetRepsMax,
  Value<double?> targetLoadKg,
  Value<int?> reps,
  Value<double?> loadKg,
  Value<int?> durationSec,
  Value<int?> distanceM,
  Value<int?> rir,
  Value<String?> side,
  Value<bool> isWarmup,
  required DateTime completedAt,
  Value<String?> note,
});
typedef $$SetLogsTableUpdateCompanionBuilder = SetLogsCompanion Function({
  Value<int> id,
  Value<int> sessionId,
  Value<String> prescriptionId,
  Value<String> exerciseId,
  Value<int> setIndex,
  Value<int?> targetRepsMin,
  Value<int?> targetRepsMax,
  Value<double?> targetLoadKg,
  Value<int?> reps,
  Value<double?> loadKg,
  Value<int?> durationSec,
  Value<int?> distanceM,
  Value<int?> rir,
  Value<String?> side,
  Value<bool> isWarmup,
  Value<DateTime> completedAt,
  Value<String?> note,
});

final class $$SetLogsTableReferences
    extends BaseReferences<_$AppDatabase, $SetLogsTable, SetLog> {
  $$SetLogsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SessionsTable _sessionIdTable(_$AppDatabase db) => db.sessions
      .createAlias($_aliasNameGenerator(db.setLogs.sessionId, db.sessions.id));

  $$SessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<int>('session_id')!;

    final manager = $$SessionsTableTableManager(
      $_db,
      $_db.sessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SetLogsTableFilterComposer
    extends Composer<_$AppDatabase, $SetLogsTable> {
  $$SetLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get prescriptionId => $composableBuilder(
    column: $table.prescriptionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get setIndex => $composableBuilder(
    column: $table.setIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetRepsMin => $composableBuilder(
    column: $table.targetRepsMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetRepsMax => $composableBuilder(
    column: $table.targetRepsMax,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get targetLoadKg => $composableBuilder(
    column: $table.targetLoadKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get loadKg => $composableBuilder(
    column: $table.loadKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get distanceM => $composableBuilder(
    column: $table.distanceM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rir => $composableBuilder(
    column: $table.rir,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get side => $composableBuilder(
    column: $table.side,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isWarmup => $composableBuilder(
    column: $table.isWarmup,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  $$SessionsTableFilterComposer get sessionId {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableFilterComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SetLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $SetLogsTable> {
  $$SetLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get prescriptionId => $composableBuilder(
    column: $table.prescriptionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get setIndex => $composableBuilder(
    column: $table.setIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetRepsMin => $composableBuilder(
    column: $table.targetRepsMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetRepsMax => $composableBuilder(
    column: $table.targetRepsMax,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get targetLoadKg => $composableBuilder(
    column: $table.targetLoadKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get loadKg => $composableBuilder(
    column: $table.loadKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get distanceM => $composableBuilder(
    column: $table.distanceM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rir => $composableBuilder(
    column: $table.rir,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get side => $composableBuilder(
    column: $table.side,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isWarmup => $composableBuilder(
    column: $table.isWarmup,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  $$SessionsTableOrderingComposer get sessionId {
    final $$SessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableOrderingComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SetLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SetLogsTable> {
  $$SetLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get prescriptionId => $composableBuilder(
    column: $table.prescriptionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get setIndex =>
      $composableBuilder(column: $table.setIndex, builder: (column) => column);

  GeneratedColumn<int> get targetRepsMin => $composableBuilder(
    column: $table.targetRepsMin,
    builder: (column) => column,
  );

  GeneratedColumn<int> get targetRepsMax => $composableBuilder(
    column: $table.targetRepsMax,
    builder: (column) => column,
  );

  GeneratedColumn<double> get targetLoadKg => $composableBuilder(
    column: $table.targetLoadKg,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reps =>
      $composableBuilder(column: $table.reps, builder: (column) => column);

  GeneratedColumn<double> get loadKg =>
      $composableBuilder(column: $table.loadKg, builder: (column) => column);

  GeneratedColumn<int> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => column,
  );

  GeneratedColumn<int> get distanceM =>
      $composableBuilder(column: $table.distanceM, builder: (column) => column);

  GeneratedColumn<int> get rir =>
      $composableBuilder(column: $table.rir, builder: (column) => column);

  GeneratedColumn<String> get side =>
      $composableBuilder(column: $table.side, builder: (column) => column);

  GeneratedColumn<bool> get isWarmup =>
      $composableBuilder(column: $table.isWarmup, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  $$SessionsTableAnnotationComposer get sessionId {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SetLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SetLogsTable,
          SetLog,
          $$SetLogsTableFilterComposer,
          $$SetLogsTableOrderingComposer,
          $$SetLogsTableAnnotationComposer,
          $$SetLogsTableCreateCompanionBuilder,
          $$SetLogsTableUpdateCompanionBuilder,
          (SetLog, $$SetLogsTableReferences),
          SetLog,
          PrefetchHooks Function({bool sessionId})
        > {
  $$SetLogsTableTableManager(_$AppDatabase db, $SetLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SetLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SetLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SetLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> sessionId = const Value.absent(),
                Value<String> prescriptionId = const Value.absent(),
                Value<String> exerciseId = const Value.absent(),
                Value<int> setIndex = const Value.absent(),
                Value<int?> targetRepsMin = const Value.absent(),
                Value<int?> targetRepsMax = const Value.absent(),
                Value<double?> targetLoadKg = const Value.absent(),
                Value<int?> reps = const Value.absent(),
                Value<double?> loadKg = const Value.absent(),
                Value<int?> durationSec = const Value.absent(),
                Value<int?> distanceM = const Value.absent(),
                Value<int?> rir = const Value.absent(),
                Value<String?> side = const Value.absent(),
                Value<bool> isWarmup = const Value.absent(),
                Value<DateTime> completedAt = const Value.absent(),
                Value<String?> note = const Value.absent(),
              }) => SetLogsCompanion(
                id: id,
                sessionId: sessionId,
                prescriptionId: prescriptionId,
                exerciseId: exerciseId,
                setIndex: setIndex,
                targetRepsMin: targetRepsMin,
                targetRepsMax: targetRepsMax,
                targetLoadKg: targetLoadKg,
                reps: reps,
                loadKg: loadKg,
                durationSec: durationSec,
                distanceM: distanceM,
                rir: rir,
                side: side,
                isWarmup: isWarmup,
                completedAt: completedAt,
                note: note,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int sessionId,
                required String prescriptionId,
                required String exerciseId,
                required int setIndex,
                Value<int?> targetRepsMin = const Value.absent(),
                Value<int?> targetRepsMax = const Value.absent(),
                Value<double?> targetLoadKg = const Value.absent(),
                Value<int?> reps = const Value.absent(),
                Value<double?> loadKg = const Value.absent(),
                Value<int?> durationSec = const Value.absent(),
                Value<int?> distanceM = const Value.absent(),
                Value<int?> rir = const Value.absent(),
                Value<String?> side = const Value.absent(),
                Value<bool> isWarmup = const Value.absent(),
                required DateTime completedAt,
                Value<String?> note = const Value.absent(),
              }) => SetLogsCompanion.insert(
                id: id,
                sessionId: sessionId,
                prescriptionId: prescriptionId,
                exerciseId: exerciseId,
                setIndex: setIndex,
                targetRepsMin: targetRepsMin,
                targetRepsMax: targetRepsMax,
                targetLoadKg: targetLoadKg,
                reps: reps,
                loadKg: loadKg,
                durationSec: durationSec,
                distanceM: distanceM,
                rir: rir,
                side: side,
                isWarmup: isWarmup,
                completedAt: completedAt,
                note: note,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SetLogsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
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
                    if (sessionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.sessionId,
                        referencedTable: $$SetLogsTableReferences
                            ._sessionIdTable(db),
                        referencedColumn: $$SetLogsTableReferences
                            ._sessionIdTable(db)
                            .id,
                      ) as T;
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

typedef $$SetLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SetLogsTable,
      SetLog,
      $$SetLogsTableFilterComposer,
      $$SetLogsTableOrderingComposer,
      $$SetLogsTableAnnotationComposer,
      $$SetLogsTableCreateCompanionBuilder,
      $$SetLogsTableUpdateCompanionBuilder,
      (SetLog, $$SetLogsTableReferences),
      SetLog,
      PrefetchHooks Function({bool sessionId})
    >;
typedef $$StallCountersTableCreateCompanionBuilder =
    StallCountersCompanion Function({
      required String exerciseId,
      required String prescriptionId,
      Value<int> count,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$StallCountersTableUpdateCompanionBuilder =
    StallCountersCompanion Function({
      Value<String> exerciseId,
      Value<String> prescriptionId,
      Value<int> count,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$StallCountersTableFilterComposer
    extends Composer<_$AppDatabase, $StallCountersTable> {
  $$StallCountersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get prescriptionId => $composableBuilder(
    column: $table.prescriptionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StallCountersTableOrderingComposer
    extends Composer<_$AppDatabase, $StallCountersTable> {
  $$StallCountersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get prescriptionId => $composableBuilder(
    column: $table.prescriptionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StallCountersTableAnnotationComposer
    extends Composer<_$AppDatabase, $StallCountersTable> {
  $$StallCountersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get prescriptionId => $composableBuilder(
    column: $table.prescriptionId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get count =>
      $composableBuilder(column: $table.count, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$StallCountersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StallCountersTable,
          StallCounter,
          $$StallCountersTableFilterComposer,
          $$StallCountersTableOrderingComposer,
          $$StallCountersTableAnnotationComposer,
          $$StallCountersTableCreateCompanionBuilder,
          $$StallCountersTableUpdateCompanionBuilder,
          (
            StallCounter,
            BaseReferences<_$AppDatabase, $StallCountersTable, StallCounter>,
          ),
          StallCounter,
          PrefetchHooks Function()
        > {
  $$StallCountersTableTableManager(_$AppDatabase db, $StallCountersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StallCountersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StallCountersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StallCountersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> exerciseId = const Value.absent(),
                Value<String> prescriptionId = const Value.absent(),
                Value<int> count = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StallCountersCompanion(
                exerciseId: exerciseId,
                prescriptionId: prescriptionId,
                count: count,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String exerciseId,
                required String prescriptionId,
                Value<int> count = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => StallCountersCompanion.insert(
                exerciseId: exerciseId,
                prescriptionId: prescriptionId,
                count: count,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StallCountersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StallCountersTable,
      StallCounter,
      $$StallCountersTableFilterComposer,
      $$StallCountersTableOrderingComposer,
      $$StallCountersTableAnnotationComposer,
      $$StallCountersTableCreateCompanionBuilder,
      $$StallCountersTableUpdateCompanionBuilder,
      (
        StallCounter,
        BaseReferences<_$AppDatabase, $StallCountersTable, StallCounter>,
      ),
      StallCounter,
      PrefetchHooks Function()
    >;
typedef $$BodyweightsTableCreateCompanionBuilder =
    BodyweightsCompanion Function({
      required DateTime measuredOn,
      required double kg,
      Value<String?> note,
      Value<int> rowid,
    });
typedef $$BodyweightsTableUpdateCompanionBuilder =
    BodyweightsCompanion Function({
      Value<DateTime> measuredOn,
      Value<double> kg,
      Value<String?> note,
      Value<int> rowid,
    });

class $$BodyweightsTableFilterComposer
    extends Composer<_$AppDatabase, $BodyweightsTable> {
  $$BodyweightsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get measuredOn => $composableBuilder(
    column: $table.measuredOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get kg => $composableBuilder(
    column: $table.kg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BodyweightsTableOrderingComposer
    extends Composer<_$AppDatabase, $BodyweightsTable> {
  $$BodyweightsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get measuredOn => $composableBuilder(
    column: $table.measuredOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get kg => $composableBuilder(
    column: $table.kg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BodyweightsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BodyweightsTable> {
  $$BodyweightsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get measuredOn => $composableBuilder(
    column: $table.measuredOn,
    builder: (column) => column,
  );

  GeneratedColumn<double> get kg =>
      $composableBuilder(column: $table.kg, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);
}

class $$BodyweightsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BodyweightsTable,
          Bodyweight,
          $$BodyweightsTableFilterComposer,
          $$BodyweightsTableOrderingComposer,
          $$BodyweightsTableAnnotationComposer,
          $$BodyweightsTableCreateCompanionBuilder,
          $$BodyweightsTableUpdateCompanionBuilder,
          (
            Bodyweight,
            BaseReferences<_$AppDatabase, $BodyweightsTable, Bodyweight>,
          ),
          Bodyweight,
          PrefetchHooks Function()
        > {
  $$BodyweightsTableTableManager(_$AppDatabase db, $BodyweightsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BodyweightsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BodyweightsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BodyweightsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<DateTime> measuredOn = const Value.absent(),
                Value<double> kg = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BodyweightsCompanion(
                measuredOn: measuredOn,
                kg: kg,
                note: note,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required DateTime measuredOn,
                required double kg,
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BodyweightsCompanion.insert(
                measuredOn: measuredOn,
                kg: kg,
                note: note,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BodyweightsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BodyweightsTable,
      Bodyweight,
      $$BodyweightsTableFilterComposer,
      $$BodyweightsTableOrderingComposer,
      $$BodyweightsTableAnnotationComposer,
      $$BodyweightsTableCreateCompanionBuilder,
      $$BodyweightsTableUpdateCompanionBuilder,
      (
        Bodyweight,
        BaseReferences<_$AppDatabase, $BodyweightsTable, Bodyweight>,
      ),
      Bodyweight,
      PrefetchHooks Function()
    >;
typedef $$CardioLogsTableCreateCompanionBuilder = CardioLogsCompanion Function({
  Value<int> id,
  Value<int?> sessionId,
  required CardioKind kind,
  required DateTime measuredOn,
  Value<int?> durationSec,
  Value<int?> distanceM,
  Value<int?> rounds,
  Value<int?> effort,
  Value<String?> note,
});
typedef $$CardioLogsTableUpdateCompanionBuilder = CardioLogsCompanion Function({
  Value<int> id,
  Value<int?> sessionId,
  Value<CardioKind> kind,
  Value<DateTime> measuredOn,
  Value<int?> durationSec,
  Value<int?> distanceM,
  Value<int?> rounds,
  Value<int?> effort,
  Value<String?> note,
});

class $$CardioLogsTableFilterComposer
    extends Composer<_$AppDatabase, $CardioLogsTable> {
  $$CardioLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<CardioKind, CardioKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<DateTime> get measuredOn => $composableBuilder(
    column: $table.measuredOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get distanceM => $composableBuilder(
    column: $table.distanceM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rounds => $composableBuilder(
    column: $table.rounds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get effort => $composableBuilder(
    column: $table.effort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CardioLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $CardioLogsTable> {
  $$CardioLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get measuredOn => $composableBuilder(
    column: $table.measuredOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get distanceM => $composableBuilder(
    column: $table.distanceM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rounds => $composableBuilder(
    column: $table.rounds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get effort => $composableBuilder(
    column: $table.effort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CardioLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CardioLogsTable> {
  $$CardioLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<CardioKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<DateTime> get measuredOn => $composableBuilder(
    column: $table.measuredOn,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => column,
  );

  GeneratedColumn<int> get distanceM =>
      $composableBuilder(column: $table.distanceM, builder: (column) => column);

  GeneratedColumn<int> get rounds =>
      $composableBuilder(column: $table.rounds, builder: (column) => column);

  GeneratedColumn<int> get effort =>
      $composableBuilder(column: $table.effort, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);
}

class $$CardioLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CardioLogsTable,
          CardioLog,
          $$CardioLogsTableFilterComposer,
          $$CardioLogsTableOrderingComposer,
          $$CardioLogsTableAnnotationComposer,
          $$CardioLogsTableCreateCompanionBuilder,
          $$CardioLogsTableUpdateCompanionBuilder,
          (
            CardioLog,
            BaseReferences<_$AppDatabase, $CardioLogsTable, CardioLog>,
          ),
          CardioLog,
          PrefetchHooks Function()
        > {
  $$CardioLogsTableTableManager(_$AppDatabase db, $CardioLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CardioLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CardioLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CardioLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> sessionId = const Value.absent(),
                Value<CardioKind> kind = const Value.absent(),
                Value<DateTime> measuredOn = const Value.absent(),
                Value<int?> durationSec = const Value.absent(),
                Value<int?> distanceM = const Value.absent(),
                Value<int?> rounds = const Value.absent(),
                Value<int?> effort = const Value.absent(),
                Value<String?> note = const Value.absent(),
              }) => CardioLogsCompanion(
                id: id,
                sessionId: sessionId,
                kind: kind,
                measuredOn: measuredOn,
                durationSec: durationSec,
                distanceM: distanceM,
                rounds: rounds,
                effort: effort,
                note: note,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> sessionId = const Value.absent(),
                required CardioKind kind,
                required DateTime measuredOn,
                Value<int?> durationSec = const Value.absent(),
                Value<int?> distanceM = const Value.absent(),
                Value<int?> rounds = const Value.absent(),
                Value<int?> effort = const Value.absent(),
                Value<String?> note = const Value.absent(),
              }) => CardioLogsCompanion.insert(
                id: id,
                sessionId: sessionId,
                kind: kind,
                measuredOn: measuredOn,
                durationSec: durationSec,
                distanceM: distanceM,
                rounds: rounds,
                effort: effort,
                note: note,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CardioLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CardioLogsTable,
      CardioLog,
      $$CardioLogsTableFilterComposer,
      $$CardioLogsTableOrderingComposer,
      $$CardioLogsTableAnnotationComposer,
      $$CardioLogsTableCreateCompanionBuilder,
      $$CardioLogsTableUpdateCompanionBuilder,
      (CardioLog, BaseReferences<_$AppDatabase, $CardioLogsTable, CardioLog>),
      CardioLog,
      PrefetchHooks Function()
    >;
typedef $$FoodLogsTableCreateCompanionBuilder = FoodLogsCompanion Function({
  required DateTime loggedOn,
  Value<int?> kcal,
  Value<int?> proteinG,
  Value<bool> hitTarget,
  Value<String?> note,
  Value<int> rowid,
});
typedef $$FoodLogsTableUpdateCompanionBuilder = FoodLogsCompanion Function({
  Value<DateTime> loggedOn,
  Value<int?> kcal,
  Value<int?> proteinG,
  Value<bool> hitTarget,
  Value<String?> note,
  Value<int> rowid,
});

class $$FoodLogsTableFilterComposer
    extends Composer<_$AppDatabase, $FoodLogsTable> {
  $$FoodLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get loggedOn => $composableBuilder(
    column: $table.loggedOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get kcal => $composableBuilder(
    column: $table.kcal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get proteinG => $composableBuilder(
    column: $table.proteinG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hitTarget => $composableBuilder(
    column: $table.hitTarget,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FoodLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $FoodLogsTable> {
  $$FoodLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get loggedOn => $composableBuilder(
    column: $table.loggedOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kcal => $composableBuilder(
    column: $table.kcal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get proteinG => $composableBuilder(
    column: $table.proteinG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hitTarget => $composableBuilder(
    column: $table.hitTarget,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FoodLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FoodLogsTable> {
  $$FoodLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get loggedOn =>
      $composableBuilder(column: $table.loggedOn, builder: (column) => column);

  GeneratedColumn<int> get kcal =>
      $composableBuilder(column: $table.kcal, builder: (column) => column);

  GeneratedColumn<int> get proteinG =>
      $composableBuilder(column: $table.proteinG, builder: (column) => column);

  GeneratedColumn<bool> get hitTarget =>
      $composableBuilder(column: $table.hitTarget, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);
}

class $$FoodLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FoodLogsTable,
          FoodLog,
          $$FoodLogsTableFilterComposer,
          $$FoodLogsTableOrderingComposer,
          $$FoodLogsTableAnnotationComposer,
          $$FoodLogsTableCreateCompanionBuilder,
          $$FoodLogsTableUpdateCompanionBuilder,
          (FoodLog, BaseReferences<_$AppDatabase, $FoodLogsTable, FoodLog>),
          FoodLog,
          PrefetchHooks Function()
        > {
  $$FoodLogsTableTableManager(_$AppDatabase db, $FoodLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FoodLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FoodLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FoodLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<DateTime> loggedOn = const Value.absent(),
                Value<int?> kcal = const Value.absent(),
                Value<int?> proteinG = const Value.absent(),
                Value<bool> hitTarget = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FoodLogsCompanion(
                loggedOn: loggedOn,
                kcal: kcal,
                proteinG: proteinG,
                hitTarget: hitTarget,
                note: note,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required DateTime loggedOn,
                Value<int?> kcal = const Value.absent(),
                Value<int?> proteinG = const Value.absent(),
                Value<bool> hitTarget = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FoodLogsCompanion.insert(
                loggedOn: loggedOn,
                kcal: kcal,
                proteinG: proteinG,
                hitTarget: hitTarget,
                note: note,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FoodLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FoodLogsTable,
      FoodLog,
      $$FoodLogsTableFilterComposer,
      $$FoodLogsTableOrderingComposer,
      $$FoodLogsTableAnnotationComposer,
      $$FoodLogsTableCreateCompanionBuilder,
      $$FoodLogsTableUpdateCompanionBuilder,
      (FoodLog, BaseReferences<_$AppDatabase, $FoodLogsTable, FoodLog>),
      FoodLog,
      PrefetchHooks Function()
    >;
typedef $$NigglesTableCreateCompanionBuilder = NigglesCompanion Function({
  Value<int> id,
  required DateTime loggedOn,
  Value<String?> exerciseId,
  Value<int?> sessionId,
  required NiggleSite site,
  required int severity,
  Value<String?> note,
  Value<DateTime?> resolvedOn,
});
typedef $$NigglesTableUpdateCompanionBuilder = NigglesCompanion Function({
  Value<int> id,
  Value<DateTime> loggedOn,
  Value<String?> exerciseId,
  Value<int?> sessionId,
  Value<NiggleSite> site,
  Value<int> severity,
  Value<String?> note,
  Value<DateTime?> resolvedOn,
});

class $$NigglesTableFilterComposer
    extends Composer<_$AppDatabase, $NigglesTable> {
  $$NigglesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get loggedOn => $composableBuilder(
    column: $table.loggedOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<NiggleSite, NiggleSite, String> get site =>
      $composableBuilder(
        column: $table.site,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get severity => $composableBuilder(
    column: $table.severity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get resolvedOn => $composableBuilder(
    column: $table.resolvedOn,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NigglesTableOrderingComposer
    extends Composer<_$AppDatabase, $NigglesTable> {
  $$NigglesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get loggedOn => $composableBuilder(
    column: $table.loggedOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get site => $composableBuilder(
    column: $table.site,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get severity => $composableBuilder(
    column: $table.severity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get resolvedOn => $composableBuilder(
    column: $table.resolvedOn,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NigglesTableAnnotationComposer
    extends Composer<_$AppDatabase, $NigglesTable> {
  $$NigglesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get loggedOn =>
      $composableBuilder(column: $table.loggedOn, builder: (column) => column);

  GeneratedColumn<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<NiggleSite, String> get site =>
      $composableBuilder(column: $table.site, builder: (column) => column);

  GeneratedColumn<int> get severity =>
      $composableBuilder(column: $table.severity, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get resolvedOn => $composableBuilder(
    column: $table.resolvedOn,
    builder: (column) => column,
  );
}

class $$NigglesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NigglesTable,
          Niggle,
          $$NigglesTableFilterComposer,
          $$NigglesTableOrderingComposer,
          $$NigglesTableAnnotationComposer,
          $$NigglesTableCreateCompanionBuilder,
          $$NigglesTableUpdateCompanionBuilder,
          (Niggle, BaseReferences<_$AppDatabase, $NigglesTable, Niggle>),
          Niggle,
          PrefetchHooks Function()
        > {
  $$NigglesTableTableManager(_$AppDatabase db, $NigglesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NigglesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NigglesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NigglesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> loggedOn = const Value.absent(),
                Value<String?> exerciseId = const Value.absent(),
                Value<int?> sessionId = const Value.absent(),
                Value<NiggleSite> site = const Value.absent(),
                Value<int> severity = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime?> resolvedOn = const Value.absent(),
              }) => NigglesCompanion(
                id: id,
                loggedOn: loggedOn,
                exerciseId: exerciseId,
                sessionId: sessionId,
                site: site,
                severity: severity,
                note: note,
                resolvedOn: resolvedOn,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime loggedOn,
                Value<String?> exerciseId = const Value.absent(),
                Value<int?> sessionId = const Value.absent(),
                required NiggleSite site,
                required int severity,
                Value<String?> note = const Value.absent(),
                Value<DateTime?> resolvedOn = const Value.absent(),
              }) => NigglesCompanion.insert(
                id: id,
                loggedOn: loggedOn,
                exerciseId: exerciseId,
                sessionId: sessionId,
                site: site,
                severity: severity,
                note: note,
                resolvedOn: resolvedOn,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NigglesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NigglesTable,
      Niggle,
      $$NigglesTableFilterComposer,
      $$NigglesTableOrderingComposer,
      $$NigglesTableAnnotationComposer,
      $$NigglesTableCreateCompanionBuilder,
      $$NigglesTableUpdateCompanionBuilder,
      (Niggle, BaseReferences<_$AppDatabase, $NigglesTable, Niggle>),
      Niggle,
      PrefetchHooks Function()
    >;
typedef $$PhotoShootsTableCreateCompanionBuilder =
    PhotoShootsCompanion Function({
      required String id,
      required DateTime shotOn,
      Value<int?> weekNo,
      Value<double?> bodyweightKg,
      Value<String?> note,
      Value<int> rowid,
    });
typedef $$PhotoShootsTableUpdateCompanionBuilder =
    PhotoShootsCompanion Function({
      Value<String> id,
      Value<DateTime> shotOn,
      Value<int?> weekNo,
      Value<double?> bodyweightKg,
      Value<String?> note,
      Value<int> rowid,
    });

final class $$PhotoShootsTableReferences
    extends BaseReferences<_$AppDatabase, $PhotoShootsTable, PhotoShoot> {
  $$PhotoShootsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ProgressPhotosTable, List<ProgressPhoto>>
  _progressPhotosRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.progressPhotos,
    aliasName: $_aliasNameGenerator(
      db.photoShoots.id,
      db.progressPhotos.shootId,
    ),
  );

  $$ProgressPhotosTableProcessedTableManager get progressPhotosRefs {
    final manager = $$ProgressPhotosTableTableManager(
      $_db,
      $_db.progressPhotos,
    ).filter((f) => f.shootId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_progressPhotosRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PhotoShootsTableFilterComposer
    extends Composer<_$AppDatabase, $PhotoShootsTable> {
  $$PhotoShootsTableFilterComposer({
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

  ColumnFilters<DateTime> get shotOn => $composableBuilder(
    column: $table.shotOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get weekNo => $composableBuilder(
    column: $table.weekNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get bodyweightKg => $composableBuilder(
    column: $table.bodyweightKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> progressPhotosRefs(
    Expression<bool> Function($$ProgressPhotosTableFilterComposer f) f,
  ) {
    final $$ProgressPhotosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.progressPhotos,
      getReferencedColumn: (t) => t.shootId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProgressPhotosTableFilterComposer(
            $db: $db,
            $table: $db.progressPhotos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PhotoShootsTableOrderingComposer
    extends Composer<_$AppDatabase, $PhotoShootsTable> {
  $$PhotoShootsTableOrderingComposer({
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

  ColumnOrderings<DateTime> get shotOn => $composableBuilder(
    column: $table.shotOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get weekNo => $composableBuilder(
    column: $table.weekNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get bodyweightKg => $composableBuilder(
    column: $table.bodyweightKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PhotoShootsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PhotoShootsTable> {
  $$PhotoShootsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get shotOn =>
      $composableBuilder(column: $table.shotOn, builder: (column) => column);

  GeneratedColumn<int> get weekNo =>
      $composableBuilder(column: $table.weekNo, builder: (column) => column);

  GeneratedColumn<double> get bodyweightKg => $composableBuilder(
    column: $table.bodyweightKg,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  Expression<T> progressPhotosRefs<T extends Object>(
    Expression<T> Function($$ProgressPhotosTableAnnotationComposer a) f,
  ) {
    final $$ProgressPhotosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.progressPhotos,
      getReferencedColumn: (t) => t.shootId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProgressPhotosTableAnnotationComposer(
            $db: $db,
            $table: $db.progressPhotos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PhotoShootsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PhotoShootsTable,
          PhotoShoot,
          $$PhotoShootsTableFilterComposer,
          $$PhotoShootsTableOrderingComposer,
          $$PhotoShootsTableAnnotationComposer,
          $$PhotoShootsTableCreateCompanionBuilder,
          $$PhotoShootsTableUpdateCompanionBuilder,
          (PhotoShoot, $$PhotoShootsTableReferences),
          PhotoShoot,
          PrefetchHooks Function({bool progressPhotosRefs})
        > {
  $$PhotoShootsTableTableManager(_$AppDatabase db, $PhotoShootsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PhotoShootsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PhotoShootsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PhotoShootsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> shotOn = const Value.absent(),
                Value<int?> weekNo = const Value.absent(),
                Value<double?> bodyweightKg = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PhotoShootsCompanion(
                id: id,
                shotOn: shotOn,
                weekNo: weekNo,
                bodyweightKg: bodyweightKg,
                note: note,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime shotOn,
                Value<int?> weekNo = const Value.absent(),
                Value<double?> bodyweightKg = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PhotoShootsCompanion.insert(
                id: id,
                shotOn: shotOn,
                weekNo: weekNo,
                bodyweightKg: bodyweightKg,
                note: note,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PhotoShootsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({progressPhotosRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (progressPhotosRefs) db.progressPhotos,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (progressPhotosRefs)
                    await $_getPrefetchedData<
                      PhotoShoot,
                      $PhotoShootsTable,
                      ProgressPhoto
                    >(
                      currentTable: table,
                      referencedTable: $$PhotoShootsTableReferences
                          ._progressPhotosRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$PhotoShootsTableReferences(
                            db,
                            table,
                            p0,
                          ).progressPhotosRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.shootId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$PhotoShootsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PhotoShootsTable,
      PhotoShoot,
      $$PhotoShootsTableFilterComposer,
      $$PhotoShootsTableOrderingComposer,
      $$PhotoShootsTableAnnotationComposer,
      $$PhotoShootsTableCreateCompanionBuilder,
      $$PhotoShootsTableUpdateCompanionBuilder,
      (PhotoShoot, $$PhotoShootsTableReferences),
      PhotoShoot,
      PrefetchHooks Function({bool progressPhotosRefs})
    >;
typedef $$ProgressPhotosTableCreateCompanionBuilder =
    ProgressPhotosCompanion Function({
      required String id,
      required String shootId,
      required String poseId,
      required String relativePath,
      Value<int> width,
      Value<int> height,
      Value<int> bytes,
      required DateTime takenAt,
      Value<int> rowid,
    });
typedef $$ProgressPhotosTableUpdateCompanionBuilder =
    ProgressPhotosCompanion Function({
      Value<String> id,
      Value<String> shootId,
      Value<String> poseId,
      Value<String> relativePath,
      Value<int> width,
      Value<int> height,
      Value<int> bytes,
      Value<DateTime> takenAt,
      Value<int> rowid,
    });

final class $$ProgressPhotosTableReferences
    extends BaseReferences<_$AppDatabase, $ProgressPhotosTable, ProgressPhoto> {
  $$ProgressPhotosTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PhotoShootsTable _shootIdTable(_$AppDatabase db) =>
      db.photoShoots.createAlias(
        $_aliasNameGenerator(db.progressPhotos.shootId, db.photoShoots.id),
      );

  $$PhotoShootsTableProcessedTableManager get shootId {
    final $_column = $_itemColumn<String>('shoot_id')!;

    final manager = $$PhotoShootsTableTableManager(
      $_db,
      $_db.photoShoots,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_shootIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ProgressPhotosTableFilterComposer
    extends Composer<_$AppDatabase, $ProgressPhotosTable> {
  $$ProgressPhotosTableFilterComposer({
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

  ColumnFilters<String> get poseId => $composableBuilder(
    column: $table.poseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get takenAt => $composableBuilder(
    column: $table.takenAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PhotoShootsTableFilterComposer get shootId {
    final $$PhotoShootsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.shootId,
      referencedTable: $db.photoShoots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhotoShootsTableFilterComposer(
            $db: $db,
            $table: $db.photoShoots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProgressPhotosTableOrderingComposer
    extends Composer<_$AppDatabase, $ProgressPhotosTable> {
  $$ProgressPhotosTableOrderingComposer({
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

  ColumnOrderings<String> get poseId => $composableBuilder(
    column: $table.poseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get takenAt => $composableBuilder(
    column: $table.takenAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PhotoShootsTableOrderingComposer get shootId {
    final $$PhotoShootsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.shootId,
      referencedTable: $db.photoShoots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhotoShootsTableOrderingComposer(
            $db: $db,
            $table: $db.photoShoots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProgressPhotosTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProgressPhotosTable> {
  $$ProgressPhotosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get poseId =>
      $composableBuilder(column: $table.poseId, builder: (column) => column);

  GeneratedColumn<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => column,
  );

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<int> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumn<DateTime> get takenAt =>
      $composableBuilder(column: $table.takenAt, builder: (column) => column);

  $$PhotoShootsTableAnnotationComposer get shootId {
    final $$PhotoShootsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.shootId,
      referencedTable: $db.photoShoots,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhotoShootsTableAnnotationComposer(
            $db: $db,
            $table: $db.photoShoots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProgressPhotosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProgressPhotosTable,
          ProgressPhoto,
          $$ProgressPhotosTableFilterComposer,
          $$ProgressPhotosTableOrderingComposer,
          $$ProgressPhotosTableAnnotationComposer,
          $$ProgressPhotosTableCreateCompanionBuilder,
          $$ProgressPhotosTableUpdateCompanionBuilder,
          (ProgressPhoto, $$ProgressPhotosTableReferences),
          ProgressPhoto,
          PrefetchHooks Function({bool shootId})
        > {
  $$ProgressPhotosTableTableManager(
    _$AppDatabase db,
    $ProgressPhotosTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProgressPhotosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProgressPhotosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProgressPhotosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> shootId = const Value.absent(),
                Value<String> poseId = const Value.absent(),
                Value<String> relativePath = const Value.absent(),
                Value<int> width = const Value.absent(),
                Value<int> height = const Value.absent(),
                Value<int> bytes = const Value.absent(),
                Value<DateTime> takenAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProgressPhotosCompanion(
                id: id,
                shootId: shootId,
                poseId: poseId,
                relativePath: relativePath,
                width: width,
                height: height,
                bytes: bytes,
                takenAt: takenAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String shootId,
                required String poseId,
                required String relativePath,
                Value<int> width = const Value.absent(),
                Value<int> height = const Value.absent(),
                Value<int> bytes = const Value.absent(),
                required DateTime takenAt,
                Value<int> rowid = const Value.absent(),
              }) => ProgressPhotosCompanion.insert(
                id: id,
                shootId: shootId,
                poseId: poseId,
                relativePath: relativePath,
                width: width,
                height: height,
                bytes: bytes,
                takenAt: takenAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProgressPhotosTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({shootId = false}) {
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
                    if (shootId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.shootId,
                        referencedTable: $$ProgressPhotosTableReferences
                            ._shootIdTable(db),
                        referencedColumn: $$ProgressPhotosTableReferences
                            ._shootIdTable(db)
                            .id,
                      ) as T;
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

typedef $$ProgressPhotosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProgressPhotosTable,
      ProgressPhoto,
      $$ProgressPhotosTableFilterComposer,
      $$ProgressPhotosTableOrderingComposer,
      $$ProgressPhotosTableAnnotationComposer,
      $$ProgressPhotosTableCreateCompanionBuilder,
      $$ProgressPhotosTableUpdateCompanionBuilder,
      (ProgressPhoto, $$ProgressPhotosTableReferences),
      ProgressPhoto,
      PrefetchHooks Function({bool shootId})
    >;
typedef $$PhotoPosesTableCreateCompanionBuilder = PhotoPosesCompanion Function({
  required String id,
  required String name,
  required int orderIndex,
  Value<String?> guidance,
  Value<bool> enabled,
  Value<int> rowid,
});
typedef $$PhotoPosesTableUpdateCompanionBuilder = PhotoPosesCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<int> orderIndex,
  Value<String?> guidance,
  Value<bool> enabled,
  Value<int> rowid,
});

class $$PhotoPosesTableFilterComposer
    extends Composer<_$AppDatabase, $PhotoPosesTable> {
  $$PhotoPosesTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get guidance => $composableBuilder(
    column: $table.guidance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PhotoPosesTableOrderingComposer
    extends Composer<_$AppDatabase, $PhotoPosesTable> {
  $$PhotoPosesTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get guidance => $composableBuilder(
    column: $table.guidance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PhotoPosesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PhotoPosesTable> {
  $$PhotoPosesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get guidance =>
      $composableBuilder(column: $table.guidance, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);
}

class $$PhotoPosesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PhotoPosesTable,
          PhotoPose,
          $$PhotoPosesTableFilterComposer,
          $$PhotoPosesTableOrderingComposer,
          $$PhotoPosesTableAnnotationComposer,
          $$PhotoPosesTableCreateCompanionBuilder,
          $$PhotoPosesTableUpdateCompanionBuilder,
          (
            PhotoPose,
            BaseReferences<_$AppDatabase, $PhotoPosesTable, PhotoPose>,
          ),
          PhotoPose,
          PrefetchHooks Function()
        > {
  $$PhotoPosesTableTableManager(_$AppDatabase db, $PhotoPosesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PhotoPosesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PhotoPosesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PhotoPosesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<String?> guidance = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PhotoPosesCompanion(
                id: id,
                name: name,
                orderIndex: orderIndex,
                guidance: guidance,
                enabled: enabled,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required int orderIndex,
                Value<String?> guidance = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PhotoPosesCompanion.insert(
                id: id,
                name: name,
                orderIndex: orderIndex,
                guidance: guidance,
                enabled: enabled,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PhotoPosesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PhotoPosesTable,
      PhotoPose,
      $$PhotoPosesTableFilterComposer,
      $$PhotoPosesTableOrderingComposer,
      $$PhotoPosesTableAnnotationComposer,
      $$PhotoPosesTableCreateCompanionBuilder,
      $$PhotoPosesTableUpdateCompanionBuilder,
      (PhotoPose, BaseReferences<_$AppDatabase, $PhotoPosesTable, PhotoPose>),
      PhotoPose,
      PrefetchHooks Function()
    >;
typedef $$MeasurementsTableCreateCompanionBuilder =
    MeasurementsCompanion Function({
      Value<int> id,
      required DateTime measuredOn,
      required MeasurementSite site,
      required double cm,
      Value<String?> note,
    });
typedef $$MeasurementsTableUpdateCompanionBuilder =
    MeasurementsCompanion Function({
      Value<int> id,
      Value<DateTime> measuredOn,
      Value<MeasurementSite> site,
      Value<double> cm,
      Value<String?> note,
    });

class $$MeasurementsTableFilterComposer
    extends Composer<_$AppDatabase, $MeasurementsTable> {
  $$MeasurementsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get measuredOn => $composableBuilder(
    column: $table.measuredOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<MeasurementSite, MeasurementSite, String>
  get site => $composableBuilder(
    column: $table.site,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<double> get cm => $composableBuilder(
    column: $table.cm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MeasurementsTableOrderingComposer
    extends Composer<_$AppDatabase, $MeasurementsTable> {
  $$MeasurementsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get measuredOn => $composableBuilder(
    column: $table.measuredOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get site => $composableBuilder(
    column: $table.site,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get cm => $composableBuilder(
    column: $table.cm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MeasurementsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MeasurementsTable> {
  $$MeasurementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get measuredOn => $composableBuilder(
    column: $table.measuredOn,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<MeasurementSite, String> get site =>
      $composableBuilder(column: $table.site, builder: (column) => column);

  GeneratedColumn<double> get cm =>
      $composableBuilder(column: $table.cm, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);
}

class $$MeasurementsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MeasurementsTable,
          Measurement,
          $$MeasurementsTableFilterComposer,
          $$MeasurementsTableOrderingComposer,
          $$MeasurementsTableAnnotationComposer,
          $$MeasurementsTableCreateCompanionBuilder,
          $$MeasurementsTableUpdateCompanionBuilder,
          (
            Measurement,
            BaseReferences<_$AppDatabase, $MeasurementsTable, Measurement>,
          ),
          Measurement,
          PrefetchHooks Function()
        > {
  $$MeasurementsTableTableManager(_$AppDatabase db, $MeasurementsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MeasurementsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MeasurementsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MeasurementsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> measuredOn = const Value.absent(),
                Value<MeasurementSite> site = const Value.absent(),
                Value<double> cm = const Value.absent(),
                Value<String?> note = const Value.absent(),
              }) => MeasurementsCompanion(
                id: id,
                measuredOn: measuredOn,
                site: site,
                cm: cm,
                note: note,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime measuredOn,
                required MeasurementSite site,
                required double cm,
                Value<String?> note = const Value.absent(),
              }) => MeasurementsCompanion.insert(
                id: id,
                measuredOn: measuredOn,
                site: site,
                cm: cm,
                note: note,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MeasurementsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MeasurementsTable,
      Measurement,
      $$MeasurementsTableFilterComposer,
      $$MeasurementsTableOrderingComposer,
      $$MeasurementsTableAnnotationComposer,
      $$MeasurementsTableCreateCompanionBuilder,
      $$MeasurementsTableUpdateCompanionBuilder,
      (
        Measurement,
        BaseReferences<_$AppDatabase, $MeasurementsTable, Measurement>,
      ),
      Measurement,
      PrefetchHooks Function()
    >;
typedef $$FormClipsTableCreateCompanionBuilder = FormClipsCompanion Function({
  required String id,
  required String exerciseId,
  required String relativePath,
  required DateTime recordedAt,
  Value<int> durationSec,
  Value<int> bytes,
  Value<String?> note,
  Value<int> rowid,
});
typedef $$FormClipsTableUpdateCompanionBuilder = FormClipsCompanion Function({
  Value<String> id,
  Value<String> exerciseId,
  Value<String> relativePath,
  Value<DateTime> recordedAt,
  Value<int> durationSec,
  Value<int> bytes,
  Value<String?> note,
  Value<int> rowid,
});

class $$FormClipsTableFilterComposer
    extends Composer<_$AppDatabase, $FormClipsTable> {
  $$FormClipsTableFilterComposer({
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

  ColumnFilters<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FormClipsTableOrderingComposer
    extends Composer<_$AppDatabase, $FormClipsTable> {
  $$FormClipsTableOrderingComposer({
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

  ColumnOrderings<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FormClipsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FormClipsTable> {
  $$FormClipsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get exerciseId => $composableBuilder(
    column: $table.exerciseId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => column,
  );

  GeneratedColumn<int> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);
}

class $$FormClipsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FormClipsTable,
          FormClip,
          $$FormClipsTableFilterComposer,
          $$FormClipsTableOrderingComposer,
          $$FormClipsTableAnnotationComposer,
          $$FormClipsTableCreateCompanionBuilder,
          $$FormClipsTableUpdateCompanionBuilder,
          (FormClip, BaseReferences<_$AppDatabase, $FormClipsTable, FormClip>),
          FormClip,
          PrefetchHooks Function()
        > {
  $$FormClipsTableTableManager(_$AppDatabase db, $FormClipsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FormClipsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FormClipsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FormClipsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> exerciseId = const Value.absent(),
                Value<String> relativePath = const Value.absent(),
                Value<DateTime> recordedAt = const Value.absent(),
                Value<int> durationSec = const Value.absent(),
                Value<int> bytes = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FormClipsCompanion(
                id: id,
                exerciseId: exerciseId,
                relativePath: relativePath,
                recordedAt: recordedAt,
                durationSec: durationSec,
                bytes: bytes,
                note: note,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String exerciseId,
                required String relativePath,
                required DateTime recordedAt,
                Value<int> durationSec = const Value.absent(),
                Value<int> bytes = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FormClipsCompanion.insert(
                id: id,
                exerciseId: exerciseId,
                relativePath: relativePath,
                recordedAt: recordedAt,
                durationSec: durationSec,
                bytes: bytes,
                note: note,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FormClipsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FormClipsTable,
      FormClip,
      $$FormClipsTableFilterComposer,
      $$FormClipsTableOrderingComposer,
      $$FormClipsTableAnnotationComposer,
      $$FormClipsTableCreateCompanionBuilder,
      $$FormClipsTableUpdateCompanionBuilder,
      (FormClip, BaseReferences<_$AppDatabase, $FormClipsTable, FormClip>),
      FormClip,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db, _db.sessions);
  $$SetLogsTableTableManager get setLogs =>
      $$SetLogsTableTableManager(_db, _db.setLogs);
  $$StallCountersTableTableManager get stallCounters =>
      $$StallCountersTableTableManager(_db, _db.stallCounters);
  $$BodyweightsTableTableManager get bodyweights =>
      $$BodyweightsTableTableManager(_db, _db.bodyweights);
  $$CardioLogsTableTableManager get cardioLogs =>
      $$CardioLogsTableTableManager(_db, _db.cardioLogs);
  $$FoodLogsTableTableManager get foodLogs =>
      $$FoodLogsTableTableManager(_db, _db.foodLogs);
  $$NigglesTableTableManager get niggles =>
      $$NigglesTableTableManager(_db, _db.niggles);
  $$PhotoShootsTableTableManager get photoShoots =>
      $$PhotoShootsTableTableManager(_db, _db.photoShoots);
  $$ProgressPhotosTableTableManager get progressPhotos =>
      $$ProgressPhotosTableTableManager(_db, _db.progressPhotos);
  $$PhotoPosesTableTableManager get photoPoses =>
      $$PhotoPosesTableTableManager(_db, _db.photoPoses);
  $$MeasurementsTableTableManager get measurements =>
      $$MeasurementsTableTableManager(_db, _db.measurements);
  $$FormClipsTableTableManager get formClips =>
      $$FormClipsTableTableManager(_db, _db.formClips);
}
