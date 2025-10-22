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
  // Time-based segmentation: split runs when consecutive timestamps exceed timeGapThreshold
  static List<RunSegment> segmentRuns({
    required List<DateTime> timestamps,
    required List<double> lats,
    required List<double> lons,
    Duration timeGapThreshold = const Duration(hours: 1),
  }) {
    final int n = math.min(timestamps.length, math.min(lats.length, lons.length));
    if (n == 0) return const [];

    final List<RunSegment> runs = [];
    int runStart = 0;
    double minLat = lats[0];
    double maxLat = lats[0];
    double minLon = lons[0];
    double maxLon = lons[0];

    double _minLat = _isFinite(minLat) ? minLat : double.infinity;
    double _maxLat = _isFinite(maxLat) ? maxLat : -double.infinity;
    double _minLon = _isFinite(minLon) ? minLon : double.infinity;
    double _maxLon = _isFinite(maxLon) ? maxLon : -double.infinity;

    void commitRun(int endIndex) {
      // Ensure bounds include last point in the run
      for (int j = runStart; j <= endIndex; j++) {
        final a = lats[j];
        final b = lons[j];
        if (_isFinite(a)) {
          if (a < _minLat) _minLat = a;
          if (a > _maxLat) _maxLat = a;
        }
        if (_isFinite(b)) {
          if (b < _minLon) _minLon = b;
          if (b > _maxLon) _maxLon = b;
        }
      }
      final seg = RunSegment(
        startIndex: runStart,
        endIndex: endIndex,
        startTime: timestamps[runStart],
        endTime: timestamps[endIndex],
        minLat: _minLat.isFinite ? _minLat : 0,
        maxLat: _maxLat.isFinite ? _maxLat : 0,
        minLon: _minLon.isFinite ? _minLon : 0,
        maxLon: _maxLon.isFinite ? _maxLon : 0,
      );
      runs.add(seg);

      // Reset for next run
      if (endIndex + 1 < n) {
        runStart = endIndex + 1;
        _minLat = double.infinity;
        _maxLat = -double.infinity;
        _minLon = double.infinity;
        _maxLon = -double.infinity;
      }
    }

    for (int i = 1; i < n; i++) {
      final gap = timestamps[i].difference(timestamps[i - 1]).abs();
      if (gap > timeGapThreshold) {
        // End current run at i-1
        commitRun(i - 1);
      }
    }

    // Close last run
    commitRun(n - 1);

    // Return all runs, even short ones. Some datasets have brief runs.
    return runs;
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
