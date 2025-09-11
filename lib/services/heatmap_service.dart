import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'package:csv/csv.dart';
import 'dart:math';

// A single data point
class HeatmapPoint {
  final int x;
  final int y;
  final DateTime t;
  final Map<String, double> metrics;

  HeatmapPoint({
    required this.x,
    required this.y,
    required this.t,
    required this.metrics,
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
    
    final header = csvTable[0].map((e) => e.toString()).toList();
    final List<HeatmapPoint> points = [];

    // Map column names to indices
    final xIndex = header.indexOf('x');
    final yIndex = header.indexOf('y');
    final tIndex = header.indexOf('t');

    if (xIndex == -1 || yIndex == -1 || tIndex == -1) {
      throw Exception("CSV file must contain 'x', 'y', and 't' columns.");
    }

    final metricNames = header.sublist(tIndex + 1);

    for (var i = 1; i < csvTable.length; i++) {
      final row = csvTable[i];
      final metrics = <String, double>{};
      
      for (var j = 0; j < metricNames.length; j++) {
        metrics[metricNames[j]] = row[tIndex + 1 + j].toDouble();
      }

      points.add(HeatmapPoint(
        x: row[xIndex],
        y: row[yIndex],
        t: DateTime.parse(row[tIndex]),
        metrics: metrics,
      ));
    }
    return points;
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
        p.metrics.containsKey(metric)).toList();

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
      combinedValues[key]!.add(p.metrics[metric]!);
    }

    for (var entry in combinedValues.entries) {
      final parts = entry.key.split('_');
      final x = int.parse(parts[0]);
      final y = int.parse(parts[1]);
      final avgValue = entry.value.reduce((a, b) => a + b) / entry.value.length;
      grid[y][x] = avgValue;
    }

    return grid;
  }
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
Color valueToColor(double value, double minValue, double maxValue, String metric) {
  if (value.isNaN) {
    return Colors.black.withOpacity(0.1);
  }

  final optimalRange = optimalRanges[metric] ?? [minValue, maxValue];
  final optimalMin = optimalRange[0];
  final optimalMax = optimalRange[1];

  // Map value to a 0-1 range based on the overall min/max of the data
  final clampedValue = value.clamp(minValue, maxValue);
  final normalizedValue = (clampedValue - minValue) / (maxValue - minValue);

  // Define stops for the gradient
  final optimalMinStop = (optimalMin - minValue) / (maxValue - minValue);
  final optimalMaxStop = (optimalMax - minValue) / (maxValue - minValue);

  if (normalizedValue < optimalMinStop) {
    // Transition from blue (min) to green (optimal min)
    final progress = normalizedValue / optimalMinStop;
    return Color.lerp(Colors.blue, Colors.green, progress)!;
  } else if (normalizedValue >= optimalMinStop && normalizedValue <= optimalMaxStop) {
    // Stay in the green range for optimal values
    return Colors.green;
  } else {
    // Transition from green (optimal max) to red (max)
    final progress = (normalizedValue - optimalMaxStop) / (1.0 - optimalMaxStop);
    return Color.lerp(Colors.green, Colors.red, progress)!;
  }
}
