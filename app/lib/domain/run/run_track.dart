import 'dart:math' as math;

import 'geo.dart';

/// One kilometre of a run, or the part-kilometre at the end.
class RunSplit {
  const RunSplit({
    required this.km,
    required this.distanceM,
    required this.movingMs,
    this.partial = false,
  });

  /// 1-based.
  final int km;
  final double distanceM;
  final int movingMs;

  /// The last, unfinished kilometre.
  final bool partial;

  double? get paceSecPerKm =>
      distanceM <= 0 ? null : (movingMs / 1000) / (distanceM / 1000);
}

/// The pace over one stretch of a run, for the chart after it.
class PaceBucket {
  const PaceBucket(this.distanceM, this.paceSecPerKm);

  /// Where the stretch ends.
  final double distanceM;
  final double paceSecPerKm;
}

/// Everything a run's numbers come from, fed one accepted fix at a time.
///
/// Distance is counted between fixes at least [stepM] apart (or half the
/// fix's accuracy radius, if that is larger), so GPS drift while standing at
/// a crossing does not become distance. Speed is the straight-line
/// displacement over the last [windowMs] -- drift that wanders round in
/// circles goes nowhere. Moving time stops while that speed stays under
/// [stopSpeedMps] and restarts above [goSpeedMps].
class RunTrack {
  RunTrack({
    this.stepM = 4,
    this.stopSpeedMps = 0.6,
    this.goSpeedMps = 1.0,
    this.windowMs = 10000,
    this.elevStepM = 2,
  });

  final double stepM;
  final double stopSpeedMps;
  final double goSpeedMps;
  final int windowMs;
  final double elevStepM;

  final List<List<RunFix>> _segments = [];
  final List<RunFix> _window = [];
  final List<RunSplit> _fullSplits = [];

  /// (distance, moving time) each time the distance moved: what the pace
  /// profile is interpolated from.
  final List<(double, int)> _samples = [(0, 0)];

  RunFix? _anchor;
  double _distance = 0;
  int _moving = 0;
  int _splitStartMoving = 0;
  double _maxSpeed = 0;
  double _speed = 0;
  bool _autoPaused = false;
  int? _firstMs;
  int? _lastMs;

  double? _altSmooth;
  double? _altRef;
  double _gain = 0;

  /// The accepted fixes, in the stretches recorded between pauses.
  List<List<RunFix>> get segments => _segments;

  double get distanceM => _distance;
  int get movingMs => _moving;
  int get elapsedMs =>
      _firstMs == null ? 0 : (_lastMs ?? _firstMs!) - _firstMs!;
  bool get autoPaused => _autoPaused;
  double get maxSpeedMps => _maxSpeed;
  double get elevGainM => _gain;

  /// Moving time over distance; null until there is some of both.
  double? get avgPaceSecPerKm => _distance < 10 || _moving <= 0
      ? null
      : (_moving / 1000) / (_distance / 1000);

  /// Pace over the last few seconds; null when stopped.
  double? get currentPaceSecPerKm =>
      _autoPaused || _speed < stopSpeedMps ? null : 1000 / _speed;

  RunFix? get last => _segments.isEmpty ? null : _segments.last.last;

