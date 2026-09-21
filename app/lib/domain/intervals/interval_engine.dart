import 'dart:async';

/// Which part of an interval we are in.
enum IntervalPhase { prepare, work, rest, done }

/// A repeating work/rest structure: a rest timer between sets, skipping
/// intervals, bag rounds. One tested source for all three.
class IntervalSpec {
  const IntervalSpec({
    required this.rounds,
    required this.workSec,
    this.restSec = 0,
    this.prepareSec = 0,
    this.label,
  }) : countdownOnly = false,
       assert(rounds > 0),
       assert(workSec >= 0),
       assert(restSec >= 0),
       assert(prepareSec >= 0);

  /// A single countdown: the rest timer between sets.
  ///
  /// Modelled as one round of "work" so it carries a duration at all — the
  /// last round of any interval has no trailing rest, so putting the seconds
  /// in `restSec` with `rounds: 1` would total zero. [countdownOnly] makes it
  /// report as a rest phase, which is what it is to the athlete.
  const IntervalSpec.rest(int seconds, {this.label})
    : rounds = 1,
      workSec = seconds,
      restSec = 0,
      prepareSec = 0,
      countdownOnly = true;

  final int rounds;
  final int workSec;
  final int restSec;

  /// A lead-in before the first work period, so you can get to the bar.
  final int prepareSec;

  final String? label;

  /// True for a plain rest countdown: one phase, reported as [IntervalPhase.rest].
  final bool countdownOnly;

  /// The last round has no trailing rest — the session moves on instead.
  int get totalSec => prepareSec + rounds * workSec + (rounds - 1) * restSec;

  Duration get total => Duration(seconds: totalSec);
}

/// A moment inside a running interval.
class IntervalTick {
  const IntervalTick({
    required this.round,
    required this.phase,
    required this.secondsLeft,
    required this.elapsedSec,
    required this.totalSec,
  });

  /// 1-based. Equals `spec.rounds` once done.
  final int round;
  final IntervalPhase phase;

  /// Seconds remaining in the current phase. Zero when done.
  final int secondsLeft;

  final int elapsedSec;
  final int totalSec;

  bool get isDone => phase == IntervalPhase.done;

  double get progress =>
      totalSec == 0 ? 1 : (elapsedSec / totalSec).clamp(0, 1);

  String get clock {
    final m = secondsLeft ~/ 60;
    final s = secondsLeft % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  bool operator ==(Object other) =>
      other is IntervalTick &&
      other.round == round &&
      other.phase == phase &&
      other.secondsLeft == secondsLeft &&
      other.elapsedSec == elapsedSec;

  @override
  int get hashCode => Object.hash(round, phase, secondsLeft, elapsedSec);

  @override
  String toString() =>
      'IntervalTick(round $round, ${phase.name}, ${secondsLeft}s left)';
}

/// Resolves an interval position from elapsed wall-clock time.
///
/// **Pure, and wall-clock based on purpose.** A tick counter drifts, and stops
/// entirely when Android suspends the isolate — you would come back from a
/// locked screen to a timer that had paused mid-rest. Everything here is a
/// function of "how long since the start instant", so a suspended app catches
/// straight back up, and the notification is what actually fires.
class IntervalEngine {
  const IntervalEngine(this.spec);

  final IntervalSpec spec;

  /// The tick at [elapsed] seconds after the start.
  IntervalTick at(int elapsedSec) {
    final e = elapsedSec < 0 ? 0 : elapsedSec;

    if (e >= spec.totalSec) {
      return IntervalTick(
        round: spec.rounds,
        phase: IntervalPhase.done,
        secondsLeft: 0,
        elapsedSec: spec.totalSec,
        totalSec: spec.totalSec,
      );
    }

    var cursor = e;

    if (cursor < spec.prepareSec) {
      return IntervalTick(
        round: 1,
        phase: IntervalPhase.prepare,
        secondsLeft: spec.prepareSec - cursor,
        elapsedSec: e,
        totalSec: spec.totalSec,
      );
    }
    cursor -= spec.prepareSec;

    final cycle = spec.workSec + spec.restSec;
    for (var round = 1; round <= spec.rounds; round++) {
      final isLast = round == spec.rounds;

      if (cursor < spec.workSec) {
        return IntervalTick(
          round: round,
          phase: spec.countdownOnly ? IntervalPhase.rest : IntervalPhase.work,
          secondsLeft: spec.workSec - cursor,
          elapsedSec: e,
          totalSec: spec.totalSec,
        );
      }
      cursor -= spec.workSec;

      if (isLast) break; // no trailing rest

      if (cursor < spec.restSec) {
        return IntervalTick(
          round: round,
          phase: IntervalPhase.rest,
          secondsLeft: spec.restSec - cursor,
          elapsedSec: e,
          totalSec: spec.totalSec,
        );
      }
      cursor -= spec.restSec;

      // Guard against a zero-length cycle spinning forever.
      if (cycle == 0) break;
    }

    return IntervalTick(
      round: spec.rounds,
      phase: IntervalPhase.done,
      secondsLeft: 0,
      elapsedSec: spec.totalSec,
      totalSec: spec.totalSec,
    );
  }

