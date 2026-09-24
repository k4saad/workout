import '../models/enums.dart';
import '../models/prescription.dart';
import '../plates/plate_solver.dart';
import 'logged_set.dart';

/// What to do next for one prescription.
class LoadSuggestion {
  const LoadSuggestion({
    required this.repTargetMin,
    required this.repTargetMax,
    required this.reason,
    this.suggestedKg,
    this.plates,
    this.isStalled = false,
    this.isRepCreep = false,
    this.newStallCount = 0,
    this.smallestStepKg,
    this.warning,
  });

  /// Null for everything that does not progress by kilograms.
  final double? suggestedKg;

  /// The rep range to aim for. May sit above the prescription's own range
  /// when rep creep is running.
  final int repTargetMin;
  final int repTargetMax;

  /// Shown verbatim in the runner. Written to be read between sets.
  final String reason;

  final PlateSolution? plates;
  final bool isStalled;

  /// True when the load is being held because one plate step would be too
  /// big a jump, and the rep target is growing instead.
  final bool isRepCreep;

  /// What to persist back to `stall_counters`.
  final int newStallCount;

  final double? smallestStepKg;
  final String? warning;

  String get repLabel => repTargetMin == repTargetMax
      ? '$repTargetMin'
      : '$repTargetMin–$repTargetMax';

  LoadSuggestion copyWith({int? newStallCount}) => LoadSuggestion(
    suggestedKg: suggestedKg,
    repTargetMin: repTargetMin,
    repTargetMax: repTargetMax,
    reason: reason,
    plates: plates,
    isStalled: isStalled,
    isRepCreep: isRepCreep,
    newStallCount: newStallCount ?? this.newStallCount,
    smallestStepKg: smallestStepKg,
    warning: warning,
  );
}

/// Decides what to put on the bar next.
///
/// Pure. No I/O, no database — the caller hands it history and a stall count
/// and gets a decision back.
///
/// The rule order is docs/02-data-model.md algorithm A. Two parts of it exist
/// specifically because v1's version deadlocked (docs/00-audit.md A1):
///
///  * **Rule 3b, rep creep.** When one lattice step is a bigger jump than
///    `maxJumpPct`, adding weight is the wrong move. The rep range grows
///    instead, which is what a coach does with a light bar and coarse plates.
///  * **Rule 8, the final guard.** A jump that was earned must always produce
///    something — weight or reps. v1 could earn a jump, clamp it to 10%,
///    round that down to zero, and report "earned the jump" while suggesting
///    the same weight forever.
class ProgressionEngine {
  const ProgressionEngine(this.solver);

  final PlateSolver solver;

  /// How much the rep range extends on each creep.
  static const repCreepStep = 2;

