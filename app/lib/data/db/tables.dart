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

// =========================================================== v3: GPS runs
//
// Location history is the most sensitive thing this app now holds — a trail
// that starts at the front door is a home address. It lives here, in the
// app-private database, and leaves the phone only inside a backup Saad makes
// himself. Nothing uploads it; test/privacy_audit_test.dart keeps it that way.

/// Where a GPS run is in its life.
enum RunStatus { recording, paused, finished, discarded }

/// What a GPS recording is: a run, or a hike (v4). Same trail, same table;
/// a hike is counted for its climb rather than its pace.
enum RunKind { run, hike }

/// One GPS-tracked run, or hike.
///
/// The link columns mirror `set_logs`: a run started from a programme day
/// stores the day, week and prescription it belonged to, DENORMALISED, so the
/// history survives the programme being edited. A free run leaves them null
/// and still appears on the calendar through [runOn].
///
/// Times are epoch MILLISECONDS in plain integers. Drift stores a DateTime as
/// whole seconds, which is too coarse for a pace.
class Runs extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Run or hike. v4; every run before it was a run.
  TextColumn get kind =>
      textEnum<RunKind>().withDefault(const Constant('run'))();
  IntColumn get sessionId => integer().nullable().references(
    Sessions,
    #id,
    onDelete: KeyAction.setNull,
  )();
  IntColumn get weekNo => integer().nullable()();
  TextColumn get dayId => text().nullable()();
  TextColumn get prescriptionId => text().nullable()();
  TextColumn get exerciseId => text().nullable()();

  /// The set this run was logged as, when it came from the session runner.
  IntColumn get setLogId => integer().nullable()();

  /// Local midnight of the start: the calendar key.
  DateTimeColumn get runOn => dateTime()();
  IntColumn get startedAtMs => integer()();
  IntColumn get endedAtMs => integer().nullable()();

  /// Time actually moving: elapsed minus pauses.
  IntColumn get movingMs => integer().withDefault(const Constant(0))();
  RealColumn get distanceM => real().withDefault(const Constant(0))();
  RealColumn get maxSpeedMps => real().nullable()();
  RealColumn get elevGainM => real().nullable()();

  /// Metres descended and the highest point, by the phone's altimeter. v4.
  RealColumn get elevLossM => real().nullable()();
  RealColumn get maxAltM => real().nullable()();
  RealColumn get startLat => real().nullable()();
  RealColumn get startLng => real().nullable()();
  RealColumn get endLat => real().nullable()();
  RealColumn get endLng => real().nullable()();

  /// 1-10 RPE, asked at the end.
  IntColumn get effort => integer().nullable()();
  TextColumn get status =>
      textEnum<RunStatus>().withDefault(const Constant('recording'))();
  TextColumn get note => text().nullable()();
}

/// One accepted GPS fix. A row per point, not a blob: the backup writes rows
/// as JSON, and a Uint8List does not survive that round trip.
class RunPoints extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get runId =>
      integer().references(Runs, #id, onDelete: KeyAction.cascade)();
  IntColumn get seq => integer()();
  IntColumn get tMs => integer()();
  RealColumn get lat => real()();
  RealColumn get lng => real()();
  RealColumn get accuracyM => real().nullable()();
  RealColumn get altitudeM => real().nullable()();
  RealColumn get speedMps => real().nullable()();

  /// True on the first fix after a pause or an app restart: the trail is
  /// drawn broken here and no distance is counted across the gap.
  BoolColumn get segmentStart => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {runId, seq},
  ];
}

// =========================================================== v3: Fuel
//
// Every row stores its own numbers, like `set_logs` stores its exercise id:
// the meal plan will be retuned, and last month's log must still say what was
// actually eaten.

/// What happened to a planned meal.
enum MealStatus { planned, eaten, partial, skipped }

extension MealStatusPortion on MealStatus {
  /// What the meal's macros are multiplied by.
  ///
  /// `planned` is zero: a meal he has chosen but not eaten has not fed him,
  /// and counting it would make every morning look like a day already won.
  double get portion => switch (this) {
    MealStatus.eaten => 1.0,
    MealStatus.partial => 0.5,
    MealStatus.skipped => 0.0,
    MealStatus.planned => 0.0,
  };

  String get label => switch (this) {
    MealStatus.eaten => 'Eaten',
    MealStatus.partial => 'Half',
    MealStatus.skipped => 'Skipped',
    MealStatus.planned => 'Planned',
  };
}

/// One meal slot on one date: which option was chosen and whether it was
/// eaten. `planned` records a swap made before eating.
class MealLogs extends Table {
  DateTimeColumn get loggedOn => dateTime()();
  TextColumn get slotId => text()();
  TextColumn get templateId => text()();
  TextColumn get status => textEnum<MealStatus>()();

  /// 1.0 eaten, 0.5 half, 0 skipped. What the totals multiply by.
  RealColumn get portion => real().withDefault(const Constant(1.0))();
  IntColumn get kcal => integer().withDefault(const Constant(0))();
  RealColumn get proteinG => real().withDefault(const Constant(0))();
  RealColumn get fatG => real().withDefault(const Constant(0))();
  RealColumn get carbsG => real().withDefault(const Constant(0))();
  IntColumn get loggedAtMs => integer().nullable()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {loggedOn, slotId};
}

/// Water for one date, in ml.
class WaterLogs extends Table {
  DateTimeColumn get loggedOn => dateTime()();
  IntColumn get ml => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {loggedOn};
}

/// A supplement ticked off on one date.
class SupplementLogs extends Table {
  DateTimeColumn get loggedOn => dateTime()();
  TextColumn get supplementId => text()();
  IntColumn get takenAtMs => integer().nullable()();

  @override
  Set<Column> get primaryKey => {loggedOn, supplementId};
}

/// A calorie adjustment Saad APPLIED — the +250 when the scale stalls, the
/// cut when the waist runs ahead.
///
/// v2 recomputed the bump on every read and stored nothing, so the moment it
/// worked (weight rising again) the target silently fell back. An applied
/// adjustment stays applied until it is reverted.
class NutritionAdjustments extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get appliedOn => dateTime()();

  /// The booster or module from the Fuel plan, when one was chosen.
  TextColumn get moduleId => text().nullable()();
  IntColumn get kcalDelta => integer()();
  TextColumn get reason => text()();
  DateTimeColumn get revertedOn => dateTime().nullable()();
}

/// One change he made to one date in the planner (v5): an entry of his own,
/// a class skipped, Friday's shift marked, the session moved. The timetable
/// itself is bundled data and never changes; these rows are laid over it.
///
/// `kind` is the domain's EntryKind name; minutes are after midnight. Rows
/// are `PlannerRow`: `PlannerEntry` is the domain's.
@DataClassName('PlannerRow')
class PlannerEntries extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Local midnight of the date it applies to.
  DateTimeColumn get onDate => dateTime()();
  TextColumn get kind => text()();
  TextColumn get blockId => text().nullable()();
  TextColumn get title => text().nullable()();
  IntColumn get startMin => integer().nullable()();
  IntColumn get endMin => integer().nullable()();
  BoolColumn get remind => boolean().withDefault(const Constant(false))();
  TextColumn get category => text().nullable()();
}
