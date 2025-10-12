import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'package:csv/csv.dart';
import 'dart:math'; // Used for max, min, sqrt, and pow for IDW
import 'package:intl/intl.dart';

// New container class to return the grid data and its geographic aspect ratio.
class HeatmapGrid {
  final List<List<double>> grid;
  final double widthRatio; // Delta Lon / Delta Lat
  final List<double>? latAxis; // optional: grid row positions in latitude
  final List<double>? lonAxis; // optional: grid column positions in longitude

  HeatmapGrid({
    required this.grid,
    required this.widthRatio,
    this.latAxis,
    this.lonAxis,
  });
}

// A single data point
class HeatmapPoint {
  final int x;
  final int y;
  final DateTime t;
  final Map<String, double> metrics;
  final double? lat; // optional
  final double? lon; // optional

  HeatmapPoint({
    required this.x,
    required this.y,
    required this.t,
    required this.metrics,
    this.lat,
    this.lon,
  });
}

// Service for creating the heatmap grid
class HeatmapService {
  late List<HeatmapPoint> points;

  HeatmapService() {
    points = [];
  }

  void setPoints(List<HeatmapPoint> newPoints) {
    points = newPoints;
  }

  static Future<List<HeatmapPoint>> parseCsvAsset(String path) async {
    final rawData = await rootBundle.loadString(path);
    final parser = const CsvToListConverter();
    final List<List<dynamic>> csvTable = parser.convert(rawData);

    if (csvTable.isEmpty) return [];

    final header = csvTable.first.map((e) => e.toString()).toList();
    final lowerHeader = header.map((e) => e.trim().toLowerCase()).toList();

    // Detect coordinate/time columns (support x,y,t or timestamp,lat,lon)
    final xIndex = lowerHeader.indexOf('x');
    final yIndex = lowerHeader.indexOf('y');
    final tIndex = lowerHeader.indexOf('t');

    final timestampIndex = lowerHeader.indexOf('timestamp');
    final latIndex = lowerHeader.indexOf('lat');
    final lonIndex = lowerHeader.indexOf('lon');

    final bool useXY = xIndex != -1 && yIndex != -1 && (tIndex != -1 ? tIndex : timestampIndex) != -1;
    final bool useLatLon = latIndex != -1 && lonIndex != -1 && timestampIndex != -1;

    if (!useXY && !useLatLon) {
      throw Exception("CSV must contain either (x,y,t) or (timestamp,lat,lon) columns.");
    }

    // Identify metric columns and normalize display names (including categorical plant status)
    final Map<int, String> metricIndexToName = {};
    for (int i = 0; i < header.length; i++) {
      if (useXY) {
        if (i == xIndex || i == yIndex || i == (tIndex != -1 ? tIndex : timestampIndex)) continue;
      }
      if (useLatLon) {
        if (i == latIndex || i == lonIndex || i == timestampIndex) continue;
      }
      final key = lowerHeader[i];
      // Map common header keys to user-facing metric labels
      String display;
      switch (key) {
        case 'ph':
          display = 'pH';
          break;
        case 'temperature':
          display = 'Temperature';
          break;
        case 'humidity':
          display = 'Humidity';
          break;
        case 'ec':
          display = 'EC';
          break;
        case 'n':
          display = 'N';
          break;
        case 'p':
          display = 'P';
          break;
        case 'k':
          display = 'K';
          break;
        case 'plant_status':
          display = 'Plant Status';
          break;
        default:
          // Keep original if unknown
          display = header[i];
      }
      metricIndexToName[i] = display;
    }

    // Helper parsers
    double _toDouble(dynamic v) {
      if (v == null) return double.nan;
      if (v is num) return v.toDouble();
      final s = v.toString().trim();
      if (s.isEmpty) return double.nan;
      return double.tryParse(s) ?? double.nan;
    }

    DateTime _parseDate(dynamic v) {
      final s = v.toString().trim();
      try {
        // Accept ISO or space-separated; DateTime.parse treats no timezone as local
        return DateTime.parse(s);
      } catch (_) {
        // Parse as LOCAL time to avoid unintended timezone shifts
        try {
          return DateFormat('yyyy-MM-dd HH:mm:ss').parse(s);
        } catch (e) {
          throw Exception("Unable to parse date: $s");
        }
      }
    }

    // First pass: collect raw rows
    final List<_RawPoint> raw = [];
    for (int i = 1; i < csvTable.length; i++) {
      final row = csvTable[i];
      if (row.isEmpty) continue;

      final DateTime t = _parseDate(row[useXY ? (tIndex != -1 ? tIndex : timestampIndex) : timestampIndex]);
      final Map<String, double> metrics = {};
      metricIndexToName.forEach((col, name) {
        if (lowerHeader[col] == 'plant_status') {
          final raw = row[col]?.toString() ?? '';
          metrics[name] = encodePlantStatus(raw).toDouble();
        } else {
          metrics[name] = _toDouble(row[col]);
        }
      });

      if (useXY) {
        raw.add(_RawPoint(
          x: (row[xIndex] as num).toInt(),
          y: (row[yIndex] as num).toInt(),
          t: t,
          metrics: metrics,
        ));
      } else {
        raw.add(_RawPoint(
          lat: _toDouble(row[latIndex]),
          lon: _toDouble(row[lonIndex]),
          t: t,
          metrics: metrics,
        ));
      }
    }

    if (raw.isEmpty) return [];

    // If using lat/lon, map to grid indices by sorting unique values
    if (useLatLon) {
      final uniqueLats = raw.map((r) => r.lat!).toSet().toList()..sort();
      final uniqueLons = raw.map((r) => r.lon!).toSet().toList()..sort();
      final Map<double, int> latToY = { for (int i = 0; i < uniqueLats.length; i++) uniqueLats[i] : i };
      final Map<double, int> lonToX = { for (int i = 0; i < uniqueLons.length; i++) uniqueLons[i] : i };

      return raw.map((r) => HeatmapPoint(
        x: lonToX[r.lon]!,
        y: latToY[r.lat]!,
        t: r.t,
        metrics: r.metrics,
        lat: r.lat,
        lon: r.lon,
      )).toList();
    }

    // Already x/y
    return raw.map((r) => HeatmapPoint(
      x: r.x!,
      y: r.y!,
      t: r.t,
      metrics: r.metrics,
      lat: r.lat,
      lon: r.lon,
    )).toList();
  }

