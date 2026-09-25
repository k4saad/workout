import 'dart:async';
import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:keller_twelve/data/db/database.dart';
import 'package:keller_twelve/data/db/tables.dart';
import 'package:keller_twelve/data/run_repository.dart';
import 'package:keller_twelve/data/run_tracker.dart';
import 'package:keller_twelve/domain/run/run.dart';

/// A run's life in the database, and the tracker that drives it.
///
/// The rules are the session runner's: persist every point the moment it
/// arrives, because a phone in a pocket can be killed at any second, and a
/// run that only lived in memory is a run that never happened.
void main() {
  late AppDatabase db;
  late DateTime now;
  late RunRepository repo;

  const origin = GeoPoint(51.9634, 7.6130);
  GeoPoint north(double m) => GeoPoint(origin.lat + m / 111195.0, origin.lng);
  RunFix fix(int s, double metres, {double accuracy = 5}) => RunFix(
    tMs: DateTime(2026, 10, 4, 18, 30).millisecondsSinceEpoch + s * 1000,
    lat: north(metres).lat,
    lng: north(metres).lng,
    accuracyM: accuracy,
  );

  setUp(() {
    db = AppDatabase.memory();
    now = DateTime(2026, 10, 4, 18, 30);
    repo = RunRepository(db, clock: () => now);
  });

  tearDown(() => db.close());

  Future<int> session() => db
      .into(db.sessions)
      .insert(
        SessionsCompanion.insert(
          programmeId: 'keller-twelve',
          blockId: 'foundation',
          dayId: 'f-sun',
          weekNo: 1,
          plannedDate: DateTime(2026, 10, 4),
          scheduledDate: DateTime(2026, 10, 4),
          status: const Value(SessionStatus.inProgress),
        ),
      );

  group('the repository', () {
    test('a started run is recording, dated to local midnight', () async {
      final id = await repo.start();
      final run = (await repo.byId(id))!;
      expect(run.status, RunStatus.recording);
      expect(run.runOn, DateTime(2026, 10, 4));
      expect(run.startedAtMs, now.millisecondsSinceEpoch);
      expect((await repo.active())!.id, id);
    });

    test('points are kept in order, with the segment breaks', () async {
      final id = await repo.start();
      await repo.addPoint(id, fix(0, 0), segmentStart: true);
      await repo.addPoint(id, fix(1, 3));
      await repo.addPoint(id, fix(60, 200), segmentStart: true);
      final pts = await repo.points(id);
      expect([for (final p in pts) p.seq], [0, 1, 2]);
      expect([for (final p in pts) p.segmentStart], [true, false, true]);
    });

    test('a run rebuilds from its points into the same numbers', () async {
      final id = await repo.start();
      final live = RunTrack();
      for (var s = 0; s <= 120; s++) {
        final f = fix(s, s * 3.0);
        live.add(f, segmentStart: s == 0);
        await repo.addPoint(id, f, segmentStart: s == 0);
      }
      final rebuilt = await repo.track(id);
      expect(rebuilt.distanceM, closeTo(live.distanceM, 1e-6));
      expect(rebuilt.movingMs, live.movingMs);
    });

    test('finishing writes the totals and closes the run', () async {
      final id = await repo.start();
      final t = RunTrack();
      for (var s = 0; s <= 300; s++) {
        final f = fix(s, s * 3.0);
        t.add(f, segmentStart: s == 0);
        await repo.addPoint(id, f, segmentStart: s == 0);
      }
      now = now.add(const Duration(minutes: 5));
      final run = await repo.finish(id, t, effort: 4);
      expect(run.status, RunStatus.finished);
      expect(run.distanceM, closeTo(900, 5));
      expect(run.movingMs, closeTo(300000, 5000));
      expect(run.effort, 4);
      expect(run.endedAtMs, now.millisecondsSinceEpoch);
      expect(run.startLat, closeTo(origin.lat, 1e-9));
      expect(run.endLat, greaterThan(origin.lat));
      expect(await repo.active(), isNull);
    });

    test('a programme run logs its time and distance as the set', () async {
      final sid = await session();
      final link = RunLink(
        sessionId: sid,
        weekNo: 1,
        dayId: 'f-sun',
        prescriptionId: 'f-sun-1',
        exerciseId: 'easy-run',
        target: const RunTarget.duration(900),
        targetRepsMin: 900,
        targetRepsMax: 1080,
      );
      final id = await repo.start(link: link);
      final t = RunTrack();
      for (var s = 0; s <= 600; s++) {
        final f = fix(s, s * 2.8);
        t.add(f, segmentStart: s == 0);
        await repo.addPoint(id, f, segmentStart: s == 0);
      }
      final run = await repo.finish(id, t, link: link);

      final sets = await db.setsForSession(sid);
      expect(sets, hasLength(1));
      final set = sets.single;
      expect(set.prescriptionId, 'f-sun-1');
      expect(set.exerciseId, 'easy-run');
      // Seconds in the seconds column, metres in the metres column: never
      // "600 reps".
      expect(set.durationSec, closeTo(600, 10));
      expect(set.distanceM, closeTo(1680, 10));
      expect(set.reps, isNull);
      expect(set.setIndex, 1);
      expect(set.targetRepsMax, 1080);
      expect(run.setLogId, set.id);
      expect(run.sessionId, sid);
    });

    test(
      'an open run with no trail is tidied; one with a trail is kept',
      () async {
        final empty = await repo.start();
        final real = await repo.start();
        await repo.addPoint(real, fix(0, 0), segmentStart: true);
        expect(await repo.tidyEmptyRuns(), 1);
        expect(await repo.byId(empty), isNull);
        expect((await repo.active())?.id, real);
      },
    );

    test('discarding removes the run and every point', () async {
      final id = await repo.start();
      await repo.addPoint(id, fix(0, 0), segmentStart: true);
      await repo.discard(id);
      expect(await repo.byId(id), isNull);
      expect(await db.select(db.runPoints).get(), isEmpty);
    });

    test('finished runs are found by day, newest first', () async {
      final a = await repo.start();
      await repo.finish(a, RunTrack());
      now = DateTime(2026, 10, 6, 7);
      final b = await repo.start();
      await repo.finish(b, RunTrack());
      final inRange = await repo.finishedBetween(
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 7),
      );
      expect([for (final r in inRange) r.id], [b, a]);
      final day = await repo.finishedBetween(
        DateTime(2026, 10, 6),
        DateTime(2026, 10, 6),
      );
      expect([for (final r in day) r.id], [b]);
    });

    test('the pace band comes from past runs of the same kind', () async {
      Future<void> past(String? exerciseId, double metres, int seconds) async {
        final id = await repo.start(
          link: exerciseId == null
              ? null
              : RunLink(exerciseId: exerciseId, prescriptionId: 'p'),
        );
        await (db.update(db.runs)..where((r) => r.id.equals(id))).write(
          RunsCompanion(
            distanceM: Value(metres),
            movingMs: Value(seconds * 1000),
            status: const Value(RunStatus.finished),
          ),
        );
        now = now.add(const Duration(days: 1));
      }

      await past('easy-run', 2000, 800);
      await past('easy-run', 2000, 760);
      await past('five-k-time-trial', 5000, 1500);
      await past(null, 3000, 900);
      final paces = await repo.recentPaces('easy-run');
      expect(paces, [380, 400]);
      expect(await repo.recentPaces(null), [300]);
    });
  });

  group('the tracker', () {
    late _FakeLocation gps;
    late int clockMs;
    late RunTracker tracker;

    setUp(() {
      gps = _FakeLocation();
      clockMs = fix(0, 0).tMs;
      tracker = RunTracker(repo: repo, source: gps, nowMs: () => clockMs);
    });

    tearDown(() => tracker.dispose());

    Future<void> send(RunFix f) async {
      gps.controller.add(f);
      await tracker.settled();
    }

    test('a fair fix is enough to be ready; a vague one is not', () async {
      await tracker.prepare();
      expect(tracker.snapshot.status, TrackerStatus.locating);
      await send(fix(0, 0, accuracy: 80));
      expect(tracker.snapshot.status, TrackerStatus.locating);
      await send(fix(1, 0, accuracy: 28));
      expect(
        tracker.snapshot.status,
        TrackerStatus.ready,
        reason: '±28 m is a normal first fix on a phone',
      );
      expect(tracker.snapshot.accuracyM, 28);
    });

    test('approximate location is named, not left to spin', () async {
      gps.access = LocationAccess.approximate;
      await tracker.prepare();
      expect(tracker.snapshot.status, TrackerStatus.approximate);
    });

    test(
      'Start works before any usable fix; the trail waits for one',
      () async {
        await tracker.prepare();
        await send(fix(0, 0, accuracy: 90));
        clockMs = fix(0, 0).tMs;
        await tracker.start();
        expect(tracker.snapshot.status, TrackerStatus.recording);
        await send(fix(1, 0, accuracy: 90));
        final id = tracker.snapshot.runId!;
        expect(await repo.points(id), isEmpty, reason: 'too vague to draw');
        clockMs = fix(20, 0).tMs;
        await send(fix(20, 0, accuracy: 18));
        expect(await repo.points(id), hasLength(1));
        expect(tracker.snapshot.elapsedMs, 20000, reason: 'the clock ran');
      },
    );

    test(
      'a vague but usable fix still draws; a hopeless one does not',
      () async {
        await tracker.prepare();
        await tracker.start();
        final id = tracker.snapshot.runId!;
        for (var s = 0; s < 10; s++) {
          clockMs = fix(s, 0).tMs;
          await send(fix(s, s * 3.0, accuracy: 35));
        }
        await send(fix(10, 30, accuracy: 60));
        expect(await repo.points(id), hasLength(10));
      },
    );

    test('the notification runs only while recording', () async {
      await tracker.prepare();
      expect(gps.recordingListeners, 0, reason: 'looking is not recording');
      expect(gps.plainListeners, 1);
      await tracker.start();
      expect(gps.recordingListeners, 1);
      expect(gps.plainListeners, 0);
      await send(fix(0, 0));
      await tracker.finish();
      expect(gps.recordingListeners + gps.plainListeners, 0);
    });

    test(
      'the last known position shows at once, and counts for nothing',
      () async {
        gps.last = fix(0, 0, accuracy: 15);
        await tracker.prepare();
        expect(tracker.snapshot.position, isNotNull);
        expect(
          tracker.snapshot.status,
          TrackerStatus.locating,
          reason: 'an old position is not a fix to start on',
        );
      },
    );

    test('leaving before anything was recorded leaves no open run', () async {
      await tracker.prepare();
      await tracker.start();
      final id = tracker.snapshot.runId!;
      tracker.dispose();
      await tracker.closed;
      expect(await repo.byId(id), isNull);
      expect(await repo.active(), isNull);
    });

    test('says so when location is refused', () async {
      gps.access = LocationAccess.deniedForever;
      await tracker.prepare();
      expect(tracker.snapshot.status, TrackerStatus.denied);
      gps.access = LocationAccess.serviceOff;
      await tracker.prepare();
      expect(tracker.snapshot.status, TrackerStatus.serviceOff);
    });

    test('records, persists every point, and finishes', () async {
      await tracker.prepare();
      await send(fix(0, 0));
      await tracker.start();
      for (var s = 1; s <= 200; s++) {
        clockMs = fix(s, 0).tMs;
        await send(fix(s, s * 3.0));
      }
      expect(tracker.snapshot.distanceM, closeTo(600, 6));
      final runId = tracker.snapshot.runId!;
      expect((await repo.points(runId)).length, greaterThanOrEqualTo(199));

      final run = await tracker.finish(effort: 3);
      expect(run!.status, RunStatus.finished);
      expect(run.distanceM, closeTo(600, 6));
      expect(tracker.snapshot.status, TrackerStatus.finished);
      expect(gps.listening, isFalse, reason: 'the GPS goes off at the end');
    });

    test('a pause breaks the trail and counts nothing across it', () async {
      await tracker.prepare();
      await tracker.start();
      for (var s = 0; s <= 60; s++) {
        clockMs = fix(s, 0).tMs;
        await send(fix(s, s * 3.0));
      }
      tracker.pause();
      for (var s = 61; s <= 120; s++) {
        clockMs = fix(s, 0).tMs;
        await send(fix(s, 180 + (s - 60) * 3.0));
      }
      expect(tracker.snapshot.distanceM, closeTo(180, 4));
      tracker.resume();
      for (var s = 121; s <= 180; s++) {
        clockMs = fix(s, 0).tMs;
        await send(fix(s, 360 + (s - 120) * 3.0));
      }
      expect(tracker.snapshot.distanceM, closeTo(360, 8));
      expect(tracker.snapshot.segments, hasLength(2));
      final pts = await repo.points(tracker.snapshot.runId!);
      expect(pts.where((p) => p.segmentStart), hasLength(2));
    });

    test('a run killed mid-way resumes as a new segment', () async {
      await tracker.prepare();
      await tracker.start();
      for (var s = 0; s <= 60; s++) {
        clockMs = fix(s, 0).tMs;
        await send(fix(s, s * 3.0));
      }
      final runId = tracker.snapshot.runId!;
      tracker.dispose(); // the phone killed the app

      final again = RunTracker(repo: repo, source: gps, nowMs: () => clockMs);
      addTearDown(again.dispose);
      await again.prepare();
      expect(again.snapshot.status, TrackerStatus.recording);
      expect(again.snapshot.runId, runId);
      expect(again.snapshot.distanceM, closeTo(180, 4));

      gps.controller.add(fix(300, 400));
      await again.settled();
      for (var s = 301; s <= 330; s++) {
        clockMs = fix(s, 0).tMs;
        gps.controller.add(fix(s, 400 + (s - 300) * 3.0));
        await again.settled();
      }
      expect(again.snapshot.distanceM, closeTo(270, 8));
      expect(again.snapshot.segments, hasLength(2));
    });

    test('discarding leaves nothing behind', () async {
      await tracker.prepare();
      await tracker.start();
      await send(fix(0, 0));
      final id = tracker.snapshot.runId!;
      await tracker.discard();
      expect(await repo.byId(id), isNull);
      expect(tracker.snapshot.status, TrackerStatus.idle);
    });
  });
}

class _FakeLocation implements LocationSource {
  LocationAccess access = LocationAccess.granted;
  RunFix? last;
  final controller = StreamController<RunFix>.broadcast(sync: true);
  int plainListeners = 0;
  int recordingListeners = 0;

  bool get listening => plainListeners + recordingListeners > 0;

  @override
  Future<LocationAccess> ensureAccess() async => access;

  @override
  Future<RunFix?> lastKnown() async => last;

  @override
  Stream<RunFix> watch({bool recording = false}) {
    late StreamController<RunFix> out;
    StreamSubscription<RunFix>? sub;
    out = StreamController<RunFix>(
      sync: true,
      onListen: () {
        recording ? recordingListeners++ : plainListeners++;
        sub = controller.stream.listen(out.add);
      },
      onCancel: () async {
        if (recording) {
          recordingListeners = math.max(0, recordingListeners - 1);
        } else {
          plainListeners = math.max(0, plainListeners - 1);
        }
        await sub?.cancel();
      },
    );
    return out.stream;
  }

  @override
  Future<void> openSettings() async {}
}
