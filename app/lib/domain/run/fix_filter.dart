import 'geo.dart';

/// What the filter made of one fix.
enum FixVerdict {
  accept,

  /// The sensor says it could be further off than a street is wide.
  inaccurate,

  /// Not newer than the last fix taken.
  stale,

  /// Further from the last fix than a runner can get in the time.
  teleport,
}

/// Decides which GPS fixes are worth drawing and counting.
///
/// Conservative on purpose: a dropped fix costs a metre of trail, a bad one
/// costs a 400 m spike and a pace nobody can run.
class FixFilter {
  FixFilter({this.maxAccuracyM = 40, this.maxSpeedMps = 9});

  /// Anything vaguer is dropped. 40 m, not tighter: distance is counted in
  /// steps of at least half the accuracy (RunTrack), so a vague fix adds
  /// trail but not metres, while dropping it leaves a straight-line gap. At
  /// 25 m a phone in a street of tall houses dropped half its fixes.
  final double maxAccuracyM;

  /// Faster than a sprinter, far faster than an easy run: 32 km/h.
  final double maxSpeedMps;

  RunFix? _last;

  FixVerdict judge(RunFix fix) {
    final acc = fix.accuracyM;
    if (acc == null || acc > maxAccuracyM) return FixVerdict.inaccurate;
    final last = _last;
    if (last != null) {
      if (fix.tMs <= last.tMs) return FixVerdict.stale;
      final dt = (fix.tMs - last.tMs) / 1000;
      final d = haversineM(last.point, fix.point);
      if (d / dt > maxSpeedMps) return FixVerdict.teleport;
    }
    _last = fix;
    return FixVerdict.accept;
  }

  /// After a pause, or when a killed run resumes: the next fix starts a new
  /// segment and is not compared with the old one.
  void reset() => _last = null;
}
