import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../data/db/tables.dart';
import '../../data/session_service.dart';
import '../../domain/intervals/interval_engine.dart';
import '../../domain/models/day.dart';
import '../../domain/models/prescription.dart';

/// One movement's worth of runner state.
class RunnerItem {
  const RunnerItem({
    required this.prescription,
    required this.planned,
    required this.logged,
  });

  final Prescription prescription;

  /// Every set to perform, expanded for per-side work.
  final List<({int setIndex, String? side})> planned;

  /// What has actually been recorded, in order.
  final List<SetLog> logged;

  int get doneCount => logged.where((l) => !l.isWarmup).length;
  int get totalCount => planned.length;
  bool get isComplete => doneCount >= totalCount;

  ({int setIndex, String? side})? get nextSet =>
      doneCount < planned.length ? planned[doneCount] : null;

  /// The load to pre-fill: whatever was last used for this prescription in
  /// this session, otherwise the prescribed start.
  double? get suggestedLoadKg {
    for (final l in logged.reversed) {
      if (!l.isWarmup && l.loadKg != null) return l.loadKg;
    }
    return prescription.startLoadKg;
  }
}

/// The whole runner state for one session.
class RunnerState {
  const RunnerState({
    required this.session,
    required this.day,
    required this.items,
    required this.focusIndex,
    this.restEndsAt,
    this.restLabel,
    this.restSetNumber,
    this.shortMode = false,
  });

  final Session session;
  final Day day;
  final List<RunnerItem> items;

  /// Which movement is in focus. One at a time — you are between heavy sets,
  /// not browsing.
  final int focusIndex;

  /// Null when no rest is running.
  final DateTime? restEndsAt;
  final String? restLabel;
  final int? restSetNumber;

  /// "I only have 40 minutes": keeps the lead movement and the first
  /// superset, drops the rest.
  final bool shortMode;

  RunnerItem? get focus =>
      focusIndex >= 0 && focusIndex < items.length ? items[focusIndex] : null;

  bool get isResting => restEndsAt != null;

  int get doneSets => items.fold(0, (a, i) => a + i.doneCount);
  int get plannedSets => visibleItems.fold(0, (a, i) => a + i.totalCount);

  /// The movements actually on the card stack, honouring short mode and
  /// optional prescriptions.
  List<RunnerItem> get visibleItems =>
      items.where((i) => !i.prescription.optional || !shortMode).toList();

  double get progress =>
      plannedSets == 0 ? 0 : (doneSets / plannedSets).clamp(0, 1);

  /// Minutes since the session started, for the time budget.
  int elapsedMinutes(DateTime now) {
    final start = session.startedAt;
    if (start == null) return 0;
    return now.difference(start).inMinutes;
  }

  /// True when the session is running long and there is still work left —
  /// the moment to offer cutting the last superset.
  bool isRunningLong(DateTime now) =>
      elapsedMinutes(now) >= 45 &&
      !shortMode &&
      visibleItems.where((i) => !i.isComplete).length > 1;

  RunnerState copyWith({
    Session? session,
    List<RunnerItem>? items,
    int? focusIndex,
    DateTime? restEndsAt,
    bool clearRest = false,
    String? restLabel,
    int? restSetNumber,
    bool? shortMode,
  }) => RunnerState(
    session: session ?? this.session,
    day: day,
    items: items ?? this.items,
    focusIndex: focusIndex ?? this.focusIndex,
    restEndsAt: clearRest ? null : (restEndsAt ?? this.restEndsAt),
    restLabel: clearRest ? null : (restLabel ?? this.restLabel),
    restSetNumber: clearRest ? null : (restSetNumber ?? this.restSetNumber),
    shortMode: shortMode ?? this.shortMode,
  );
}

