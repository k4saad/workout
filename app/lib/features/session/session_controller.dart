import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../data/db/tables.dart';
import '../../data/session_service.dart';
import '../../domain/intervals/interval_engine.dart';
import '../../domain/models/day.dart';
import '../../domain/models/prescription.dart';
import '../../domain/progression/progression_engine.dart';

/// One movement's worth of runner state.
class RunnerItem {
  const RunnerItem({
    required this.prescription,
    required this.planned,
    required this.logged,
    this.suggestion,
  });

  final Prescription prescription;

  /// What the engine said to do today, worked out when the session opened.
  /// Null when there was none to ask (a test, or a caller without one).
  final LoadSuggestion? suggestion;

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
  /// this session; otherwise the SUGGESTION; only then the programme start.
  ///
  /// v2 skipped the middle step, so the stepper showed week 1's load every
  /// week whatever the engine had earned (coach review §0 item 5).
  double? get suggestedLoadKg {
    for (final l in logged.reversed) {
      if (!l.isWarmup && l.loadKg != null) return l.loadKg;
    }
    return suggestion?.suggestedKg ?? prescription.startLoadKg;
  }

  /// The rep range this session aims at: the suggestion's (which may have
  /// crept above the prescription's), else the prescription's own.
  int get targetRepsMin => suggestion?.repTargetMin ?? prescription.repsMin;
  int get targetRepsMax => suggestion?.repTargetMax ?? prescription.repsMax;

  /// What each stepper starts at before it is touched. An untouched stepper
  /// logs exactly this — v2 showed 30 s on a plank stepper and logged null.
  ({int? reps, double? loadKg, int? durationSec, int? distanceM}) get prefill {
    final kind = SessionService.inputKindFor(prescription);
    final counted =
        kind == SetInputKind.repsAndLoad || kind == SetInputKind.reps;
    return (
      reps: counted ? targetRepsMin : null,
      loadKg: kind == SetInputKind.repsAndLoad ? suggestedLoadKg : null,
      durationSec: kind == SetInputKind.duration ? targetRepsMax : null,
      distanceM: kind == SetInputKind.distance ? targetRepsMax : null,
    );
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
    this.suggestions = const {},
  });

  final Session session;
  final Day day;
  final List<RunnerItem> items;

  /// prescriptionId -> today's suggestion. Carried across every reload, so
  /// what was pre-filled is what gets logged as the target.
  final Map<String, LoadSuggestion> suggestions;

  /// Which movement is in focus. One at a time — you are between heavy sets,
  /// not browsing.
  final int focusIndex;

  /// Null when no rest is running.
  final DateTime? restEndsAt;
  final String? restLabel;
  final int? restSetNumber;

  /// Running long: the programme's rule 7 is in force — "cut the last
  /// superset, not the main lift, not the warm-up".
  final bool shortMode;

  RunnerItem? get focus =>
      focusIndex >= 0 && focusIndex < items.length ? items[focusIndex] : null;

  bool get isResting => restEndsAt != null;

  int get doneSets => visibleItems.fold(0, (a, i) => a + i.doneCount);
  int get plannedSets => visibleItems.fold(0, (a, i) => a + i.totalCount);

  /// What short mode takes off the card stack, whether or not it is on:
  /// the day's LAST superset (programme rule 7), plus anything optional.
  ///
  /// Never the first movement — the main lift — and warm-up drills are not
  /// items at all. A last superset already finished is not cut: there is no
  /// time left to save in it.
  List<RunnerItem> get shortModeCut {
    if (items.isEmpty) return const [];
    final lead = items.first;
    String? lastGroup;
    for (final i in items) {
      if (i != lead && i.prescription.groupId != null) {
        lastGroup = i.prescription.groupId;
      }
    }
    final group = [
      for (final i in items)
        if (lastGroup != null &&
            i != lead &&
            i.prescription.groupId == lastGroup)
          i,
    ];
    final cutGroup = group.any((i) => !i.isComplete)
        ? group
        : const <RunnerItem>[];
    return [
      for (final i in items)
        if (i != lead && (cutGroup.contains(i) || i.prescription.optional)) i,
    ];
  }

  /// The movements actually on the card stack, honouring short mode.
  List<RunnerItem> get visibleItems {
    if (!shortMode) return items;
    final cut = shortModeCut;
    return [
      for (final i in items)
        if (!cut.contains(i)) i,
    ];
  }

  double get progress =>
      plannedSets == 0 ? 0 : (doneSets / plannedSets).clamp(0, 1);

  /// Minutes since the session started, for the time budget.
  int elapsedMinutes(DateTime now) {
    final start = session.startedAt;
    if (start == null) return 0;
    return now.difference(start).inMinutes;
  }

  /// True when the session is running long, there is still work left, and
  /// short mode would actually cut something — the moment to offer it.
  bool isRunningLong(DateTime now) =>
      elapsedMinutes(now) >= 45 &&
      !shortMode &&
      shortModeCut.isNotEmpty &&
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
    suggestions: suggestions,
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
  ///
  /// [suggestions] (from `SuggestionService.forSession`) are what the runner
  /// pre-fills and logs as each set's target. Pass them on the first load;
  /// every reload after a set carries them over.
  Future<RunnerState> load(
    Session session,
    Day day, {
    int focusIndex = 0,
    bool shortMode = false,
    DateTime? restEndsAt,
    String? restLabel,
    int? restSetNumber,
    Map<String, LoadSuggestion> suggestions = const {},
  }) async {
    final logs = await db.setsForSession(session.id);
    final items = <RunnerItem>[];
    for (final p in day.loggedPrescriptions) {
      items.add(
        RunnerItem(
          prescription: p,
          planned: SessionService.plannedSets(p),
          logged: logs.where((l) => l.prescriptionId == p.id).toList()
            ..sort(_byTimeLogged),
          suggestion: suggestions[p.id],
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
      suggestions: suggestions,
    );
  }

  /// Drift keeps whole seconds; the row id breaks a tie in logging order.
  static int _byTimeLogged(SetLog a, SetLog b) {
    final t = a.completedAt.compareTo(b.completedAt);
    return t != 0 ? t : a.id.compareTo(b.id);
  }

  /// Records a set and starts the rest timer.
  ///
  /// The set's target is the SUGGESTION's rep range and load, not the
  /// prescription's: that is what makes rep creep accumulate from one week
  /// to the next (coach review §0 item 4).
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
    final s = state.suggestions[prescription.id];
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
        targetRepsMin: s?.repTargetMin ?? prescription.repsMin,
        targetRepsMax: s?.repTargetMax ?? prescription.repsMax,
        targetLoadKg: s?.suggestedKg ?? prescription.startLoadKg,
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
      suggestions: state.suggestions,
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
    logs.sort(_byTimeLogged);
    await service.deleteSet(logs.last.id);
    return load(
      state.session,
      state.day,
      focusIndex: state.focusIndex,
      shortMode: state.shortMode,
      suggestions: state.suggestions,
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

  /// Programme rule 7: cuts the last superset. The main lift is never what
  /// gets cut. See [RunnerState.shortModeCut].
  RunnerState enterShortMode(RunnerState state) =>
      state.copyWith(shortMode: true);

  /// Closes the session and writes back each trained movement's stall
  /// counter — the engine's "repeat, stall 1 of 2" only means something if
  /// the next session knows about it. v2 never wrote it, so the back-off
  /// never fired.
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
    for (final item in state.items) {
      final s = item.suggestion;
      if (s == null || item.doneCount == 0) continue;
      await db.setStall(
        item.prescription.exerciseId,
        item.prescription.id,
        s.newStallCount,
      );
    }
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
