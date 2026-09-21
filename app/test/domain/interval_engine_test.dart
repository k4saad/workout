import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/domain/intervals/interval_engine.dart';

void main() {
  group('rest timer — a single countdown', () {
    const spec = IntervalSpec.rest(150, label: 'Back squat');
    const engine = IntervalEngine(spec);

    test('total is just the rest', () {
      expect(spec.totalSec, 150);
    });

    test('counts down and then reports done', () {
      expect(engine.at(0).phase, IntervalPhase.rest);
      expect(engine.at(0).secondsLeft, 150);
      expect(engine.at(1).secondsLeft, 149);
      expect(engine.at(149).secondsLeft, 1);
      expect(engine.at(150).phase, IntervalPhase.done);
      expect(engine.at(150).secondsLeft, 0);
    });

    test('stays done past the end rather than going negative', () {
      // This is the case that matters after the screen has been off: you come
      // back four minutes later and the timer must read "done", not "-90".
      expect(engine.at(9999).phase, IntervalPhase.done);
      expect(engine.at(9999).secondsLeft, 0);
    });

    test('negative elapsed clamps to the start', () {
      expect(engine.at(-5).secondsLeft, 150);
    });

    test('formats a readable clock', () {
      expect(engine.at(0).clock, '2:30');
      expect(engine.at(90).clock, '1:00');
      expect(engine.at(145).clock, '0:05');
    });
  });

  group('skipping intervals — 8 x 30 s on / 30 s off', () {
    const spec = IntervalSpec(rounds: 8, workSec: 30, restSec: 30);
    const engine = IntervalEngine(spec);

    test('the last round has no trailing rest', () {
      // 8 work + 7 rest, not 8 and 8. Otherwise the session ends with you
      // standing around for half a minute.
      expect(spec.totalSec, 8 * 30 + 7 * 30);
      expect(spec.totalSec, 450);
    });

    test('walks work and rest in the right order', () {
      expect(engine.at(0).phase, IntervalPhase.work);
      expect(engine.at(0).round, 1);
      expect(engine.at(29).phase, IntervalPhase.work);
      expect(engine.at(30).phase, IntervalPhase.rest);
      expect(engine.at(30).round, 1);
      expect(engine.at(59).phase, IntervalPhase.rest);
      expect(engine.at(60).phase, IntervalPhase.work);
      expect(engine.at(60).round, 2);
    });

    test('lands on the final round correctly', () {
      // Round 8 work starts at 7 * 60 = 420.
      expect(engine.at(420).round, 8);
      expect(engine.at(420).phase, IntervalPhase.work);
      expect(engine.at(449).phase, IntervalPhase.work);
      expect(engine.at(450).phase, IntervalPhase.done);
    });

    test('every second resolves to exactly one phase', () {
      for (var t = 0; t < spec.totalSec; t++) {
        final tick = engine.at(t);
        expect(tick.phase, isNot(IntervalPhase.done), reason: 't=$t');
        expect(tick.secondsLeft, greaterThan(0), reason: 't=$t');
        expect(tick.round, inInclusiveRange(1, spec.rounds), reason: 't=$t');
      }
    });
  });

  group('bag rounds with a lead-in', () {
    const spec = IntervalSpec(
      rounds: 3,
      workSec: 120,
      restSec: 60,
      prepareSec: 10,
    );
    const engine = IntervalEngine(spec);

    test('prepare runs first', () {
      expect(engine.at(0).phase, IntervalPhase.prepare);
      expect(engine.at(0).secondsLeft, 10);
      expect(engine.at(9).phase, IntervalPhase.prepare);
      expect(engine.at(10).phase, IntervalPhase.work);
      expect(engine.at(10).round, 1);
    });

    test('total accounts for the lead-in', () {
      expect(spec.totalSec, 10 + 3 * 120 + 2 * 60);
    });

    test('finishes after the third work period', () {
      expect(engine.at(10 + 360 + 120 - 1).phase, IntervalPhase.work);
      expect(engine.at(10 + 360 + 120).phase, IntervalPhase.done);
    });
  });

  group('wall-clock resolution', () {
    test('atTime derives the tick from two instants', () {
      const engine = IntervalEngine(IntervalSpec.rest(150));
      final start = DateTime(2026, 11, 2, 18, 30);
      expect(engine.atTime(start, start).secondsLeft, 150);
      expect(
        engine
            .atTime(start, start.add(const Duration(seconds: 90)))
            .secondsLeft,
        60,
      );
    });

    test('a suspended app catches straight up instead of pausing', () {
      // The app is killed at t=10 and reopened at t=200. A tick counter would
      // read 10 s elapsed; wall-clock reads done.
      const engine = IntervalEngine(IntervalSpec.rest(150));
      final start = DateTime(2026, 11, 2, 18, 30);
      final reopened = start.add(const Duration(seconds: 200));
      expect(engine.atTime(start, reopened).phase, IntervalPhase.done);
    });

    test('endsAt is when the notification should fire', () {
      const engine = IntervalEngine(IntervalSpec.rest(150));
      final start = DateTime(2026, 11, 2, 18, 30);
      expect(engine.endsAt(start), DateTime(2026, 11, 2, 18, 32, 30));
    });
  });

  group('transitions — what gets scheduled as cues', () {
    test('one cue per phase change plus a finish', () {
      const spec = IntervalSpec(rounds: 3, workSec: 120, restSec: 60);
      const engine = IntervalEngine(spec);
      final start = DateTime(2026, 11, 2, 18, 0);
      final t = engine.transitions(start);

      // 3 work starts + 2 rest starts + 1 done.
      expect(t, hasLength(6));
      expect(t.first.phase, IntervalPhase.work);
      expect(t.first.at, start);
      expect(t.last.phase, IntervalPhase.done);
      expect(t.last.at, start.add(Duration(seconds: spec.totalSec)));
    });

    test('transitions are strictly increasing', () {
      const engine = IntervalEngine(
        IntervalSpec(rounds: 8, workSec: 30, restSec: 30),
      );
      final t = engine.transitions(DateTime(2026, 11, 2, 18));
      for (var i = 1; i < t.length; i++) {
        expect(t[i].at.isAfter(t[i - 1].at), isTrue, reason: 'at index $i');
      }
    });
  });

  group('IntervalRunner', () {
    late DateTime now;
    DateTime clock() => now;

    setUp(() => now = DateTime(2026, 11, 2, 18, 30));

    test('current reflects the clock, not a tick count', () {
      final r = IntervalRunner(const IntervalSpec.rest(150), clock: clock);
      r.start();
      expect(r.current.secondsLeft, 150);

      now = now.add(const Duration(seconds: 100));
      expect(r.current.secondsLeft, 50);

      now = now.add(const Duration(seconds: 100));
      expect(r.current.phase, IntervalPhase.done);
      r.dispose();
    });

    test('+15 s pushes the finish line out', () {
      final r = IntervalRunner(const IntervalSpec.rest(150), clock: clock);
      r.start();
      now = now.add(const Duration(seconds: 100));
      expect(r.current.secondsLeft, 50);

      r.adjust(15);
      expect(r.current.secondsLeft, 65);
      expect(r.endsAt, DateTime(2026, 11, 2, 18, 32, 45));
      r.dispose();
    });

    test('-15 s pulls it in, and cannot go past done', () {
      final r = IntervalRunner(const IntervalSpec.rest(60), clock: clock);
      r.start();
      now = now.add(const Duration(seconds: 50));
      r.adjust(-15);
      expect(r.current.phase, IntervalPhase.done);
      r.dispose();
    });

    test('skip ends it immediately', () {
      final r = IntervalRunner(const IntervalSpec.rest(150), clock: clock);
      r.start();
      r.skip();
      expect(r.current.phase, IntervalPhase.done);
      r.dispose();
    });

    test('resume picks up a timer the app was killed during', () {
      final started = DateTime(2026, 11, 2, 18, 29, 0);
      now = DateTime(2026, 11, 2, 18, 30, 30); // 90 s later
      final r = IntervalRunner(const IntervalSpec.rest(150), clock: clock);
      r.resume(started);
      expect(r.current.secondsLeft, 60);
      expect(r.startedAt, started);
      r.dispose();
    });

    test('emits ticks and closes cleanly', () async {
      final r = IntervalRunner(
        const IntervalSpec.rest(2),
        clock: clock,
        resolution: const Duration(milliseconds: 10),
      );
      final seen = <IntervalTick>[];
      final sub = r.ticks.listen(seen.add);
      r.start();
      now = now.add(const Duration(seconds: 1));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      now = now.add(const Duration(seconds: 2));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(seen, isNotEmpty);
      expect(seen.last.phase, IntervalPhase.done);
      expect(r.isRunning, isFalse, reason: 'should stop itself when done');
      await sub.cancel();
      r.dispose();
    });
  });
}