  // Create a grid from the data points
  List<List<double>> createGrid({
    required String metric,
    required DateTime start,
    required DateTime end,
  }) {
    if (points.isEmpty) {
      return [
        [double.nan]
      ];
    }

    final filteredPoints = points.where((p) =>
        (p.t.isAfter(start) || p.t.isAtSameMomentAs(start)) &&
        (p.t.isBefore(end) || p.t.isAtSameMomentAs(end)) &&
        (metric == 'All' || p.metrics.containsKey(metric))).toList();

    if (filteredPoints.isEmpty) {
      return [
        [double.nan]
      ];
    }

    final maxX = filteredPoints.map((p) => p.x).reduce(max);
    final maxY = filteredPoints.map((p) => p.y).reduce(max);

    final grid = List.generate(maxY + 1, (i) => List.filled(maxX + 1, double.nan));

    final Map<String, List<double>> combinedValues = {};
    for (var p in filteredPoints) {
      final key = '${p.x}_${p.y}';
      if (!combinedValues.containsKey(key)) {
        combinedValues[key] = [];
      }
      if (metric == 'All') {
        // Average across all metrics available for this point
        final values = p.metrics.values.where((v) => v.isFinite).toList();
        if (values.isNotEmpty) {
          combinedValues[key]!.add(values.reduce((a, b) => a + b) / values.length);
        }
      } else {
        final v = p.metrics[metric];
        if (v != null && v.isFinite) combinedValues[key]!.add(v);
      }
    }

    for (var entry in combinedValues.entries) {
      final parts = entry.key.split('_');
      final x = int.parse(parts[0]);
      final y = int.parse(parts[1]);
      if (entry.value.isNotEmpty) {
        final avgValue = entry.value.reduce((a, b) => a + b) / entry.value.length;
        grid[y][x] = avgValue;
      }
    }

    return grid;
  }

