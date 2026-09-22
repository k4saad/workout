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

/// A measurement site. Waist is the one that tells you whether the surplus is
/// too big — if it grows faster than the lifts, trim the calories.
enum MeasurementSite { waist, chest, upperArm, thigh, neck, hips, calf }

/// One pass in front of the phone.
///
/// A SHOOT is the unit you compare, not an individual photo: four poses on
/// one date, so a comparison is like for like.
class PhotoShoots extends Table {
  TextColumn get id => text()(); // uuid
  DateTimeColumn get shotOn => dateTime()();
  IntColumn get weekNo => integer().nullable()();

  /// Resolved from the bodyweight table within +/- 2 days, so a caption is
  /// never empty and you never type the number twice.
  RealColumn get bodyweightKg => real().nullable()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One photo.
///
/// [filePath] is ALWAYS app-private. Never a MediaStore uri, never anything
/// under /sdcard/Pictures. These are shirtless photos of one person and the
/// storage design is part of the feature, not a preference.
class ProgressPhotos extends Table {
  TextColumn get id => text()();
  TextColumn get shootId =>
      text().references(PhotoShoots, #id, onDelete: KeyAction.cascade)();
  TextColumn get poseId => text()();

  /// Relative to the app documents directory, so a restore onto a different
  /// device with a different sandbox path still finds the file.
  TextColumn get relativePath => text()();

  IntColumn get width => integer().withDefault(const Constant(0))();
  IntColumn get height => integer().withDefault(const Constant(0))();
  IntColumn get bytes => integer().withDefault(const Constant(0))();
  DateTimeColumn get takenAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The poses to shoot. Editable, but four is the right number: enough to see
/// change from every angle, few enough to do in ninety seconds.
class PhotoPoses extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get orderIndex => integer()();
  TextColumn get guidance => text().nullable()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

class Measurements extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get measuredOn => dateTime()();
  TextColumn get site => textEnum<MeasurementSite>()();
  RealColumn get cm => real()();
  TextColumn get note => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {measuredOn, site},
  ];
}

/// A filmed working set. For a lifter with no coach this is worth more than
/// any stock demo — week 1 against week 8 catches a depth drift that no cue
/// list will.
class FormClips extends Table {
  TextColumn get id => text()();
  TextColumn get exerciseId => text()();
  TextColumn get relativePath => text()();
  DateTimeColumn get recordedAt => dateTime()();
  IntColumn get durationSec => integer().withDefault(const Constant(0))();
  IntColumn get bytes => integer().withDefault(const Constant(0))();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
