import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/run/run.dart';
import 'db/database.dart';
import 'db/tables.dart';
import 'run_repository.dart';

/// Whether the phone will say where it is.
enum LocationAccess {
  granted,

  /// Granted, but only "approximate": a fix a kilometre wide. Android asks
  /// precise-or-approximate in the same dialog, and a run needs precise.
  approximate,
  denied,
  deniedForever,
  serviceOff,
}

/// Where fixes come from. The real one wraps the location plugin and its
/// foreground service (run_location.dart); tests feed their own.
abstract interface class LocationSource {
  /// Checks, and if needed asks for, location permission.
  Future<LocationAccess> ensureAccess();

  /// Fixes, about one a second, for as long as someone listens. With
  /// [recording], listening runs the foreground service and its "Recording
  /// your run" notification, so the run keeps recording with the screen off.
  /// Without it — while only looking for a fix — there is no notification.
  Stream<RunFix> watch({bool recording = false});

  /// The phone's last known position, at once: something to show on the map
  /// while the GPS warms up. Never counted.
  Future<RunFix?> lastKnown();

  /// Opens the app's system settings, for a permission refused for good.
  Future<void> openSettings();
}

enum TrackerStatus {
  /// Nothing yet.
  idle,

  /// Listening, waiting for a fix good enough to start on.
  locating,

  /// A good fix: ready to go.
  ready,
  recording,
  paused,
  finished,

  /// Location permission refused.
  denied,

  /// Location is switched off on the phone.
  serviceOff,

  /// Only approximate location is allowed.
  approximate,
}

/// Everything the live screen draws, at one moment.
class RunSnapshot {
  const RunSnapshot({
    required this.status,
    this.runId,
    this.distanceM = 0,
    this.movingMs = 0,
    this.elapsedMs = 0,
    this.currentPaceSecPerKm,
    this.avgPaceSecPerKm,
    this.autoPaused = false,
    this.accuracyM,
    this.position,
    this.segments = const [],
    this.splits = const [],
  });

  final TrackerStatus status;
  final int? runId;
  final double distanceM;
  final int movingMs;
  final int elapsedMs;
  final double? currentPaceSecPerKm;
  final double? avgPaceSecPerKm;
  final bool autoPaused;

  /// Of the latest fix, accepted or not: how sure the GPS is right now.
  final double? accuracyM;

  /// The latest fix, for the "you are here" dot.
  final GeoPoint? position;

  /// The trail, broken where it was paused.
  final List<List<GeoPoint>> segments;
  final List<RunSplit> splits;

  bool get isLive =>
      status == TrackerStatus.recording || status == TrackerStatus.paused;

  double? get speedKmh =>
      currentPaceSecPerKm == null ? null : 3600 / currentPaceSecPerKm!;
}

/// Records one run: fixes in, filtered, counted, and persisted the moment
/// they arrive.
///
/// Persist-on-every-point is the session runner's rule, for the same reason:
/// a phone in a pocket can be killed at any second, and [prepare] picks an
/// unfinished run back up as a new segment instead of losing it.
class RunTracker {
  RunTracker({
    required this.repo,
    required this.source,
    this.link,
    int Function()? nowMs,
    this.readyAccuracyM = 30,
  }) : _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  final RunRepository repo;
  final LocationSource source;

  /// The programme day this run belongs to; null for a free run.
  final RunLink? link;
  final int Function() _nowMs;

  /// A fix this sure means the GPS has found him. Start does not wait for
  /// it — the clock runs and the trail begins at the first usable fix — but
  /// the screen says "GPS fair" or "GPS good" rather than "waiting".
  final double readyAccuracyM;

  final ValueNotifier<RunSnapshot> state = ValueNotifier(
    const RunSnapshot(status: TrackerStatus.idle),
  );

  RunSnapshot get snapshot => state.value;

  TrackerStatus _status = TrackerStatus.idle;
  RunTrack _track = RunTrack();
  FixFilter _filter = FixFilter();
  StreamSubscription<RunFix>? _sub;
  bool _subRecording = false;
  Future<void>? _closing;
  int? _runId;
  bool _nextSegment = true;
  RunFix? _lastRaw;

  /// A position to show before any fix: the phone's last known one.
  RunFix? _lastShown;
  int? _startedMs;
  int _pausedMs = 0;
  int? _pausedAt;
  int _sinceSave = 0;
  bool _disposed = false;

  /// Fixes are handled one at a time, in order: each waits for the last
  /// one's database write.
  Future<void> _queue = Future.value();

  /// Completes when every fix received so far has been handled.
  Future<void> settled() => _queue;

  /// Completes once [dispose] has finished tidying up.
  Future<void> get closed => _closing ?? Future.value();

  /// Checks permission, picks up an unfinished run if there is one, and
  /// starts listening.
  Future<void> prepare() async {
    final access = await source.ensureAccess();
    if (_disposed) return;
    switch (access) {
      case LocationAccess.denied || LocationAccess.deniedForever:
        _status = TrackerStatus.denied;
        _emit();
        return;
      case LocationAccess.serviceOff:
        _status = TrackerStatus.serviceOff;
        _emit();
        return;
      case LocationAccess.approximate:
        _status = TrackerStatus.approximate;
        _emit();
        return;
      case LocationAccess.granted:
        break;
    }

    // A run left open with no trail is nothing to pick up.
    await repo.tidyEmptyRuns();
    if (_disposed) return;

    final open = await repo.active();
    if (open != null) {
      _runId = open.id;
      _track = await repo.track(open.id);
      _startedMs = open.startedAtMs;
      _filter = FixFilter();
      _nextSegment = true;
      _status = open.status == RunStatus.paused
          ? TrackerStatus.paused
          : TrackerStatus.recording;
      if (_status == TrackerStatus.paused) _pausedAt = _nowMs();
    } else if (_runId == null) {
      _status = TrackerStatus.locating;
      // Somewhere to centre the map while the GPS warms up.
      final last = await source.lastKnown();
      if (_disposed) return;
      if (last != null && _lastRaw == null) _lastShown = last;
    }
    await _listen(recording: _runId != null);
    _emit();
  }

