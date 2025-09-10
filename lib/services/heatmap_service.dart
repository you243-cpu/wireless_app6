// lib/services/heatmap_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart' show rootBundle;

/// A single sensor measurement
class HeatPoint {
  final DateTime t;
  final double lat;
  final double lon;
  final double pH;
  final double n;
  final double p;
  final double k;

  HeatPoint({
    required this.t,
    required this.lat,
    required this.lon,
    required this.pH,
    required this.n,
    required this.p,
    required this.k,
  });
}

/// Grid cell with aggregated value
class GridCell {
  final int row;
  final int col;
  final double value; // aggregated value for chosen metric
  GridCell(this.row, this.col, this.value);
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
    // expected header contains timestamp, lat, lon, pH, N, P, K (case-insensitive)
    int idx(String name) => header.indexWhere((h) => h.toLowerCase() == name.toLowerCase());

    final int ti = idx('timestamp');
    final int lati = idx('lat');
    final int loni = idx('lon');
    final int phi = idx('ph');
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
        final n = double.parse(row[ni].toString());
        final p = double.parse(row[pi].toString());
        final k = double.parse(row[ki].toString());
        pts.add(HeatPoint(t: ts, lat: lat, lon: lon, pH: pH, n: n, p: p, k: k));
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

  /// Create grid aggregated values for a metric (pH/n/p/k/all) for a given
  /// time window (start..end). Returns 2D array of cell values (NaN for empty).
  List<List<double>> createGrid({
    required String metric, // 'pH','N','P','K','all'
    required DateTime start,
    required DateTime end,
    int cols = 40,
    int rows = 40,
  }) {
    // initialize grid lists for sums and counts
    final sums = List.generate(rows, (_) => List<double>.filled(cols, 0.0));
    final counts = List.generate(rows, (_) => List<int>.filled(cols, 0));
    for (final pt in points) {
      if (pt.t.isBefore(start) || pt.t.isAfter(end)) continue;
      // map lat/lon to grid col,row
      final cx = ((pt.lon - minLon) / (maxLon - minLon) * (cols - 1)).clamp(0.0, cols - 1.0);
      final cy = ((pt.lat - minLat) / (maxLat - minLat) * (rows - 1)).clamp(0.0, rows - 1.0);
      final col = cx.round();
      final row = (rows - 1 - cy.round()); // flip so row0 is top (latitude high->top)
      double val;
      if (metric.toLowerCase() == 'ph') val = pt.pH;
      else if (metric.toLowerCase() == 'n') val = pt.n;
      else if (metric.toLowerCase() == 'p') val = pt.p;
      else if (metric.toLowerCase() == 'k') val = pt.k;
      else if (metric.toLowerCase() == 'all') {
        // normalize or average — here simple average of pH, n, p, k
        val = (pt.pH + pt.n + pt.p + pt.k) / 4.0;
      } else val = pt.pH;
      sums[row][col] += val;
      counts[row][col] += 1;
    }

    // compute averages; empty cells -> double.nan
    final grid = List.generate(rows, (r) => List<double>.filled(cols, double.nan));
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (counts[r][c] > 0) grid[r][c] = sums[r][c] / counts[r][c];
      }
    }
    return grid;
  }
}