  // Create a grid from the data points for a set of metrics (per-cell averaged)
  List<List<double>> createGridForMetrics({
    required List<String> metrics,
    required DateTime start,
    required DateTime end,
  }) {
    if (points.isEmpty) {
      return [
        [double.nan]
      ];
    }

    final filteredPoints = points.where((p) =>
        (p.t.isAfter(start) || p.t.isAtSameMomentAs(start)) &&
        (p.t.isBefore(end) || p.t.isAtSameMomentAs(end))).toList();

    if (filteredPoints.isEmpty) {
      return [
        [double.nan]
      ];
    }

    final maxX = filteredPoints.map((p) => p.x).reduce(max);
    final maxY = filteredPoints.map((p) => p.y).reduce(max);

    final grid = List.generate(maxY + 1, (i) => List.filled(maxX + 1, double.nan));

    final Map<String, List<double>> combinedValues = {};
    for (var p in filteredPoints) {
      final key = '${p.x}_${p.y}';
      if (!combinedValues.containsKey(key)) {
        combinedValues[key] = [];
      }
      final v = _metricValueForList(p, metrics);
      if (v.isFinite) combinedValues[key]!.add(v);
    }

    for (var entry in combinedValues.entries) {
      final parts = entry.key.split('_');
      final x = int.parse(parts[0]);
      final y = int.parse(parts[1]);
      if (entry.value.isNotEmpty) {
        final avgValue = entry.value.reduce((a, b) => a + b) / entry.value.length;
        grid[y][x] = avgValue;
      }
    }

    return grid;
  }