  /// Listens, recording or not. Switching from one to the other replaces the
  /// stream, so the notification starts with the run and not before.
  Future<void> _listen({required bool recording}) async {
    if (_sub != null && _subRecording == recording) return;
    await _stopListening();
    if (_disposed) return;
    _subRecording = recording;
    _sub = source.watch(recording: recording).listen((f) {
      _queue = _queue.then((_) => _onFix(f));
    });
  }

  Future<void> _stopListening() async {
    final sub = _sub;
    _sub = null;
    await sub?.cancel();
  }

  Future<void> _onFix(RunFix f) async {
    if (_disposed) return;
    _lastRaw = f;
    switch (_status) {
      case TrackerStatus.locating || TrackerStatus.ready:
        _status = (f.accuracyM ?? double.infinity) <= readyAccuracyM
            ? TrackerStatus.ready
            : TrackerStatus.locating;
      case TrackerStatus.recording:
        await _record(f);
      default:
        break;
    }
    _emit();
  }

  Future<void> _record(RunFix f) async {
    if (_filter.judge(f) != FixVerdict.accept) return;
    final seg = _nextSegment;
    _nextSegment = false;
    _track.add(f, segmentStart: seg);
    await repo.addPoint(_runId!, f, segmentStart: seg);
    if (++_sinceSave >= 10) {
      _sinceSave = 0;
      await repo.saveProgress(_runId!, _track);
    }
  }

  /// Opens the run and records from here, with or without a fix yet: the
  /// clock starts now and the trail at the first usable fix. A fresh fix
  /// from the last few seconds becomes the first point, so the trail starts
  /// where he stands.
  Future<void> start() async {
    if (_runId != null || _disposed) return;
    _runId = await repo.start(link: link);
    _startedMs = _nowMs();
    _track = RunTrack();
    _filter = FixFilter();
    _nextSegment = true;
    _status = TrackerStatus.recording;
    final seed = _lastRaw;
    if (seed != null && _nowMs() - seed.tMs <= 5000) {
      _queue = _queue.then((_) => _record(seed));
    }
    await _listen(recording: true);
    _emit();
    await _queue;
  }

  void pause() {
    if (_status != TrackerStatus.recording) return;
    _status = TrackerStatus.paused;
    _pausedAt = _nowMs();
    final id = _runId!;
    _queue = _queue.then((_) async {
      await repo.setStatus(id, RunStatus.paused);
      await repo.saveProgress(id, _track);
    });
    _emit();
  }

  void resume() {
    if (_status != TrackerStatus.paused) return;
    _pausedMs += _nowMs() - (_pausedAt ?? _nowMs());
    _pausedAt = null;
    _status = TrackerStatus.recording;
    _nextSegment = true;
    _filter.reset();
    final id = _runId!;
    _queue = _queue.then((_) => repo.setStatus(id, RunStatus.recording));
    _emit();
  }

  /// Closes the run (logging it into its session, for a programme run) and
  /// switches the GPS off.
  Future<Run?> finish({int? effort}) async {
    await _queue;
    final id = _runId;
    if (id == null) return null;
    await _stopListening();
    final run = await repo.finish(id, _track, link: link, effort: effort);
    _status = TrackerStatus.finished;
    _emit();
    return run;
  }

  /// Throws the run away, trail and all.
  Future<void> discard() async {
    await _queue;
    await _stopListening();
    final id = _runId;
    if (id != null) await repo.discard(id);
    _runId = null;
    _track = RunTrack();
    _startedMs = null;
    _status = TrackerStatus.idle;
    _emit();
  }

  /// Opens the phone's settings, for permission refused for good.
  Future<void> openSettings() => source.openSettings();

  int get _elapsed {
    final start = _startedMs;
    if (start == null) return 0;
    final now = _nowMs();
    final pausedNow = _pausedAt == null ? 0 : now - _pausedAt!;
    return (now - start - _pausedMs - pausedNow).clamp(0, 1 << 62);
  }

  /// Wall-clock time moves even when no fix arrives; the screen calls this
  /// once a second.
  void tick() => _emit();

  void _emit() {
    if (_disposed) return;
    final raw = _lastRaw;
    state.value = RunSnapshot(
      status: _status,
      runId: _runId,
      distanceM: _track.distanceM,
      movingMs: _track.movingMs,
      elapsedMs: _elapsed,
      currentPaceSecPerKm: _status == TrackerStatus.recording
          ? _track.currentPaceSecPerKm
          : null,
      avgPaceSecPerKm: _track.avgPaceSecPerKm,
      autoPaused: _status == TrackerStatus.recording && _track.autoPaused,
      accuracyM: raw?.accuracyM,
      position: raw?.point ?? _lastShown?.point,
      segments: [
        for (final s in _track.segments) [for (final f in s) f.point],
      ],
      splits: _track.splits,
    );
  }

  /// The run's numbers as they stand.
  RunTrack get track => _track;

  /// Stops listening. An unfinished run with a trail stays open in the
  /// database, to be picked up by the next [prepare]; one with nothing on it
  /// is thrown away, so leaving never leaves a phantom "Run still open".
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final id = _runId;
    _closing = () async {
      await _stopListening();
      await _queue;
      if (id != null && _status != TrackerStatus.finished) {
        final points = await repo.points(id);
        if (points.isEmpty) await repo.discard(id);
      }
    }();
    state.dispose();
  }
}