  void add(RunFix fix, {bool segmentStart = false}) {
    _firstMs ??= fix.tMs;
    if (segmentStart || _segments.isEmpty) {
      _segments.add([fix]);
      _anchor = fix;
      _window
        ..clear()
        ..add(fix);
      _speed = 0;
      _lastMs = fix.tMs;
      _altSmooth = null;
      _altRef = null;
      _elevation(fix);
      return;
    }

    final prev = _segments.last.last;
    _segments.last.add(fix);
    final dt = math.max(0, fix.tMs - prev.tMs);
    _lastMs = fix.tMs;

    final before = _distance;
    _window.add(fix);
    while (_window.length > 2 && fix.tMs - _window[1].tMs >= windowMs) {
      _window.removeAt(0);
    }
    final span = fix.tMs - _window.first.tMs;
    _speed = span > 0
        ? haversineM(_window.first.point, fix.point) / (span / 1000)
        : 0;
    if (span >= 4000) {
      if (_autoPaused && _speed >= goSpeedMps) {
        _autoPaused = false;
      } else if (!_autoPaused && _speed < stopSpeedMps) {
        _autoPaused = true;
      }
      if (_speed > _maxSpeed) _maxSpeed = _speed;
    }

    // Standing still, the reference point stays where he stopped and drift
    // counts for nothing; once he moves off, the whole step from there is
    // credited, so the metres run before auto-pause lets go are not lost.
    if (!_autoPaused) {
      final step = haversineM(_anchor!.point, fix.point);
      final threshold = math.max(stepM, 0.5 * (fix.accuracyM ?? 0));
      if (step >= threshold) {
        _distance += step;
        _anchor = fix;
      }
    }

    final movingBefore = _moving;
    if (!_autoPaused) _moving += dt;
    if (_distance > before) _samples.add((_distance, _moving));
    _elevation(fix);
    _splitsCrossed(before, movingBefore);
  }

  void _elevation(RunFix fix) {
    final alt = fix.altitudeM;
    if (alt == null) return;
    // Smooth first, then count only climbs past a step: the altimeter in a
    // phone wanders a metre or two either way standing still.
    final s = _altSmooth == null
        ? alt
        : _altSmooth! + 0.3 * (alt - _altSmooth!);
    _altSmooth = s;
    final ref = _altRef;
    if (ref == null) {
      _altRef = s;
    } else if (s > ref + elevStepM) {
      _gain += s - ref;
      _altRef = s;
    } else if (s < ref - elevStepM) {
      _altRef = s;
    }
  }

  void _splitsCrossed(double distBefore, int movingBefore) {
    var nextKm = _fullSplits.length + 1;
    while (_distance >= nextKm * 1000) {
      final boundary = nextKm * 1000.0;
      final frac = _distance == distBefore
          ? 1.0
          : (boundary - distBefore) / (_distance - distBefore);
      final at = movingBefore + ((_moving - movingBefore) * frac).round();
      _fullSplits.add(
        RunSplit(km: nextKm, distanceM: 1000, movingMs: at - _splitStartMoving),
      );
      _splitStartMoving = at;
      nextKm++;
    }
  }

  /// Pace over every [bucketM] of the run (and the last half-bucket or
  /// more), for the chart on the summary.
  List<PaceBucket> profile({double bucketM = 100}) {
    if (_distance < bucketM / 2) return const [];
    double movingAt(double d) {
      for (var i = 1; i < _samples.length; i++) {
        final (d1, m1) = _samples[i];
        if (d1 >= d) {
          final (d0, m0) = _samples[i - 1];
          final f = d1 == d0 ? 1.0 : (d - d0) / (d1 - d0);
          return m0 + (m1 - m0) * f;
        }
      }
      return _samples.last.$2.toDouble();
    }

    final out = <PaceBucket>[];
    var prevD = 0.0;
    var prevT = 0.0;
    for (var k = 1; k * bucketM <= _distance + 1e-9; k++) {
      final d = k * bucketM;
      final t = movingAt(d);
      out.add(PaceBucket(d, (t - prevT) / 1000 / (bucketM / 1000)));
      prevD = d;
      prevT = t;
    }
    final rest = _distance - prevD;
    if (rest >= bucketM / 2) {
      out.add(PaceBucket(_distance, (_moving - prevT) / 1000 / (rest / 1000)));
    }
    return out;
  }

  /// Every full kilometre, then whatever is left over.
  List<RunSplit> get splits {
    final rest = _distance - _fullSplits.length * 1000;
    return [
      ..._fullSplits,
      if (rest > 1)
        RunSplit(
          km: _fullSplits.length + 1,
          distanceM: rest,
          movingMs: _moving - _splitStartMoving,
          partial: true,
        ),
    ];
  }
}
