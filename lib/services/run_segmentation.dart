import 'dart:math' as math;
import '../providers/csv_data_provider.dart';

class RunSegment {
  final int startIndex;
  final int endIndex; // inclusive
  final DateTime startTime;
  final DateTime endTime;
  final double minLat;
  final double maxLat;
  final double minLon;
  final double maxLon;

  const RunSegment({
    required this.startIndex,
    required this.endIndex,
    required this.startTime,
    required this.endTime,
    required this.minLat,
    required this.maxLat,
    required this.minLon,
    required this.maxLon,
  });
}

class RunSummary {
  final RunSegment segment;
  final Map<String, double> avgByMetric;

  const RunSummary({required this.segment, required this.avgByMetric});
}

class RunSegmentationService {
  // Main API: segment runs using spatial/temporal heuristics
  static List<RunSegment> segmentRuns({
    required List<DateTime> timestamps,
    required List<double> lats,
    required List<double> lons,
    Duration maxGap = const Duration(minutes: 12),
  }) {
    final int n = math.min(timestamps.length, math.min(lats.length, lons.length));
    if (n == 0) return const [];

    // Compute step distances (degrees). Guard against NaNs.
    final List<double> steps = <double>[];
    for (int i = 1; i < n; i++) {
      final double aLat = lats[i - 1];
      final double aLon = lons[i - 1];
      final double bLat = lats[i];
      final double bLon = lons[i];
      if (!_isFinite(aLat) || !_isFinite(aLon) || !_isFinite(bLat) || !_isFinite(bLon)) {
        steps.add(0);
        continue;
      }
      steps.add(_hypot(bLat - aLat, bLon - aLon));
    }

    final double medianStep = _median(steps.where((v) => v.isFinite && v > 0).toList());
    // Dynamic thresholds
    final double base = medianStep.isFinite && medianStep > 0 ? medianStep : 0.00015; // ~17m
    final double largeJumpThreshold = base * 10; // "farther than normal"
    final double returnRadius = base * 2.5; // near starting stop

    final List<RunSegment> runs = [];
    int runStart = 0;
    double startLat = lats[0];
    double startLon = lons[0];
    bool movedAwayFromStart = false;
    double minLat = startLat, maxLat = startLat, minLon = startLon, maxLon = startLon;

    for (int i = 1; i < n; i++) {
      // Bounds tracking
      if (_isFinite(lats[i]) && _isFinite(lons[i])) {
        if (lats[i] < minLat) minLat = lats[i];
        if (lats[i] > maxLat) maxLat = lats[i];
        if (lons[i] < minLon) minLon = lons[i];
        if (lons[i] > maxLon) maxLon = lons[i];
      }

      final bool bigTimeGap = timestamps[i].difference(timestamps[i - 1]).abs() > maxGap;
      final double step = steps[i - 1].isFinite ? steps[i - 1] : 0.0;

      // Heuristic A: large spatial jump -> start new run at i
      if (step > largeJumpThreshold || bigTimeGap) {
        runs.add(RunSegment(
          startIndex: runStart,
          endIndex: i - 1,
          startTime: timestamps[runStart],
          endTime: timestamps[i - 1],
          minLat: minLat,
          maxLat: maxLat,
          minLon: minLon,
          maxLon: maxLon,
        ));
        // reset
        runStart = i;
        startLat = lats[i];
        startLon = lons[i];
        movedAwayFromStart = false;
        minLat = startLat; maxLat = startLat; minLon = startLon; maxLon = startLon;
        continue;
      }

      // Track if we have moved away sufficiently from the start
      final double distFromStart = _hypot(lats[i] - startLat, lons[i] - startLon);
      if (distFromStart > base * 4) {
        movedAwayFromStart = true;
      }

      // Heuristic B: returned close to the starting point after moving away -> new run
      if (movedAwayFromStart && distFromStart <= returnRadius && (i - runStart) >= 8) {
        runs.add(RunSegment(
          startIndex: runStart,
          endIndex: i - 1,
          startTime: timestamps[runStart],
          endTime: timestamps[i - 1],
          minLat: minLat,
          maxLat: maxLat,
          minLon: minLon,
          maxLon: maxLon,
        ));
        runStart = i;
        startLat = lats[i];
        startLon = lons[i];
        movedAwayFromStart = false;
        minLat = startLat; maxLat = startLat; minLon = startLon; maxLon = startLon;
      }
    }

    // close last run
    double lastMinLat = minLat;
    double lastMaxLat = maxLat;
    double lastMinLon = minLon;
    double lastMaxLon = maxLon;
    for (int i = runStart; i < n; i++) {
      if (_isFinite(lats[i])) {
        if (lats[i] < lastMinLat) lastMinLat = lats[i];
        if (lats[i] > lastMaxLat) lastMaxLat = lats[i];
      }
      if (_isFinite(lons[i])) {
        if (lons[i] < lastMinLon) lastMinLon = lons[i];
        if (lons[i] > lastMaxLon) lastMaxLon = lons[i];
      }
    }
    runs.add(RunSegment(
      startIndex: runStart,
      endIndex: n - 1,
      startTime: timestamps[runStart],
      endTime: timestamps[n - 1],
      minLat: lastMinLat,
      maxLat: lastMaxLat,
      minLon: lastMinLon,
      maxLon: lastMaxLon,
    ));

    // Remove degenerate runs with < 3 points if there are other runs
    final filtered = runs.where((r) => (r.endIndex - r.startIndex + 1) >= 3 || runs.length == 1).toList();
    return filtered;
  }

  static List<RunSummary> summarizeRuns({required CSVDataProvider provider, required List<RunSegment> segments}) {
    final List<RunSummary> out = [];
    for (final seg in segments) {
      final avg = <String, double>{};
      avg['pH'] = _avg(provider.pH, seg.startIndex, seg.endIndex);
      avg['N'] = _avg(provider.n, seg.startIndex, seg.endIndex);
      avg['P'] = _avg(provider.p, seg.startIndex, seg.endIndex);
      avg['K'] = _avg(provider.k, seg.startIndex, seg.endIndex);
      avg['Temperature'] = _avg(provider.temperature, seg.startIndex, seg.endIndex);
      avg['Humidity'] = _avg(provider.humidity, seg.startIndex, seg.endIndex);
      avg['EC'] = _avg(provider.ec, seg.startIndex, seg.endIndex);
      out.add(RunSummary(segment: seg, avgByMetric: avg));
    }
    return out;
  }

  static List<DateTime> runStartTimes(List<RunSegment> segments) => segments.map((s) => s.startTime).toList();

  static List<double> averagesForMetric(List<RunSummary> summaries, String metric) {
    return summaries.map((s) => s.avgByMetric[metric] ?? double.nan).toList();
  }

  static double _avg(List<double> values, int start, int end) {
    if (values.isEmpty) return double.nan;
    final int n = values.length;
    final int s = math.max(0, math.min(start, n - 1));
    final int e = math.max(s, math.min(end, n - 1));
    double sum = 0.0;
    int count = 0;
    for (int i = s; i <= e; i++) {
      final v = values[i];
      if (v.isFinite) {
        sum += v;
        count++;
      }
    }
    if (count == 0) return double.nan;
    return sum / count;
  }

  static double _median(List<double> list) {
    if (list.isEmpty) return double.nan;
    final sorted = List<double>.from(list)..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return (sorted[mid - 1] + sorted[mid]) / 2.0;
  }

  static bool _isFinite(double v) => v.isFinite && !v.isNaN;
  static double _hypot(double a, double b) => math.sqrt(a * a + b * b);
}
