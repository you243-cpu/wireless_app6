// lib/services/heatmap_service.dart
import 'dart:math';
import 'dart:ui';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// A single sensor measurement
class HeatPoint {
  final DateTime t;
  final double lat;
  final double lon;
  final double pH;
  final double temp;
  final double humidity;
  final double ec;
  final double n;
  final double p;
  final double k;

  HeatPoint({
    required this.t,
    required this.lat,
    required this.lon,
    required this.pH,
    required this.temp,
    required this.humidity,
    required this.ec,
    required this.n,
    required this.p,
    required this.k,
  });
}

/// Service to parse CSV and prepare grid data
class HeatmapService {
  List<HeatPoint> points = [];

  // bounds
  late double minLat, maxLat, minLon, maxLon;

  /// Load CSV from asset
  static Future<List<HeatPoint>> parseCsvAsset(String assetPath) async {
    final csvString = await rootBundle.loadString(assetPath);
    return parseCsvString(csvString);
  }

  /// Parse CSV string into HeatPoint list
  static List<HeatPoint> parseCsvString(String csvString) {
    final rows = const CsvToListConverter().convert(csvString, eol: '\n');
    if (rows.isEmpty) return [];
    final header = rows.first.map((e) => e.toString().trim()).toList();

    // expected header contains timestamp, lat, lon, pH, Temperature, Humidity, EC, N, P, K
    int idx(String name) =>
        header.indexWhere((h) => h.toLowerCase() == name.toLowerCase());

    final int ti = idx('timestamp');
    final int lati = idx('lat');
    final int loni = idx('lon');
    final int phi = idx('ph');
    final int tempi = idx('temperature');
    final int humi = idx('humidity');
    final int eci = idx('ec');
    final int ni = idx('n');
    final int pi = idx('p');
    final int ki = idx('k');

    final List<HeatPoint> pts = [];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      try {
        final ts = DateTime.parse(row[ti].toString());
        final lat = double.parse(row[lati].toString());
        final lon = double.parse(row[loni].toString());
        final pH = double.parse(row[phi].toString());
        final temp = double.parse(row[tempi].toString());
        final humidity = double.parse(row[humi].toString());
        final ec = double.parse(row[eci].toString());
        final n = double.parse(row[ni].toString());
        final p = double.parse(row[pi].toString());
        final k = double.parse(row[ki].toString());

        pts.add(HeatPoint(
          t: ts,
          lat: lat,
          lon: lon,
          pH: pH,
          temp: temp,
          humidity: humidity,
          ec: ec,
          n: n,
          p: p,
          k: k,
        ));
      } catch (_) {
        // ignore malformed rows
      }
    }
    return pts;
  }

  /// Set points and compute bounds
  void setPoints(List<HeatPoint> pts) {
    points = pts;
    if (pts.isEmpty) {
      minLat = maxLat = minLon = maxLon = 0;
      return;
    }
    minLat = pts.map((p) => p.lat).reduce(min);
    maxLat = pts.map((p) => p.lat).reduce(max);
    minLon = pts.map((p) => p.lon).reduce(min);
    maxLon = pts.map((p) => p.lon).reduce(max);

    // tiny padding
    final padLat = (maxLat - minLat) * 0.02;
    final padLon = (maxLon - minLon) * 0.02;
    minLat -= padLat;
    maxLat += padLat;
    minLon -= padLon;
    maxLon += padLon;
  }

  /// Create grid aggregated values for a metric (pH/temp/humidity/ec/n/p/k/all)
  List<List<double>> createGrid({
    required String metric,
    required DateTime start,
    required DateTime end,
    int cols = 40,
    int rows = 40,
  }) {
    final sums = List.generate(rows, (_) => List<double>.filled(cols, 0.0));
    final counts = List.generate(rows, (_) => List<int>.filled(cols, 0));

    for (final pt in points) {
      if (pt.t.isBefore(start) || pt.t.isAfter(end)) continue;

      // map lat/lon to grid col,row
      final cx = ((pt.lon - minLon) / (maxLon - minLon) * (cols - 1))
          .clamp(0.0, cols - 1.0);
      final cy = ((pt.lat - minLat) / (maxLat - minLat) * (rows - 1))
          .clamp(0.0, rows - 1.0);
      final col = cx.round();
      final row = (rows - 1 - cy.round());

      double val;
      switch (metric.toLowerCase()) {
        case 'ph':
          val = pt.pH;
          break;
        case 'temperature':
          val = pt.temp;
          break;
        case 'humidity':
          val = pt.humidity;
          break;
        case 'ec':
          val = pt.ec;
          break;
        case 'n':
          val = pt.n;
          break;
        case 'p':
          val = pt.p;
          break;
        case 'k':
          val = pt.k;
          break;
        case 'all':
          // simple average of everything
          val = (pt.pH +
                  pt.temp +
                  pt.humidity +
                  pt.ec +
                  pt.n +
                  pt.p +
                  pt.k) /
              7.0;
          break;
        default:
          val = double.nan;
      }

      sums[row][col] += val;
      counts[row][col] += 1;
    }

    // compute averages; empty cells -> double.nan
    final grid =
        List.generate(rows, (r) => List<double>.filled(cols, double.nan));
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (counts[r][c] > 0) {
          grid[r][c] = sums[r][c] / counts[r][c];
        }
      }
    }
    return grid;
  }
}

/// Optimal value ranges for different metrics, used for the green center of the legend.
const Map<String, List<double>> optimalRanges = {
  'pH': [6.0, 7.0],
  'Temperature': [18.0, 24.0], // in Celsius
  'EC': [1.0, 2.5], // Siemens/meter
  'N': [1.0, 2.0], // mg/L
  'P': [0.15, 0.3], // mg/L
  'K': [0.5, 1.0], // mg/L
  'All': [0.5, 1.0], // arbitrary for 'all'
};

/// Convert numeric value to color (blue -> green -> red gradient)
Color valueToColor(double value, double min, double max, String metric) {
  if (value.isNaN) return Colors.transparent;

  final optimalRange = optimalRanges[metric] ?? [min, max];
  final optimalMin = optimalRange[0];
  final optimalMax = optimalRange[1];

  if (value >= optimalMin && value <= optimalMax) {
    // Value is in the optimal range (green)
    return Colors.green;
  } else if (value < optimalMin) {
    // Value is too low (blue -> green)
    final t = ((value - min) / (optimalMin - min)).clamp(0.0, 1.0);
    return Color.lerp(Colors.blue, Colors.green, t)!;
  } else {
    // Value is too high (green -> red)
    final t = ((value - optimalMax) / (max - optimalMax)).clamp(0.0, 1.0);
    return Color.lerp(Colors.green, Colors.red, t)!;
  }
}
