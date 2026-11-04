// Checks on a plot boundary walked with the phone.
//
// Of the 42 boundaries recorded with the app up to November 2026, 11 had only
// three points, several had every point within a few metres of the others (area
// ~0 ha against a recorded 0.3–1.3 ha), and some were walked out of order so the
// outline crossed itself. These checks stop that at the source: a corner too
// close to another is refused, a weak GPS fix is flagged, and a boundary is only
// saved with four corners, an outline that does not cross itself, and an area
// that is a real plot's.

import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

class PolygonQuality {
  /// Corners closer than this are the same corner taken twice.
  static const double minCornerSpacingM = 3;

  /// A fix worse than this moves a corner more than a small plot's width.
  static const double warnAccuracyM = 10;

  /// One per corner of the plot.
  static const int minCorners = 4;

  /// Smaller than this is points bunched together, not a plot (0.01 ha).
  static const double minAreaM2 = 100;

  static const Distance _distance = Distance();

  static double metres(LatLng a, LatLng b) => _distance.as(LengthUnit.Meter, a, b);

  /// The nearest existing corner to [p], as (index, metres); null when none.
  static (int, double)? nearest(LatLng p, List<LatLng> corners) {
    (int, double)? best;
    for (int i = 0; i < corners.length; i++) {
      final d = metres(p, corners[i]);
      if (best == null || d < best.$2) best = (i, d);
    }
    return best;
  }

  /// Corners in a local metre grid around their first one.
  static List<math.Point<double>> _local(List<LatLng> pts) {
    if (pts.isEmpty) return const [];
    final lat0 = pts.first.latitude;
    final lng0 = pts.first.longitude;
    final k = math.cos(lat0 * math.pi / 180);
    return [
      for (final p in pts)
        math.Point((p.longitude - lng0) * 111320 * k, (p.latitude - lat0) * 110540),
    ];
  }

  /// Area enclosed by the corners, in square metres (shoelace).
  static double areaM2(List<LatLng> pts) {
    final xy = _local(pts);
    if (xy.length < 3) return 0;
    double s = 0;
    for (int i = 0; i < xy.length; i++) {
      final a = xy[i], b = xy[(i + 1) % xy.length];
      s += a.x * b.y - b.x * a.y;
    }
    return s.abs() / 2;
  }

  static bool _cross(math.Point<double> p1, math.Point<double> p2, math.Point<double> p3, math.Point<double> p4) {
    double o(math.Point<double> a, math.Point<double> b, math.Point<double> c) =>
        (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
    final d1 = o(p3, p4, p1), d2 = o(p3, p4, p2), d3 = o(p1, p2, p3), d4 = o(p1, p2, p4);
    return ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) && ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0));
  }

  /// True when two non-adjacent edges of the outline cross.
  static bool selfIntersects(List<LatLng> pts) {
    final xy = _local(pts);
    final n = xy.length;
    if (n < 4) return false;
    for (int i = 0; i < n; i++) {
      for (int j = i + 1; j < n; j++) {
        if ((i + 1) % n == j || (j + 1) % n == i) continue; // neighbours share a corner
        if (_cross(xy[i], xy[(i + 1) % n], xy[j], xy[(j + 1) % n])) return true;
      }
    }
    return false;
  }

  /// Indices of the corners in walking order around their centre — what an
  /// outline walked out of order should have been.
  static List<int> orderAroundCentre(List<LatLng> pts) {
    final xy = _local(pts);
    final cx = xy.fold<double>(0, (s, p) => s + p.x) / xy.length;
    final cy = xy.fold<double>(0, (s, p) => s + p.y) / xy.length;
    final idx = List<int>.generate(xy.length, (i) => i);
    idx.sort((a, b) => math.atan2(xy[a].y - cy, xy[a].x - cx).compareTo(math.atan2(xy[b].y - cy, xy[b].x - cx)));
    return idx;
  }
}
