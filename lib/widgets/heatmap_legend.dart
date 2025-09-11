// lib/widgets/heatmap_legend.dart
import 'package:flutter/material.dart';
import '../services/heatmap_service.dart';

class HeatmapLegend extends StatelessWidget {
  final double minValue;
  final double maxValue;
  final String metricLabel;
  final bool isDark;
  final Axis axis; // vertical or horizontal
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
    // Determine the optimal range for the current metric
    final optimalRange = optimalRanges[metricLabel] ?? [minValue, maxValue];
    final optimalMin = optimalRange[0];
    final optimalMax = optimalRange[1];

    // Calculate the stops for the gradient based on the value ranges
    final double blueStop = (optimalMin - minValue) / (maxValue - minValue);
    final double greenStop = (optimalMax - minValue) / (maxValue - minValue);

    // Clamp the stops to be within [0, 1]
    final stops = [
      0.0,
      blueStop.clamp(0.0, 1.0),
      greenStop.clamp(0.0, 1.0),
      1.0
    ];
    
    // Sort the stops to ensure they are in increasing order
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
            child: Container(
              width: thickness,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: gradientColors.reversed.toList(),
                  stops: stops.reversed.toList(),
                ),
                border: Border.all(
                  color: isDark ? Colors.white54 : Colors.black54,
                  width: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                minValue.toStringAsFixed(2),
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 12),
              ),
              Text(
                maxValue.toStringAsFixed(2),
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 12),
              ),
            ],
          )
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
