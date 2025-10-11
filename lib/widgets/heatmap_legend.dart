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
    // NOTE: The original optimalRange, blueStop, and redStop calculations
    // are ignored to implement the fixed, symmetrical gradient as requested.
    
    // --- FIXED SYMMETRICAL GRADIENT LOGIC ---
    // This ensures Green (the 'optimal' band) is always visible in the middle.
    const double greenStart = 0.3; // Green starts at 30% of the bar
    const double greenEnd = 0.7;   // Green ends at 70% of the bar (40% width)

    // The gradient colors and stops are now fixed to provide a consistent visual.
    final stops = [
      0.0,        // Start of Blue
      greenStart, // Start of Green
      greenEnd,   // End of Green
      1.0         // End of Red
    ];

    final gradientColors = [
      Colors.blue,
      Colors.green,
      Colors.green,
      Colors.red,
    ];
    // ----------------------------------------

    if (axis == Axis.vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start, // Align title and bar/labels
        children: [
          // FIX: Added maxLines and overflow to prevent the label from wrapping/overflowing
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
