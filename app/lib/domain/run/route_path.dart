import 'dart:math' as math;

import 'geo.dart';

GeoPoint _lerp(GeoPoint a, GeoPoint b, double t) =>
    GeoPoint(a.lat + (b.lat - a.lat) * t, a.lng + (b.lng - a.lng) * t);

/// A recorded route measured along its length: what draws it in after a
/// run, and what moves the replay dot with the distance and time ticking.
///
/// Segments stay separate — a pause is a break in the line — and the jump
/// between them is neither distance nor time.
class RoutePath {
  RoutePath(List<List<RunFix>> segments)
    : _segs = [
        for (final s in segments)
          if (s.isNotEmpty) s,
      ] {
    var d = 0.0;
    var t = 0;
    for (final s in _segs) {
      final ds = <double>[d];
      final ts = <int>[t];
      for (var i = 1; i < s.length; i++) {
        d += haversineM(s[i - 1].point, s[i].point);
        t += math.max(0, s[i].tMs - s[i - 1].tMs);
        ds.add(d);
        ts.add(t);
      }
      _dist.add(ds);
      _time.add(ts);
    }
    lengthM = d;
    durationMs = t;
  }

  final List<List<RunFix>> _segs;
  final _dist = <List<double>>[];
  final _time = <List<int>>[];

  /// Metres along the route, pauses not counted.
  late final double lengthM;

  /// Time along the route, pauses not counted.
  late final int durationMs;

  /// The route up to [fraction] of its length, still broken where it was
  /// paused, ending exactly at that point.
  List<List<GeoPoint>> upTo(double fraction) {
    if (fraction <= 0 || _segs.isEmpty) return const [];
    final target = fraction.clamp(0.0, 1.0) * lengthM;
    final out = <List<GeoPoint>>[];
    for (var i = 0; i < _segs.length; i++) {
      final s = _segs[i];
      final ds = _dist[i];
      if (ds.first > target && out.isNotEmpty) break;
      final pts = <GeoPoint>[s.first.point];
      for (var j = 1; j < s.length; j++) {
        if (ds[j] <= target) {
          pts.add(s[j].point);
          continue;
        }
        final span = ds[j] - ds[j - 1];
        final t = span == 0 ? 0.0 : (target - ds[j - 1]) / span;
        pts.add(_lerp(s[j - 1].point, s[j].point, t));
        out.add(pts);
        return out;
      }
      out.add(pts);
    }
    return out;
  }

  /// The route from [fromM] to [toM] metres along it, ending exactly on
  /// both, still broken where it was paused. Empty when there is nothing
  /// between them.
  List<List<GeoPoint>> between(double fromM, double toM) {
    final a = math.max(0.0, fromM);
    final b = math.min(lengthM, toM);
    if (_segs.isEmpty || b <= a) return const [];
    final out = <List<GeoPoint>>[];
    for (var i = 0; i < _segs.length; i++) {
      final s = _segs[i];
      final ds = _dist[i];
      if (ds.last <= a) continue;
      if (ds.first >= b) break;
      GeoPoint cut(int j, double target) {
        final span = ds[j] - ds[j - 1];
        final t = span == 0 ? 0.0 : (target - ds[j - 1]) / span;
        return _lerp(s[j - 1].point, s[j].point, t);
      }

      final pts = <GeoPoint>[];
      for (var j = 0; j < s.length; j++) {
        final d = ds[j];
        if (j > 0) {
          final d0 = ds[j - 1];
          if (d0 < a && d > a) pts.add(cut(j, a));
          if (d0 < b && d > b) {
            pts.add(cut(j, b));
            break;
          }
        }
        if (d >= a && d <= b) pts.add(s[j].point);
      }
      if (pts.length > 1) out.add(pts);
    }
    return out;
  }