  /// [prescription] must be the block-RESOLVED prescription for the week.
  /// [history] must not contain deload or test sessions, nor the session
  /// being run (`SuggestionService` filters them). [blockLoadMultiplier]
  /// scales loads read from history; below 1.0 it also marks a deload week.
  LoadSuggestion suggest({
    required Prescription prescription,
    required List<LoggedSet> history,
    DateTime? now,

    /// When ANY session was last trained, not just this exercise.
    ///
    /// The history window exists to stop a load from six months ago driving
    /// today's suggestion. It is not meant to punish a missed week: miss
    /// Thursday, train the following Monday, and on the Thursday after that
    /// the squat history is 22 days old and the engine would cold-start you
    /// back at the programme's opening load — a rollback of the whole block.
    ///
    /// So the window is measured from the last time you were under a bar at
    /// all. Stop training for a month and it expires as intended.
    DateTime? lastTrainedAt,
    int stallCount = 0,
    double blockLoadMultiplier = 1.0,
  }) {
    final p = prescription;
    final today = now ?? DateTime.now();

    // ---- Rule 0: everything that does not progress by kilograms ----------
    switch (p.progression.type) {
      case ProgressionType.none:
        return LoadSuggestion(
          repTargetMin: p.repsMin,
          repTargetMax: p.repsMax,
          reason: 'As prescribed.',
        );

      case ProgressionType.cardioTable:
        // The block resolver has already put this week's row from the
        // cardio table into repsMin/repsMax (resolver step 5).
        return LoadSuggestion(
          repTargetMin: p.repsMin,
          repTargetMax: p.repsMax,
          reason: 'This week on the cardio table: ${_runLength(p)}, easy.',
        );

      case ProgressionType.bandProgression:
        final last = _lastNote(history);
        return LoadSuggestion(
          repTargetMin: p.repsMin,
          repTargetMax: p.repsMax,
          reason: last == null
              ? 'Pick a band that leaves one rep in the tank. Log the colour.'
              : 'Last band: $last. Move to a thinner band once you hit '
                    '${p.repsMax} on every set.',
        );

      case ProgressionType.timeOnly:
        final fresh = _inWindow(history, p, today, lastTrainedAt);
        final lastTarget = _lastTargetMax(fresh) ?? p.repsMax;
        final hitIt =
            fresh.isNotEmpty && fresh.every((s) => s.achieved >= lastTarget);

        // A hold needs a ceiling. Five seconds a week compounds: a 30-second
        // plank in week 1 is a ten-minute plank by the end of the year, which
        // is a test of patience rather than of anything trainable. Past the
        // ceiling the progression belongs on the load or on a harder variant.
        //
        // Only when one is AUTHORED, though. For a timed hold `repsMax` is a
        // duration, so deriving a fallback from it is arithmetic on a number
        // that means something else. Gate V-hold checks every hold has one.
        final ceiling = p.repsCreepMax;
        final atCeiling = ceiling != null && lastTarget >= ceiling;
        final grown = lastTarget + p.progression.incrementSec;
        final next = hitIt
            ? (ceiling == null ? grown : (grown < ceiling ? grown : ceiling))
            : lastTarget;

        return LoadSuggestion(
          repTargetMin: next,
          repTargetMax: next,
          reason: atCeiling
              ? 'At the $ceiling-second ceiling — hold it there and make '
                    'the movement harder instead.'
              : hitIt
              ? 'Held it — add ${p.progression.incrementSec} seconds.'
              : 'Hold for $next seconds.',
        );

      case ProgressionType.repsOnly:
        final fresh = _inWindow(history, p, today, lastTrainedAt);
        final lastTarget = _lastTargetMax(fresh) ?? p.repsMax;
        final hitIt =
            fresh.isNotEmpty && fresh.every((s) => s.achieved >= lastTarget);
        final ceiling = p.repsCreepMax ?? (p.repsMax * 3);
        final next = hitIt
            ? (lastTarget + 1).clamp(p.repsMin, ceiling)
            : lastTarget;
        return LoadSuggestion(
          repTargetMin: p.repsMin,
          repTargetMax: next,
          reason: hitIt
              ? 'Clean last time — one more rep per set.'
              : 'Same target: work towards $next reps.',
        );

      case ProgressionType.doubleProgression:
        break; // falls through to the load rules below
    }

    // ---- Rule 1: cold start ----------------------------------------------
    // [prescription] is the RESOLVED one: the block resolver has already
    // multiplied its startLoadKg by the block's loadMultiplier (step 2b).
    // Scaling it again made a deload cold start 0.7 x 0.7 = 49%.
    final fresh = _inWindow(history, p, today, lastTrainedAt);
    if (fresh.isEmpty) {
      return _withPlates(
        p,
        p.startLoadKg,
        repMin: p.repsMin,
        repMax: p.repsMax,
        reason: history.isEmpty
            ? 'Programme start.'
            : 'No recent history — back to the programme start.',
        stallCount: stallCount,
        deloaded: blockLoadMultiplier != 1.0,
      );
    }

    // Rule 1b: history, but none of it loaded — the exercise fallback found
    // a bodyweight variant (Foundation's split squat, before Build loads
    // it). Reps without a load earn no jump from a load never lifted.
    final loggedLoad = _lastLoad(fresh);
    final start = p.startLoadKg;
    if (loggedLoad == null && start != null && start > 0) {
      return _withPlates(
        p,
        start,
        repMin: p.repsMin,
        repMax: p.repsMax,
        reason: 'First time with load — start at the programme load.',
        stallCount: stallCount,
        deloaded: blockLoadMultiplier != 1.0,
      );
    }

    final lastLoad = loggedLoad ?? start ?? 0;
    final targetMin = _lastTargetMin(fresh) ?? p.repsMin;
    final targetMax = _lastTargetMax(fresh) ?? p.repsMax;

    // ---- Rule 5: did anything fall short? --------------------------------
    final fellShort = fresh.any((s) => s.achieved < targetMin);
    if (fellShort) {
      if (stallCount + 1 < p.progression.stallLimit) {
        return _withPlates(
          p,
          _scale(lastLoad, blockLoadMultiplier),
          repMin: targetMin,
          repMax: targetMax,
          reason:
              'Repeat — stall ${stallCount + 1} of '
              '${p.progression.stallLimit}.',
          isStalled: true,
          stallCount: stallCount + 1,
          deloaded: blockLoadMultiplier != 1.0,
        );
      }
      final backedOff = lastLoad * (1 - p.progression.deloadPct);
      return _withPlates(
        p,
        _scale(backedOff, blockLoadMultiplier),
        repMin: p.repsMin,
        repMax: p.repsMax,
        reason:
            'Back off ${(p.progression.deloadPct * 100).round()}% and build '
            'up again. You will come back through this stronger.',
        isStalled: true,
        stallCount: 0,
        deloaded: blockLoadMultiplier != 1.0,
      );
    }

    // ---- Rules 3 and 4: was the jump earned? ------------------------------
    // A deload's RIR target is softer on purpose (its block default is 4),
    // and last week's sets were logged against a harder one. The deload must
    // not re-judge them: the week earned what it earned, and the deload
    // takes 70% of that.
    final isDeload = blockLoadMultiplier < 1.0;
    final allAtTop = fresh.every((s) => s.achieved >= targetMax);
    final rirMet =
        isDeload ||
        p.targetRir == null ||
        fresh.every((s) => s.rir == null || s.rir! >= p.targetRir!);

    if (!(allAtTop && rirMet)) {
      return _withPlates(
        p,
        _scale(lastLoad, blockLoadMultiplier),
        repMin: targetMin,
        repMax: targetMax,
        reason: allAtTop
            ? 'Top of the range, but it was a grind — same weight, '
                  'clean it up.'
            : 'Add reps at this weight.',
        stallCount: 0,
        deloaded: blockLoadMultiplier != 1.0,
      );
    }

    // The jump IS earned. Can the plates deliver it?
    final step = solver.smallestStepAt(lastLoad, p.loadMode);
    final maxJump = lastLoad * p.progression.maxJumpPct;
    final canCreep = p.repsCreepMax != null && targetMax < p.repsCreepMax!;

    // Rule 3b: one step is too big a jump, so the load stays put.
    //
    // In a deload the load-holding half still applies — a jump the plates
    // cannot make was never earned in kilograms, so the deload comes off what
    // was actually lifted. The rep-creep half does NOT: the whole point of
    // the week is less stress, and "70% of the load but two more reps per
    // set" is more work, not less.
    if (step != null && step > maxJump && canCreep) {
      final crept = isDeload
          ? targetMax
          : (targetMax + repCreepStep).clamp(p.repsMin, p.repsCreepMax!);
      return _withPlates(
        p,
        _scale(lastLoad, blockLoadMultiplier),
        repMin: targetMin,
        repMax: crept,
        reason: isDeload
            ? 'Deload: ${(blockLoadMultiplier * 100).round()}% of the '
                  '${_fmt(solver.solve(lastLoad, p.loadMode).achievableKg)} kg '
                  'you earned.'
            : 'Earned it, but the smallest jump here is '
                  '${_fmt(step)} kg — ${(step / lastLoad * 100).round()}% of '
                  'the load. Plates are too coarse: add reps instead.',
        isRepCreep: !isDeload,
        stallCount: 0,
        deloaded: blockLoadMultiplier != 1.0 && !isDeload,
      );
    }

    // Rule 3a: take the jump, capped so it can never be smaller than one
    // loadable step. Clamping below a step is what produced the deadlock.
    final desired = p.progression.incrementKg > 0
        ? p.progression.incrementKg
        : (step ?? 0);
    final cap = step == null ? maxJump : (maxJump > step ? maxJump : step);

    // A jump smaller than the smallest loadable step snaps straight back to
    // where it started, and the athlete is told "earned the jump" while the
    // bar never changes. Wanting 1 kg on a kit whose finest step is 2.5 kg
    // means taking 2.5 or taking nothing, and nothing is the deadlock.
    final atLeastOneStep = (step != null && desired < step) ? step : desired;
    final jump = atLeastOneStep < cap ? atLeastOneStep : cap;

    var suggested = _scale(lastLoad + jump, blockLoadMultiplier);
    var reason = 'Earned the jump.';
    var repMin = p.repsMin;
    var repMax = p.repsMax;
    var creeping = false;

    var earned = lastLoad + jump;
    if (step != null && step > maxJump && !canCreep) {
      reason = 'Rep ceiling reached — taking the big jump.';
      earned = lastLoad + step;
      suggested = _scale(earned, blockLoadMultiplier);
    }
    if (isDeload) {
      // Nothing is being jumped this week: say what the number is.
      reason =
          'Deload: ${(blockLoadMultiplier * 100).round()}% of the '
          '${_fmt(solver.solve(earned, p.loadMode).achievableKg)} kg '
          'you earned.';
    }

    // ---- Rule 8: the final guard -----------------------------------------
    // Snap first, then check that SOMETHING actually moved.
    final held = _scaleNonNull(lastLoad, blockLoadMultiplier);
    final snapped = solver.solve(suggested ?? held, p.loadMode);
    final sameLoad =
        (snapped.achievableKg - solver.solve(held, p.loadMode).achievableKg)
            .abs() <
        1e-6;
    // Same exemption as rule 3b: a deload is allowed to produce "nothing
    // moved", because the load coming down IS the change.
    if (!isDeload &&
        sameLoad &&
        p.repsCreepMax != null &&
        targetMax < p.repsCreepMax!) {
      repMin = targetMin;
      repMax = (targetMax + repCreepStep).clamp(p.repsMin, p.repsCreepMax!);
      creeping = true;
      reason =
          'Earned it, but that jump is not loadable with these plates '
          '— add reps instead.';
      suggested = _scale(lastLoad, blockLoadMultiplier);
    }

    return _withPlates(
      p,
      suggested,
      repMin: repMin,
      repMax: repMax,
      reason: reason,
      isRepCreep: creeping,
      stallCount: 0,
      // The deload reason above already says so.
      deloaded: blockLoadMultiplier != 1.0 && (!isDeload || creeping),
    );
  }