  // Build a uniform, seamless grid using lat/lon by Inverse Distance Weighting (IDW) interpolation
  HeatmapGrid createUniformGridFromLatLon({
    required String metric,
    required DateTime start,
    required DateTime end,
    int? targetCols,
    int? targetRows,
  }) {
    if (points.isEmpty) {
      return HeatmapGrid(grid: [[double.nan]], widthRatio: 1.0);
    }

    final candidates = points.where((p) =>
      p.lat != null && p.lon != null &&
      (p.t.isAfter(start) || p.t.isAtSameMomentAs(start)) &&
      (p.t.isBefore(end) || p.t.isAtSameMomentAs(end))
    ).toList();

    if (candidates.isEmpty) {
      // Fallback to index-based grid with a square ratio
      final fallbackGrid = createGrid(metric: metric, start: start, end: end);
      return HeatmapGrid(grid: fallbackGrid, widthRatio: 1.0, latAxis: null, lonAxis: null);
    }

    // Determine resolution
    final uniqueLats = candidates.map((p) => p.lat!).toSet().toList()..sort();
    final uniqueLons = candidates.map((p) => p.lon!).toSet().toList()..sort();
    
    // Enforce a higher minimum resolution for better visual detail (32x32)
    final int minResolution = 32; 
    final int maxResolution = 128; 

    final int cols = targetCols ?? max(minResolution, min(maxResolution, uniqueLons.length * 4));
    final int rows = targetRows ?? max(minResolution, min(maxResolution, uniqueLats.length * 4));
    
    if (cols <= 0 || rows <= 0) {
      return HeatmapGrid(grid: [[double.nan]], widthRatio: 1.0);
    }

    final double minLat = uniqueLats.first;
    final double maxLat = uniqueLats.last;
    final double minLon = uniqueLons.first;
    final double maxLon = uniqueLons.last;

    // Calculate Aspect Ratio: Delta Lon / Delta Lat
    final double deltaLat = maxLat - minLat;
    final double deltaLon = maxLon - minLon;
    final double ratio = (deltaLat.abs() < 1e-6 || !deltaLat.isFinite) ? 1.0 : deltaLon / deltaLat;

    // Precompute candidate values and positions
    final List<_Sample> samples = [];
    for (final p in candidates) {
      final value = _metricValue(p, metric);
      if (value.isFinite) {
        samples.add(_Sample(p.lat!, p.lon!, value));
      }
    }
    if (samples.isEmpty) {
      return HeatmapGrid(grid: [[double.nan]], widthRatio: 1.0);
    }

    // Axis arrays (inclusive endpoints)
    List<double> latAxis = List.generate(rows, (r) => rows == 1 ? minLat : minLat + (maxLat - minLat) * r / (rows - 1));
    List<double> lonAxis = List.generate(cols, (c) => cols == 1 ? minLon : minLon + (maxLon - minLon) * c / (cols - 1));

    // Fill grid using Inverse Distance Weighting (IDW) interpolation
    final grid = List.generate(rows, (_) => List.filled(cols, double.nan));
    
    const double p = 2.0; // Power parameter (Inverse Square Distance)
    const double epsilon = 1e-12; // Small value to prevent division by zero

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final lat = latAxis[r];
        final lon = lonAxis[c];
        
        double weightedSum = 0.0;
        double weightSum = 0.0;
        
        for (final s in samples) {
          // Calculate Euclidean distance squared (approximation)
          final double dLat = s.lat - lat;
          final double dLon = s.lon - lon;
          final double dist2 = dLat * dLat + dLon * dLon;
          
          final double dist = sqrt(dist2);
          
          // Weight calculation: 1 / (distance^p + epsilon)
          final double weight = 1.0 / (pow(dist, p) + epsilon); 

          weightedSum += s.value * weight;
          weightSum += weight;
        }

        if (weightSum > 0) {
          grid[r][c] = weightedSum / weightSum;
        } else {
          grid[r][c] = double.nan;
        }
      }
    }
    
    return HeatmapGrid(grid: grid, widthRatio: ratio, latAxis: latAxis, lonAxis: lonAxis);
  }

  // Build a uniform, seamless grid using lat/lon and averaging across selected metrics
  HeatmapGrid createUniformGridFromLatLonForMetrics({
    required List<String> metrics,
    required DateTime start,
    required DateTime end,
    int? targetCols,
    int? targetRows,
  }) {
    if (points.isEmpty) {
      return HeatmapGrid(grid: [[double.nan]], widthRatio: 1.0);
    }

    final candidates = points.where((p) =>
        p.lat != null &&
        p.lon != null &&
        (p.t.isAfter(start) || p.t.isAtSameMomentAs(start)) &&
        (p.t.isBefore(end) || p.t.isAtSameMomentAs(end))).toList();

    if (candidates.isEmpty) {
      // Fallback to index-based grid with a square ratio
      final fallbackGrid = createGridForMetrics(metrics: metrics, start: start, end: end);
      return HeatmapGrid(grid: fallbackGrid, widthRatio: 1.0, latAxis: null, lonAxis: null);
    }

    // Determine resolution
    final uniqueLats = candidates.map((p) => p.lat!).toSet().toList()..sort();
    final uniqueLons = candidates.map((p) => p.lon!).toSet().toList()..sort();

    // Enforce a minimum and maximum visual resolution
    final int minResolution = 32;
    final int maxResolution = 128;

    final int cols = targetCols ?? max(minResolution, min(maxResolution, uniqueLons.length * 4));
    final int rows = targetRows ?? max(minResolution, min(maxResolution, uniqueLats.length * 4));

    if (cols <= 0 || rows <= 0) {
      return HeatmapGrid(grid: [[double.nan]], widthRatio: 1.0);
    }

    final double minLat = uniqueLats.first;
    final double maxLat = uniqueLats.last;
    final double minLon = uniqueLons.first;
    final double maxLon = uniqueLons.last;

    // Calculate Aspect Ratio: Delta Lon / Delta Lat
    final double deltaLat = maxLat - minLat;
    final double deltaLon = maxLon - minLon;
    final double ratio = (deltaLat.abs() < 1e-6 || !deltaLat.isFinite) ? 1.0 : deltaLon / deltaLat;

    // Precompute candidate values and positions
    final List<_Sample> samples = [];
    for (final p in candidates) {
      final value = _metricValueForList(p, metrics);
      if (value.isFinite) {
        samples.add(_Sample(p.lat!, p.lon!, value));
      }
    }
    if (samples.isEmpty) {
      return HeatmapGrid(grid: [[double.nan]], widthRatio: 1.0);
    }

    // Axis arrays (inclusive endpoints)
    List<double> latAxis = List.generate(rows, (r) => rows == 1 ? minLat : minLat + (maxLat - minLat) * r / (rows - 1));
    List<double> lonAxis = List.generate(cols, (c) => cols == 1 ? minLon : minLon + (maxLon - minLon) * c / (cols - 1));

    // Fill grid using Inverse Distance Weighting (IDW) interpolation
    final grid = List.generate(rows, (_) => List.filled(cols, double.nan));

    const double p = 2.0; // Power parameter (Inverse Square Distance)
    const double epsilon = 1e-12; // Small value to prevent division by zero

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final lat = latAxis[r];
        final lon = lonAxis[c];

        double weightedSum = 0.0;
        double weightSum = 0.0;

        for (final s in samples) {
          // Calculate Euclidean distance squared (approximation)
          final double dLat = s.lat - lat;
          final double dLon = s.lon - lon;
          final double dist2 = dLat * dLat + dLon * dLon;

          final double dist = sqrt(dist2);

          // Weight calculation: 1 / (distance^p + epsilon)
          final double weight = 1.0 / (pow(dist, p) + epsilon);

          weightedSum += s.value * weight;
          weightSum += weight;
        }

        if (weightSum > 0) {
          grid[r][c] = weightedSum / weightSum;
        } else {
          grid[r][c] = double.nan;
        }
      }
    }

    return HeatmapGrid(grid: grid, widthRatio: ratio, latAxis: latAxis, lonAxis: lonAxis);
  }

  double _metricValue(HeatmapPoint p, String metric) {
    if (metric == 'All') {
      final values = p.metrics.values.where((v) => v.isFinite).toList();
      if (values.isEmpty) return double.nan;
      return values.reduce((a, b) => a + b) / values.length;
    }
    return p.metrics[metric] ?? double.nan;
  }

  // Average value across a specific list of metrics for a point
  double _metricValueForList(HeatmapPoint p, List<String> metrics) {
    final values = <double>[];
    for (final m in metrics) {
      final v = p.metrics[m];
      if (v != null && v.isFinite) values.add(v);
    }
    if (values.isEmpty) return double.nan;
    return values.reduce((a, b) => a + b) / values.length;
  }

  // Compute an average optimal range across a set of metrics
  List<double> averageOptimalRange(List<String> metrics) {
    final mins = <double>[];
    final maxs = <double>[];
    for (final m in metrics) {
      final r = optimalRanges[m];
      if (r != null && r.length >= 2) {
        mins.add(r[0]);
        maxs.add(r[1]);
      }
    }
    if (mins.isEmpty || maxs.isEmpty) {
      // Fallback
      return [0.0, 1.0];
    }
    final avgMin = mins.reduce((a, b) => a + b) / mins.length;
    final avgMax = maxs.reduce((a, b) => a + b) / maxs.length;
    return [avgMin, avgMax];
  }

}

