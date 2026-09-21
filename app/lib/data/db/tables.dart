import 'package:drift/drift.dart';

/// Session lifecycle state.
enum SessionStatus { planned, inProgress, completed, partial, skipped }

/// What kind of cardio a row records.
enum CardioKind { run, skip, bag, other }

/// Where a niggle was felt.
enum NiggleSite { knee, lowBack, shoulder, elbow, wrist, hip, neck, other }

/// One training session on one date.
///
/// `plannedDate` and `scheduledDate` are separate on purpose: life moves
/// sessions. Adherence is measured against `plannedDate`; the calendar draws
/// the session on `scheduledDate`.
class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get programmeId => text()();
  TextColumn get blockId => text()();
  TextColumn get dayId => text()();
  IntColumn get weekNo => integer()();

  DateTimeColumn get plannedDate => dateTime()();
  DateTimeColumn get scheduledDate => dateTime()();

  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get finishedAt => dateTime().nullable()();

  TextColumn get status =>
      textEnum<SessionStatus>().withDefault(const Constant('planned'))();

  RealColumn get bodyweightKg => real().nullable()();
  IntColumn get rpeOverall => integer().nullable()();
  TextColumn get note => text().nullable()();

  /// True when the session was reconstructed from memory rather than logged
  /// live. You will forget to open the app mid-session a dozen times over
  /// twelve weeks, and the progression engine needs that history anyway.
  BoolColumn get loggedRetroactively =>
      boolean().withDefault(const Constant(false))();

  /// Set when the athlete chose the short version of the session.
  BoolColumn get wasShortened => boolean().withDefault(const Constant(false))();
}

/// One logged set.
///
/// `exerciseId` is DENORMALISED on purpose: exercises get swapped in the
/// editor, and history must survive that. Never resolve history through the
/// live programme JSON.
///
/// `prescriptionId` is stored too, because the progression engine keys on it
/// FIRST — two prescriptions of the same lift in one week (single-leg calf
/// raise at 3x15 Monday and 3x20 Thursday) would otherwise fight each other.
class SetLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId =>
      integer().references(Sessions, #id, onDelete: KeyAction.cascade)();

  TextColumn get prescriptionId => text()();
  TextColumn get exerciseId => text()();

  IntColumn get setIndex => integer()();

  IntColumn get targetRepsMin => integer().nullable()();
  IntColumn get targetRepsMax => integer().nullable()();
  RealColumn get targetLoadKg => real().nullable()();

  IntColumn get reps => integer().nullable()();
  RealColumn get loadKg => real().nullable()();
  IntColumn get durationSec => integer().nullable()();
  IntColumn get distanceM => integer().nullable()();
  IntColumn get rir => integer().nullable()();

  /// Which side, for per-side prescriptions. Null for bilateral work.
  TextColumn get side => text().nullable()();

  /// Ramp sets are logged but excluded from every progression decision and
  /// every volume statistic.
  BoolColumn get isWarmup => boolean().withDefault(const Constant(false))();

  DateTimeColumn get completedAt => dateTime()();
  TextColumn get note => text().nullable()();
}

/// How many consecutive sessions a lift has failed its rep target.
class StallCounters extends Table {
  TextColumn get exerciseId => text()();
  TextColumn get prescriptionId => text()();
  IntColumn get count => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {exerciseId, prescriptionId};
}

/// One weigh-in per day. The date IS the key, so re-entering a morning weight
/// replaces it rather than appending a second row — `insertOnConflictUpdate`
/// resolves against the primary key, not against a unique index.
class Bodyweights extends Table {
  DateTimeColumn get measuredOn => dateTime()();
  RealColumn get kg => real()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {measuredOn};
}

class CardioLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId => integer().nullable()();
  TextColumn get kind => textEnum<CardioKind>()();
  DateTimeColumn get measuredOn => dateTime()();
  IntColumn get durationSec => integer().nullable()();
  IntColumn get distanceM => integer().nullable()();
  IntColumn get rounds => integer().nullable()();
  IntColumn get effort => integer().nullable()();
  TextColumn get note => text().nullable()();
}

/// Deliberately minimal. A number you type, not a food diary.
class FoodLogs extends Table {
  DateTimeColumn get loggedOn => dateTime()();
  IntColumn get kcal => integer().nullable()();
  IntColumn get proteinG => integer().nullable()();
  BoolColumn get hitTarget => boolean().withDefault(const Constant(false))();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {loggedOn};
}

/// Twelve weeks of training alone with no structured way to record that
/// something hurt is how a niggle becomes an injury (audit C15).
class Niggles extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get loggedOn => dateTime()();
  TextColumn get exerciseId => text().nullable()();
  IntColumn get sessionId => integer().nullable()();
  TextColumn get site => textEnum<NiggleSite>()();

  /// 1 = noticed it, 5 = stopped the session.
  IntColumn get severity => integer()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get resolvedOn => dateTime().nullable()();
}