  // ---------------------------------------------------------------- helpers

  /// Sets close enough together in time to be one session.
  ///
  /// `LoggedSet` carries no session id — the engine is deliberately ignorant
  /// of the database — so sessions are inferred from the gaps. Six hours is
  /// far longer than any session in a sixty-minute programme and far shorter
  /// than the gap to the next one.
  static const _sessionGap = Duration(hours: 6);

  /// Midnight on the calendar day [d] falls in.
  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// [n] days before [d], by the calendar.
  ///
  /// `subtract(Duration(days:))` is wrong across a DST boundary, and Germany
  /// crosses one in the middle of the programme.
  static DateTime _daysBefore(DateTime d, int n) =>
      DateTime(d.year, d.month, d.day - n);

  List<LoggedSet> _inWindow(
    List<LoggedSet> history,
    Prescription p,
    DateTime now,
    DateTime? lastTrainedAt,
  ) {
    if (history.isEmpty) return const [];
    final days = p.progression.historyWindowDays;

    // Measured back from the last session of ANY kind, so a missed week does
    // not throw away the block. Never forward of now, and never further back
    // than one extra window — a month off is still a reason to start again.
    var anchor = now;
    if (lastTrainedAt != null && lastTrainedAt.isBefore(now)) {
      final floor = _daysBefore(now, days);
      anchor = lastTrainedAt.isAfter(floor) ? lastTrainedAt : floor;
    }

    // By the CALENDAR, not the clock. Week 6's Monday at 18:40 and week 9's
    // Monday opened at 19:00 are twenty-one days apart on any calendar, and
    // twenty-one days and twenty minutes by the hour. Judged by the hour,
    // that session dropped out of a 21-day window and the block rolled back
    // to its opening loads.
    final cutoff = _daysBefore(_dateOnly(anchor), days);

    final sorted = [...history]
      ..sort((a, b) => a.completedAt.compareTo(b.completedAt));

    // A session is in or out as a unit. One that ran past midnight must not
    // be judged on the half of it that landed after the cutoff: two sets at
    // the top of the range would earn a jump the whole session did not.
    final out = <LoggedSet>[];
    var run = <LoggedSet>[sorted.first];
    void flush() {
      if (run.any((s) => !_dateOnly(s.completedAt).isBefore(cutoff))) {
        out.addAll(run);
      }
    }

    for (final s in sorted.skip(1)) {
      if (s.completedAt.difference(run.last.completedAt) <= _sessionGap) {
        run.add(s);
      } else {
        flush();
        run = [s];
      }
    }
    flush();
    return out;
  }

