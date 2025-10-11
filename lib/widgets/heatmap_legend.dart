import 'package:flutter/material.dart';
import '../services/heatmap_service.dart'; // Re-added the required import

// 1. Define the enum to switch between gradient calculation modes
enum GradientMode {
  /// Proportional, where the stops are fixed (0.3 and 0.7) to guarantee
  /// a visible green band, regardless of data distribution.
  fixed,

  /// Value-based, where the stops are calculated based on the metric's
  /// optimal range relative to the min/max values. (Data accurate, but
  /// green band might be invisible if optimal range is narrow).
  valueBased,
}

// NOTE: optimalRangesMock has been removed, as the service is now imported.

class HeatmapLegend extends StatelessWidget {
  final double minValue;
  final double maxValue;
  final String metricLabel;
  final bool isDark;
  final Axis axis;
  final double thickness;
  final GradientMode gradientMode; // New property to select the mode
  final List<double>? optimalRangeOverride; // Optional override for optimal range when combining metrics

  const HeatmapLegend({
    super.key,
    required this.minValue,
    required this.maxValue,
    required this.metricLabel,
    this.isDark = false,
    this.axis = Axis.vertical,
    this.thickness = 20,
    this.gradientMode = GradientMode.fixed, // Default to the working fixed mode
    this.optimalRangeOverride,
  });

  @override
  Widget build(BuildContext context) {
    final List<double> stops;
    
    // --- Gradient Calculation based on Mode ---
    if (gradientMode == GradientMode.fixed) {
      // MODE 1: Fixed Symmetrical Gradient (Visual Reliability)
      const double greenStart = 0.3;
      const double greenEnd = 0.7;
      
      stops = [
        0.0,        // Start of Blue
        greenStart, // Start of Green
        greenEnd,   // End of Green
        1.0         // End of Red
      ];
    } else {
      // MODE 2: Value-Based Proportional Gradient (Data Accuracy)
      // Use override if provided, else fall back to `optimalRanges` map from heatmap_service.dart
      final optimalRange = optimalRangeOverride ?? (optimalRanges[metricLabel] ?? [minValue, maxValue]);
      final optimalMin = optimalRange[0];
      final optimalMax = optimalRange[1];

      final double range = (maxValue - minValue).abs() < 1e-12 ? 1.0 : (maxValue - minValue);

      final blueStop = (optimalMin - minValue) / range;
      final redStop = (optimalMax - minValue) / range;

      stops = [
        0.0,
        blueStop.clamp(0.0, 1.0),
        redStop.clamp(0.0, 1.0),
        1.0
      ];
      stops.sort();
    }
    // ----------------------------------------

    final gradientColors = [
      Colors.blue,
      Colors.green,
      Colors.green,
      Colors.red,
    ];

    if (axis == Axis.vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          // FIX: Label overflow handling
          Text(
            metricLabel,
            maxLines: 1, 
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: thickness,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      // Increase from bottom (min/blue) to top (max/red)
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: gradientColors,
                      stops: stops,
                    ),
                    border: Border.all(
                      color: isDark ? Colors.white54 : Colors.black54,
                      width: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Labels aligned to the bar: top = max, bottom = min
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      maxValue.toStringAsFixed(2),
                      style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 12),
                    ),
                    Text(
                      minValue.toStringAsFixed(2),
                      style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      return Row(
        children: [
          Text(
            minValue.toStringAsFixed(2),
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 12),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Container(
              height: thickness,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: gradientColors,
                  stops: stops,
                ),
                border: Border.all(
                  color: isDark ? Colors.white54 : Colors.black54,
                  width: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            maxValue.toStringAsFixed(2),
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 12),
          ),
        ],
      );
    }
  }
}