  /// Where the replay dot is at [fraction]: the point, the distance run and
  /// the time taken to get there.
  ({GeoPoint point, double distanceM, int elapsedMs}) at(double fraction) {
    if (_segs.isEmpty) {
      return (point: const GeoPoint(0, 0), distanceM: 0, elapsedMs: 0);
    }
    final target = fraction.clamp(0.0, 1.0) * lengthM;
    for (var i = 0; i < _segs.length; i++) {
      final s = _segs[i];
      final ds = _dist[i];
      final ts = _time[i];
      for (var j = 1; j < s.length; j++) {
        if (ds[j] < target) continue;
        final span = ds[j] - ds[j - 1];
        final t = span == 0 ? 0.0 : (target - ds[j - 1]) / span;
        return (
          point: _lerp(s[j - 1].point, s[j].point, t),
          distanceM: target,
          elapsedMs: (ts[j - 1] + (ts[j] - ts[j - 1]) * t).round(),
        );
      }
    }
    final last = _segs.last;
    return (point: last.last.point, distanceM: lengthM, elapsedMs: durationMs);
  }
}

/// The route as it may leave the phone on a shared card: [hideM] cut from
/// each end, so neither the start nor the finish — for most runs, the
/// front door — is on it. Empty when too little would be left to be worth
/// drawing (a short loop is all near the door anyway).
List<List<GeoPoint>> privateRoute(
  List<List<RunFix>> segments, {
  double hideM = 200,
}) {
  final path = RoutePath(segments);
  if (hideM <= 0) return path.between(0, path.lengthM);
  if (path.lengthM - 2 * hideM < 50) return const [];
  return path.between(hideM, path.lengthM - hideM);
}

/// A stretch of the route and how fast it was run: the unit the route is
/// coloured by.
class PaceStretch {
  const PaceStretch({
    required this.points,
    required this.distanceM,
    required this.paceSecPerKm,
  });

  final List<GeoPoint> points;
  final double distanceM;
  final double paceSecPerKm;
}

/// The route cut into stretches of about [everyM], each with its pace.
/// Stretches share their end points, so the coloured line has no gaps; a
/// short tail is folded into the stretch before it.
List<PaceStretch> paceStretches(
  List<List<RunFix>> segments, {
  double everyM = 100,
}) {
  final out = <PaceStretch>[];
  for (final s in segments) {
    if (s.length < 2) continue;
    var start = 0;
    var d = 0.0;
    PaceStretch make(int from, int to, double dist) => PaceStretch(
      points: [for (var k = from; k <= to; k++) s[k].point],
      distanceM: dist,
      paceSecPerKm: dist <= 0
          ? 0
          : (s[to].tMs - s[from].tMs) / 1000 / (dist / 1000),
    );
    final mine = <PaceStretch>[];
    var prevStart = 0;
    for (var i = 1; i < s.length; i++) {
      d += haversineM(s[i - 1].point, s[i].point);
      if (d >= everyM) {
        mine.add(make(start, i, d));
        prevStart = start;
        start = i;
        d = 0;
      }
    }
    if (start < s.length - 1) {
      if (mine.isNotEmpty && d < everyM / 2) {
        // Too short to stand alone: its pace would be noise. It joins the
        // stretch before it.
        final prev = mine.removeLast();
        mine.add(make(prevStart, s.length - 1, prev.distanceM + d));
      } else {
        mine.add(make(start, s.length - 1, d));
      }
    }
    out.addAll(mine);
  }
  return out;
}

/// A shade per stretch, 1 for the quickest and 0 for the slowest, measured
/// between the 10th and 90th percentile so one stop at a crossing does not
/// wash out the rest. A steady run is an even 0.5.
List<double> paceShades(List<PaceStretch> stretches) {
  final paces = [
    for (final s in stretches)
      if (s.paceSecPerKm > 0) s.paceSecPerKm,
  ]..sort();
  if (paces.isEmpty) return [for (final _ in stretches) 0.5];
  double pct(double p) =>
      paces[((paces.length - 1) * p).round().clamp(0, paces.length - 1)];
  final fast = pct(0.1), slow = pct(0.9);
  if (slow - fast < 5) return [for (final _ in stretches) 0.5];
  return [
    for (final s in stretches)
      s.paceSecPerKm <= 0
          ? 0.5
          : ((slow - s.paceSecPerKm) / (slow - fast)).clamp(0.0, 1.0),
  ];
}