extension on double {
  bool get isValidFinite => isFinite && !isNaN;
}

extension _IterableExt<T> on Iterable<T> {
  R? firstOrNull<R>(R Function(T) map) {
    for (final e in this) {
      return map(e);
    }
    return null;
  }
}

// Interpolate a single metric value at a given lat/lon using IDW
double interpolateAt({
  required List<HeatmapPoint> points,
  required String metric,
  required double lat,
  required double lon,
  required DateTime start,
  required DateTime end,
}) {
  const double p = 2.0;
  const double epsilon = 1e-12;
  double weightedSum = 0.0;
  double weightSum = 0.0;
  for (final pt in points) {
    if (pt.lat == null || pt.lon == null) continue;
    if (pt.t.isBefore(start) || pt.t.isAfter(end)) continue;
    final v = pt.metrics[metric];
    if (v == null || !v.isFinite) continue;
    final double dLat = pt.lat! - lat;
    final double dLon = pt.lon! - lon;
    final double dist = sqrt(dLat * dLat + dLon * dLon);
    final double weight = 1.0 / (pow(dist, p) + epsilon);
    weightedSum += v * weight;
    weightSum += weight;
  }
  if (weightSum <= 0) return double.nan;
  return weightedSum / weightSum;
}

// Interpolate several metrics at a given lat/lon
Map<String, double> interpolateAtForMetrics({
  required List<HeatmapPoint> points,
  required List<String> metrics,
  required double lat,
  required double lon,
  required DateTime start,
  required DateTime end,
}) {
  final Map<String, double> out = {};
  for (final m in metrics) {
    out[m] = interpolateAt(points: points, metric: m, lat: lat, lon: lon, start: start, end: end);
  }
  return out;
}

class _Sample {
  final double lat;
  final double lon;
  final double value;
  const _Sample(this.lat, this.lon, this.value);
}

class _RawPoint {
  final int? x;
  final int? y;
  final double? lat;
  final double? lon;
  final DateTime t;
  final Map<String, double> metrics;

  _RawPoint({this.x, this.y, this.lat, this.lon, required this.t, required this.metrics});
}

// Encode plant status strings into numeric categories for heatmap coloring
int encodePlantStatus(String status) {
  final s = status.trim().toLowerCase();
  if (s.isEmpty) return 0;
  if (s == 'healthy') return 1;
  if (s.contains('anthracnose') && s.contains('wilt')) return 2;
  if (s.contains('anthracnose') && s.contains('sunken')) return 3;
  if (s.contains('no turmeric')) return 4;
  if (s.contains('anthracnose') && s.contains('yellow')) return 5;
  if (s.contains('anthracnose') && s.contains('blight')) return 6;
  if (s.contains('anthracnose') && s.contains('lesion')) return 7;
  return 0; // Unknown
}