  /// The tick for a run that began at [startedAt], as of [now].
  IntervalTick atTime(DateTime startedAt, DateTime now) =>
      at(now.difference(startedAt).inSeconds);

  /// When the whole interval finishes, for scheduling the notification.
  DateTime endsAt(DateTime startedAt) =>
      startedAt.add(Duration(seconds: spec.totalSec));

  /// Every instant at which a phase changes, for scheduling the round cues.
  List<({DateTime at, IntervalPhase phase, int round})> transitions(
    DateTime startedAt,
  ) {
    final out = <({DateTime at, IntervalPhase phase, int round})>[];
    var t = 0;
    if (spec.prepareSec > 0) t += spec.prepareSec;
    for (var round = 1; round <= spec.rounds; round++) {
      out.add((
        at: startedAt.add(Duration(seconds: t)),
        phase: spec.countdownOnly ? IntervalPhase.rest : IntervalPhase.work,
        round: round,
      ));
      t += spec.workSec;
      if (round < spec.rounds && spec.restSec > 0) {
        out.add((
          at: startedAt.add(Duration(seconds: t)),
          phase: IntervalPhase.rest,
          round: round,
        ));
        t += spec.restSec;
      }
    }
    out.add((
      at: startedAt.add(Duration(seconds: t)),
      phase: IntervalPhase.done,
      round: spec.rounds,
    ));
    return out;
  }
}

/// Drives an [IntervalEngine] from a clock.
///
/// The ticker is cosmetic — it only repaints the countdown. The scheduled
/// notification is what actually survives the screen going off, so losing
/// ticks while suspended costs nothing: the next tick recomputes from the
/// start instant and lands on the right value.
class IntervalRunner {
  IntervalRunner(
    IntervalSpec spec, {
    DateTime Function()? clock,
    this.resolution = const Duration(milliseconds: 250),
  }) : engine = IntervalEngine(spec),
       _clock = clock ?? DateTime.now;

  final IntervalEngine engine;
  final DateTime Function() _clock;

  /// How often the cosmetic countdown repaints. Nothing depends on it for
  /// correctness — the tick is always recomputed from the start instant.
  final Duration resolution;

  final _controller = StreamController<IntervalTick>.broadcast();
  Timer? _timer;
  DateTime? _startedAt;

  /// Accumulated seconds added or removed by the +/-15 s buttons.
  int _adjustmentSec = 0;

  Stream<IntervalTick> get ticks => _controller.stream;

  bool get isRunning => _timer != null;
  DateTime? get startedAt => _startedAt;

  IntervalTick get current {
    final started = _startedAt;
    if (started == null) return engine.at(0);
    return engine.at(_clock().difference(started).inSeconds - _adjustmentSec);
  }

  /// When the interval will finish, accounting for adjustments. Used to
  /// schedule the notification.
  DateTime? get endsAt =>
      _startedAt?.add(Duration(seconds: engine.spec.totalSec + _adjustmentSec));

  void start({DateTime? from}) {
    _startedAt = from ?? _clock();
    _adjustmentSec = 0;
    _timer?.cancel();
    _timer = Timer.periodic(resolution, (_) => _emit());
    _emit();
  }

  /// Resumes a timer that was running when the app was killed.
  void resume(DateTime startedAt, {int adjustmentSec = 0}) {
    _startedAt = startedAt;
    _adjustmentSec = adjustmentSec;
    _timer?.cancel();
    _timer = Timer.periodic(resolution, (_) => _emit());
    _emit();
  }

  /// Shifts the finish line. Negative shortens.
  ///
  /// Implemented as an offset rather than by moving the start instant, so the
  /// elapsed-time reading stays honest.
  void adjust(int seconds) {
    if (_startedAt == null) return;
    _adjustmentSec += seconds;
    _emit();
  }

  void skip() {
    if (_startedAt == null) return;
    _adjustmentSec = -engine.spec.totalSec;
    _emit();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _emit() {
    if (_controller.isClosed) return;
    final tick = current;
    _controller.add(tick);
    if (tick.isDone) stop();
  }

  void dispose() {
    stop();
    _controller.close();
  }
}