  double? _lastLoad(List<LoggedSet> sets) {
    for (final s in sets.reversed) {
      if (s.loadKg != null && s.loadKg! > 0) return s.loadKg;
    }
    return null;
  }

  int? _lastTargetMin(List<LoggedSet> sets) {
    for (final s in sets.reversed) {
      if (s.targetRepsMin != null) return s.targetRepsMin;
    }
    return null;
  }

  int? _lastTargetMax(List<LoggedSet> sets) {
    for (final s in sets.reversed) {
      if (s.targetRepsMax != null) return s.targetRepsMax;
    }
    return null;
  }

  String? _lastNote(List<LoggedSet> sets) {
    for (final s in sets.reversed) {
      if (s.note != null && s.note!.trim().isNotEmpty) return s.note!.trim();
    }
    return null;
  }

  double? _scale(double? kg, double multiplier) =>
      kg == null ? null : kg * multiplier;

  /// Same, for a load already known to exist.
  double _scaleNonNull(double kg, double multiplier) => kg * multiplier;

  LoadSuggestion _withPlates(
    Prescription p,
    double? kg, {
    required int repMin,
    required int repMax,
    required String reason,
    required int stallCount,
    bool isStalled = false,
    bool isRepCreep = false,
    bool deloaded = false,
  }) {
    if (kg == null) {
      return LoadSuggestion(
        repTargetMin: repMin,
        repTargetMax: repMax,
        reason: reason,
        isStalled: isStalled,
        isRepCreep: isRepCreep,
        newStallCount: stallCount,
      );
    }

    // Rule 6 and 7: the multiplier is already in, now snap DOWN. Never up —
    // suggesting more than was earned is how people get hurt training alone.
    final solution = solver.solve(kg, p.loadMode);

    return LoadSuggestion(
      suggestedKg: solution.achievableKg,
      repTargetMin: repMin,
      repTargetMax: repMax,
      reason: deloaded ? '$reason (deload week)' : reason,
      plates: solution,
      isStalled: isStalled,
      isRepCreep: isRepCreep,
      newStallCount: stallCount,
      smallestStepKg: solution.smallestStepKg,
      warning: solution.warning,
    );
  }

  static String _fmt(double v) => v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');

  /// "35 min", "24–26 min", "5000 m".
  static String _runLength(Prescription p) {
    String range(int a, int b) => a == b ? '$a' : '$a–$b';
    return switch (p.unit) {
      RepUnit.sec =>
        '${range((p.repsMin / 60).round(), (p.repsMax / 60).round())} min',
      RepUnit.m => '${range(p.repsMin, p.repsMax)} m',
      RepUnit.reps => range(p.repsMin, p.repsMax),
    };
  }
}