/// Drives the session runner.
///
/// Every mutation writes to the database before it updates state. There is no
/// "unsaved" state to lose.
class SessionController {
  SessionController({
    required this.service,
    required this.db,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final SessionService service;
  final AppDatabase db;
  final DateTime Function() _clock;

  /// Rebuilds runner state from the database. The single source of truth.
  Future<RunnerState> load(
    Session session,
    Day day, {
    int focusIndex = 0,
    bool shortMode = false,
    DateTime? restEndsAt,
    String? restLabel,
    int? restSetNumber,
  }) async {
    final logs = await db.setsForSession(session.id);
    final items = <RunnerItem>[];
    for (final p in day.loggedPrescriptions) {
      items.add(
        RunnerItem(
          prescription: p,
          planned: SessionService.plannedSets(p),
          logged: logs.where((l) => l.prescriptionId == p.id).toList()
            ..sort((a, b) => a.completedAt.compareTo(b.completedAt)),
        ),
      );
    }
    return RunnerState(
      session: session,
      day: day,
      items: items,
      focusIndex: focusIndex.clamp(0, items.isEmpty ? 0 : items.length - 1),
      shortMode: shortMode,
      restEndsAt: restEndsAt,
      restLabel: restLabel,
      restSetNumber: restSetNumber,
    );
  }

  /// Records a set and starts the rest timer.
  ///
  /// Returns the new state plus when the rest ends, so the caller can schedule
  /// the notification.
  Future<RunnerState> logSet(
    RunnerState state, {
    required Prescription prescription,
    required int setIndex,
    String? side,
    int? reps,
    double? loadKg,
    int? durationSec,
    int? distanceM,
    int? rir,
    String? note,
    bool isWarmup = false,
    required String exerciseName,
  }) async {
    await service.logSet(
      state.session.id,
      SetEntry(
        prescriptionId: prescription.id,
        exerciseId: prescription.exerciseId,
        setIndex: setIndex,
        side: side,
        reps: reps,
        loadKg: loadKg,
        durationSec: durationSec,
        distanceM: distanceM,
        rir: rir,
        note: note,
        isWarmup: isWarmup,
        targetRepsMin: prescription.repsMin,
        targetRepsMax: prescription.repsMax,
        targetLoadKg: prescription.startLoadKg,
      ),
    );

    final restSec = _restAfter(state, prescription);
    final ends = restSec > 0 ? _clock().add(Duration(seconds: restSec)) : null;

    return load(
      state.session,
      state.day,
      focusIndex: state.focusIndex,
      shortMode: state.shortMode,
      restEndsAt: ends,
      restLabel: exerciseName,
      restSetNumber: setIndex,
    );
  }

  /// How long to rest after a given set.
  ///
  /// Inside a superset only the LAST member carries a rest — that is the
  /// whole reason supersets fit the sixty-minute ceiling. Logging the first
  /// member means going straight to the second.
  int _restAfter(RunnerState state, Prescription p) {
    if (p.groupId == null) return p.restSec;
    final group = state.day.sections
        .expand((s) => s.groups)
        .firstWhere(
          (g) => g.isNotEmpty && g.first.groupId == p.groupId,
          orElse: () => [p],
        );
    final isLast = group.isNotEmpty && group.last.id == p.id;
    return isLast ? group.last.restSec : 0;
  }

  Future<RunnerState> undoLast(RunnerState state) async {
    final logs = await db.setsForSession(state.session.id);
    if (logs.isEmpty) return state;
    logs.sort((a, b) => a.completedAt.compareTo(b.completedAt));
    await service.deleteSet(logs.last.id);
    return load(
      state.session,
      state.day,
      focusIndex: state.focusIndex,
      shortMode: state.shortMode,
    );
  }

  RunnerState focusOn(RunnerState state, int index) =>
      state.copyWith(focusIndex: index);

  RunnerState clearRest(RunnerState state) => state.copyWith(clearRest: true);

  RunnerState adjustRest(RunnerState state, int seconds) {
    final ends = state.restEndsAt;
    if (ends == null) return state;
    final next = ends.add(Duration(seconds: seconds));
    if (!next.isAfter(_clock())) return state.copyWith(clearRest: true);
    return state.copyWith(restEndsAt: next);
  }

  /// Drops the optional work. The main lift is never what gets cut.
  RunnerState enterShortMode(RunnerState state) =>
      state.copyWith(shortMode: true);

  Future<void> finish(
    RunnerState state, {
    double? bodyweightKg,
    int? rpe,
    String? note,
  }) async {
    final incomplete = state.visibleItems.any((i) => !i.isComplete);
    await service.finish(
      state.session.id,
      partial: incomplete,
      wasShortened: state.shortMode,
      bodyweightKg: bodyweightKg,
      rpeOverall: rpe,
      note: note,
    );
  }

  Future<void> logNiggle({
    required RunnerState state,
    required NiggleSite site,
    required int severity,
    String? exerciseId,
    String? note,
  }) => service.logNiggle(
    site: site,
    severity: severity,
    exerciseId: exerciseId,
    sessionId: state.session.id,
    note: note,
  );

  /// The rest interval for the countdown widget.
  static IntervalSpec restSpec(int seconds, String label) =>
      IntervalSpec.rest(seconds, label: label);
}

final sessionControllerProvider =
    Provider.family<SessionController, AppDatabase>(
      (ref, db) => SessionController(service: SessionService(db), db: db),
    );