// Human-readable label for a plant status code
String labelForPlantStatusCode(int code) {
  switch (code) {
    case 1:
      return 'Healthy';
    case 2:
      return 'Anthracnose - Symptomatic (wilt)';
    case 3:
      return 'Anthracnose - Symptomatic (sunken spots)';
    case 4:
      return 'No Turmeric Detected';
    case 5:
      return 'Anthracnose - Symptomatic (yellowing)';
    case 6:
      return 'Anthracnose - Symptomatic (blight)';
    case 7:
      return 'Anthracnose - Symptomatic (lesions)';
    default:
      return 'Unknown';
  }
}

// Color for a plant status code, consistent across app (heatmap/graph legends)
Color colorForPlantStatusCode(int code) {
  switch (code) {
    case 1:
      return const Color(0xFF2E7D32); // Healthy - green
    case 2:
      return const Color(0xFF8E24AA); // Anthracnose (wilt) - purple
    case 3:
      return const Color(0xFFD32F2F); // Anthracnose (sunken spots) - red
    case 4:
      return const Color(0xFF616161); // No Turmeric Detected - gray
    case 5:
      return const Color(0xFFFBC02D); // Anthracnose (yellowing) - yellow
    case 6:
      return const Color(0xFFEF6C00); // Anthracnose (blight) - orange
    case 7:
      return const Color(0xFF1E88E5); // Anthracnose (lesions) - blue
    default:
      return Colors.black.withOpacity(0.15); // Unknown
  }
}

class PlantStatusCategoryItem {
  final int code;
  final String label;
  final Color color;
  const PlantStatusCategoryItem({required this.code, required this.label, required this.color});
}

List<PlantStatusCategoryItem> getPlantStatusLegendItems() {
  const codes = [1, 2, 3, 4, 5, 6, 7];
  return codes
      .map((c) => PlantStatusCategoryItem(
            code: c,
            label: labelForPlantStatusCode(c),
            color: colorForPlantStatusCode(c),
          ))
      .toList();
}

// This map defines the "optimal" range for each metric for color scaling.
final Map<String, List<double>> optimalRanges = {
  'pH': [6.0, 7.5],
  'Temperature': [20.0, 25.0],
  'Humidity': [40.0, 60.0],
  'EC': [1.0, 2.0],
  'N': [100.0, 150.0],
  'P': [20.0, 50.0],
  'K': [150.0, 250.0],
  'All': [0, 1]
};

// Converts a value to a color based on the optimal range for the metric
Color valueToColor(
  double value,
  double minValue,
  double maxValue,
  String metric, {
  List<double>? optimalRangeOverride,
}) {
  if (metric == 'Plant Status') {
    final int code = value.isNaN ? 0 : value.round();
    return colorForPlantStatusCode(code);
  }
  if (value.isNaN) {
    return Colors.black.withOpacity(0.1);
  }

  final double range = maxValue - minValue;
  
  // Guard against zero/invalid range. If the range is zero (all values are identical), 
  // we return a neutral color (e.g., green, as it's the "optimal" middle).
  if (!range.isFinite || range.abs() < 1e-12) {
    return Colors.green;
  }

  final optimalRange = optimalRangeOverride ?? optimalRanges[metric] ?? [minValue, maxValue];
  final optimalMin = optimalRange[0];
  final optimalMax = optimalRange[1];

  // Map value to a 0-1 range based on the overall min/max of the data
  final clampedValue = value.clamp(minValue, maxValue);
  final normalizedValue = (clampedValue - minValue) / range; // 0 to 1

  // Map optimal stops to the new normalized 0-1 range.
  final optimalMinStop = (optimalMin - minValue) / range;
  final optimalMaxStop = (optimalMax - minValue) / range;

  if (normalizedValue < optimalMinStop) {
    // Transition from blue (min) to green (optimal min)
    final double denom = (optimalMinStop <= 0 || !optimalMinStop.isFinite) ? 1.0 : optimalMinStop;
    final progress = (normalizedValue / denom).clamp(0.0, 1.0);
    return Color.lerp(Colors.blue, Colors.green, progress)!;
  } else if (normalizedValue >= optimalMinStop && normalizedValue <= optimalMaxStop) {
    // Stay in the green range for optimal values
    return Colors.green;
  } else {
    // Transition from green (optimal max) to red (max)
    final double denom = ((1.0 - optimalMaxStop) <= 0 || !(1.0 - optimalMaxStop).isFinite)
        ? 1.0
        : (1.0 - optimalMaxStop);
    final progress = ((normalizedValue - optimalMaxStop) / denom).clamp(0.0, 1.0);
    return Color.lerp(Colors.green, Colors.red, progress)!;
  }
}
