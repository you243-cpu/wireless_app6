import 'package:flutter/material.dart';
import '../services/heatmap_service.dart';

class HeatmapLegend extends StatelessWidget {
  final double minValue;
  final double maxValue;
  final String metricLabel;
  final bool isDark;
  final Axis axis;
  final double thickness;

  const HeatmapLegend({
    super.key,
    required this.minValue,
    required this.maxValue,
    required this.metricLabel,
    this.isDark = false,
    this.axis = Axis.vertical,
    this.thickness = 20,
  });

  @override
  Widget build(BuildContext context) {
    final optimalRange = optimalRanges[metricLabel] ?? [minValue, maxValue];
    final optimalMin = optimalRange[0];
    final optimalMax = optimalRange[1];

    final double range = (maxValue - minValue).abs() < 1e-12 ? 1.0 : (maxValue - minValue);

    final blueStop = (optimalMin - minValue) / range;
    final redStop = (optimalMax - minValue) / range;

    final stops = [
      0.0,
      blueStop.clamp(0.0, 1.0),
      redStop.clamp(0.0, 1.0),
      1.0
    ];
    stops.sort();

    final gradientColors = [
      Colors.blue,
      Colors.green,
      Colors.green,
      Colors.red,
    ];

    if (axis == Axis.vertical) {
      return Column(
        children: [
          Text(
            metricLabel,
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
